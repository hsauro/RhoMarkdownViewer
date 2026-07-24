program MarkdownRender;

{
  Renders a markdown file to a PNG through the real TRhoMarkdownViewer layout
  and paint path, with no window involved.

    MarkdownRender <input.md> <output.png> [width] [fontSize] [links|select|dark|html|anchors]

  Passing "links" as the fifth argument overlays a translucent marker wherever
  LinkAt reports a link, by probing the document on a grid. That verifies the
  real hit-testing path - not an internal copy of it - so the overlay landing
  exactly on the link text is proof the click zones are right.

  This is the cheap way to check a rendering change. Write a small markdown file
  exercising the feature under test, render it, and look at the PNG - far less
  fragile than driving the demo GUI and screenshotting it.

  The viewer is created unparented: MeasureDocument and RenderToCanvas both take
  their width explicitly and never touch the paint box, which is the whole
  reason those two methods exist.
}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Skia,
  uRhoMarkdownTypes in '..\..\Source\uRhoMarkdownTypes.pas',
  uRhoMarkdownHighlight in '..\..\Source\uRhoMarkdownHighlight.pas',
  uRhoMarkdownParser in '..\..\Source\uRhoMarkdownParser.pas',
  uRhoMarkdownHtml in '..\..\Source\uRhoMarkdownHtml.pas',
  uRhoMarkdownViewer in '..\..\Source\uRhoMarkdownViewer.pas';

const
  DefaultWidth = 800;
  MaxHeight    = 20000;   // guard against a runaway document
  ProbeStep    = 3;       // grid spacing for the link overlay

procedure Run;
var
  InputFile, OutputFile: string;
  Width, FontSize, Height: Single;
  Viewer: TRhoMarkdownViewer;
  Surface: ISkSurface;
  Image: ISkImage;
  Bytes: TBytes;
  Paint: ISkPaint;
  X, Y: Single;
  Hits: Integer;
  I, Resolved, Total: Integer;
  Slug: string;
  Ok: Boolean;
  Lines: TStringList;
  Blocks: TMarkDownBlockList;
begin
  if ParamCount < 2 then
    raise Exception.Create(
      'usage: MarkdownRender <input.md> <output.png> [width] [fontSize]');

  InputFile := ParamStr(1);
  OutputFile := ParamStr(2);
  if not TFile.Exists(InputFile) then
    raise Exception.CreateFmt('input not found: %s', [InputFile]);

  Width := DefaultWidth;
  if ParamCount >= 3 then
    Width := StrToFloatDef(ParamStr(3), DefaultWidth);
  FontSize := 0;
  if ParamCount >= 4 then
    FontSize := StrToFloatDef(ParamStr(4), 0);

  Viewer := TRhoMarkdownViewer.Create(nil);
  try
    if FontSize > 0 then
      Viewer.FontSize := FontSize;
    if (ParamCount >= 5) and SameText(ParamStr(5), 'dark') then
      Viewer.ApplyTheme(rtDark);
    Viewer.LoadFromFile(InputFile);

    Height := Viewer.MeasureDocument(Width);
    if Height <= 0 then
      raise Exception.Create('document laid out to zero height');
    if Height > MaxHeight then
      Height := MaxHeight;

    Surface := TSkSurface.MakeRaster(Round(Width), Round(Height));
    if Surface = nil then
      raise Exception.Create('could not create raster surface');

    Viewer.RenderToCanvas(Surface.Canvas, Width, Height, 0);

    if (ParamCount >= 5) and SameText(ParamStr(5), 'html') then
    begin
      // Writes the HTML export beside the PNG, so the two can be compared.
      TFile.WriteAllText(TPath.ChangeExtension(OutputFile, '.html'),
        Viewer.AsHtmlDocument(TPath.GetFileNameWithoutExtension(InputFile)));
      Writeln('html    -> ', TPath.ChangeExtension(OutputFile, '.html'));
      Writeln('fragment length = ', Length(Viewer.AsHtml));
    end;

    if (ParamCount >= 5) and SameText(ParamStr(5), 'select') then
    begin
      // Select everything, re-render so the highlight shows, then dump both
      // copy forms. This exercises the real SelectedText path, including the
      // source-map lookup that makes markdown copy exact.
      Viewer.SelectAll;
      Viewer.RenderToCanvas(Surface.Canvas, Width, Height, 0);
      Writeln('--- SelectedText(markdown), first 300 chars ---');
      Writeln(Copy(Viewer.SelectedText(False), 1, 300));
      Writeln('--- SelectedText(plain), first 300 chars ---');
      Writeln(Copy(Viewer.SelectedText(True), 1, 300));
      Writeln('--- lengths: markdown=', Length(Viewer.SelectedText(False)),
        ' plain=', Length(Viewer.SelectedText(True)), ' ---');
    end;

    if (ParamCount >= 5) and SameText(ParamStr(5), 'anchors') then
    begin
      // Lists every heading with the slug an in-page link must target, and
      // checks each one actually resolves through ScrollToAnchor - the real
      // anchor path, not a copy of it. (Duplicate headings disambiguate as
      // slug-1, slug-2 inside the viewer; this listing shows the base slug.)
      Lines := TStringList.Create;
      Blocks := nil;
      try
        Lines.LoadFromFile(InputFile, TEncoding.UTF8);
        Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
        Writeln('--- headings and anchor slugs ---');
        Resolved := 0;
        Total := 0;
        for I := 0 to Blocks.Count - 1 do
          if Blocks[I].Kind = bkHeading then
          begin
            Inc(Total);
            Slug := RhoHeadingSlug(Blocks[I].Text);
            Ok := Viewer.ScrollToAnchor(Slug);
            if Ok then
              Inc(Resolved);
            Writeln(Format('  H%d  #%-44s %-5s y=%.0f',
              [Blocks[I].Level, Slug, BoolToStr(Ok, True), Viewer.ScrollY]));
          end;
        Writeln(Format('resolved %d of %d headings', [Resolved, Total]));
        Viewer.SetScrollPos(0);
      finally
        Blocks.Free;
        Lines.Free;
      end;
    end;

    if (ParamCount >= 5) and SameText(ParamStr(5), 'links') then
    begin
      // ScrollY is 0 and the whole document is rendered, so viewport
      // coordinates equal content coordinates here.
      Paint := TSkPaint.Create;
      Paint.Color := $4000C000;
      Hits := 0;
      Y := 0;
      while Y < Height do
      begin
        X := 0;
        while X < Width do
        begin
          if Viewer.LinkAt(X, Y) <> '' then
          begin
            Surface.Canvas.DrawRect(RectF(X, Y, X + ProbeStep, Y + ProbeStep),
              Paint);
            Inc(Hits);
          end;
          X := X + ProbeStep;
        end;
        Y := Y + ProbeStep;
      end;
      Writeln(Format('link probe: %d hit cells at %dpx grid', [Hits, ProbeStep]));
    end;

    Image := Surface.MakeImageSnapshot;
    Bytes := Image.Encode(TSkEncodedImageFormat.PNG);
    TFile.WriteAllBytes(OutputFile, Bytes);

    Writeln(Format('%s -> %s  (%dx%d, %d blocks)',
      [TPath.GetFileName(InputFile), TPath.GetFileName(OutputFile),
       Round(Width), Round(Height), Viewer.BlockCount]));
  finally
    Viewer.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

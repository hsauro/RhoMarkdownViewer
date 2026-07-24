program DesignStreamTest;

// Exercises the path a component dropped on a form at design time takes:
// class resolution by name, property streaming, child handling, and Loaded.
// Reports rather than displays, so it can run unattended.
//
// This is the ONLY coverage of the design-time path - everything else in the
// project creates the viewer in code, which does not go near form streaming.
// It caught a real defect: `Size` was missing from the published list, so any
// form holding the component failed to load. Build and run it after changing
// the published property surface, the constructor, or Loaded.
//
//   msbuild Tests\DesignStream\DesignStreamTest.dproj /t:Build /p:Platform=Win64
//   Tests\DesignStream\DesignStreamTest.exe        (prints PASS or FAIL)

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  FMX.Forms,
  FMX.Types,
  FMX.Skia,
  ufDT in 'ufDT.pas' {frmDT},
  uRhoMarkdownViewer;

var
  I, Boxes, Bars: Integer;
  Child: TFmxObject;
begin
  try
    GlobalUseSkia := True;
    Application.Initialize;
    // Direct construction, not Application.CreateForm: CreateForm routes a
    // streaming failure through Application.HandleException, which swallows it
    // and leaves the variable nil.
    frmDT := TfrmDT.Create(nil);

    Writeln('form loaded OK');
    Writeln('  form children = ', frmDT.ChildrenCount);
    for I := 0 to frmDT.ChildrenCount - 1 do
      Writeln('    child[', I, '] = ', frmDT.Children[I].ClassName,
        ' name="', frmDT.Children[I].Name, '"');
    Writeln('  Viewer field assigned = ', BoolToStr(Assigned(frmDT.Viewer), True));
    if not Assigned(frmDT.Viewer) then
    begin
      Writeln('FAIL: the .fmx object did not bind to the form field');
      ExitCode := 1;
      Exit;
    end;
    Writeln('  BlockCount    = ', frmDT.Viewer.BlockCount);
    Writeln('  FontSize      = ', FormatFloat('0.##', frmDT.Viewer.FontSize));
    Writeln('  Markdown line count = ', frmDT.Viewer.Markdown.Count);

    // Duplicate children are the classic Stored:=False failure: the ctor makes
    // them, then streaming makes them again.
    Boxes := 0;
    Bars := 0;
    for I := 0 to frmDT.Viewer.ChildrenCount - 1 do
    begin
      Child := frmDT.Viewer.Children[I];
      if Child.ClassName = 'TSkPaintBox' then Inc(Boxes);
      if Child.ClassName = 'TScrollBar' then Inc(Bars);
    end;
    Writeln('  children      = ', frmDT.Viewer.ChildrenCount,
      '  (paintboxes = ', Boxes, ', scrollbars = ', Bars, ')');

    if (Boxes = 1) and (Bars = 1) and (frmDT.Viewer.BlockCount > 0) then
      Writeln('PASS')
    else
    begin
      Writeln('FAIL');
      ExitCode := 1;
    end;
  except
    on E: Exception do
    begin
      Writeln('FAIL: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

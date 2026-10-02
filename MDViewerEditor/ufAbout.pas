unit ufAbout;

// The About box. Built in code rather than from an .fmx: it is one viewer and
// one button, and the body is markdown rendered by TRhoMarkdownViewer itself -
// so the About box doubles as a small demonstration of the component.

interface

procedure ShowAboutBox(const AVersion: string; ADark: Boolean);

implementation

uses
  System.SysUtils, System.UITypes, System.Types, FMX.Types, FMX.Controls,
  FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Layouts, uRhoMarkdownViewer, uRhoMarkdownMath;

function PlatformText: string;
begin
  Result := Format('%s %d.%d, %d-bit',
    [TOSVersion.Name, TOSVersion.Major, TOSVersion.Minor, SizeOf(Pointer) * 8]);
end;

function MathStatusText: string;
begin
  // The one runtime fact worth reporting: formulas showing as raw LaTeX almost
  // always mean the RaTeX library or its fonts are not beside the executable.
  if RhoMathAvailable then
    Result := 'available'
  else
    Result := 'not found - formulas display as LaTeX source';
end;

function AboutMarkdown(const AVersion: string): string;
begin
  Result :=
    '# AlphaFerro' + sLineBreak +
    sLineBreak +
    '**Version ' + AVersion + '**' + sLineBreak +
    sLineBreak +
    'A live markdown editor and previewer, with fast, native rendering ' +
    'powered by Skia.' + sLineBreak +
    sLineBreak +
    '## Features' + sLineBreak +
    sLineBreak +
    '- GitHub-flavoured markdown: tables, task lists, strikethrough, ' +
    'reference links' + sLineBreak +
    '- Syntax highlighting for 25+ languages, including Antimony' + sLineBreak +
    '- LaTeX math, inline `$x^2$` and display `$$...$$`' + sLineBreak +
    '- Light and dark themes' + sLineBreak +
    '- Find with **Ctrl+F**, then **F3** / **Shift+F3**' + sLineBreak +
    '- Export to PDF' + sLineBreak +
    sLineBreak +
    '## Built with' + sLineBreak +
    sLineBreak +
    '- **TRhoMarkdownViewer** (Rhody Controls)' + sLineBreak +
    '- Delphi FMX and Skia' + sLineBreak +
    '- RaTeX math engine and KaTeX fonts (MIT licence)' + sLineBreak +
    sLineBreak +
    '## System' + sLineBreak +
    sLineBreak +
    '- **Platform:** ' + PlatformText + sLineBreak +
    '- **Math engine:** ' + MathStatusText + sLineBreak +
    sLineBreak +
    '---' + sLineBreak +
    sLineBreak +
    'Copyright &copy; 2026 Herbert Sauro. Released under the MIT licence.' +
    sLineBreak;
end;

procedure ShowAboutBox(const AVersion: string; ADark: Boolean);
var
  Form: TForm;
  Viewer: TRhoMarkdownViewer;
  ButtonBar: TLayout;
  OkButton: TButton;
begin
  Form := TForm.CreateNew(nil);
  try
    Form.Caption := 'About AlphaFerro';
    Form.Width := 520;
    Form.Height := 600;
    Form.Position := TFormPosition.OwnerFormCenter;
    Form.BorderIcons := [TBorderIcon.biSystemMenu];

    ButtonBar := TLayout.Create(Form);
    ButtonBar.Parent := Form;
    ButtonBar.Align := TAlignLayout.Bottom;
    ButtonBar.Height := 48;

    OkButton := TButton.Create(Form);
    OkButton.Parent := ButtonBar;
    OkButton.Text := 'OK';
    OkButton.Width := 90;
    OkButton.Align := TAlignLayout.Right;
    OkButton.Margins.Rect := TRectF.Create(0, 10, 12, 10);
    OkButton.ModalResult := mrOk;
    OkButton.Default := True;
    OkButton.Cancel := True;

    Viewer := TRhoMarkdownViewer.Create(Form);
    Viewer.Parent := Form;
    Viewer.Align := TAlignLayout.Client;
    Viewer.Margins.Rect := TRectF.Create(12, 8, 12, 0);
    if ADark then
      Viewer.ApplyTheme(rtDark)
    else
      Viewer.ApplyTheme(rtLight);
    Viewer.MarkdownText := AboutMarkdown(AVersion);
    // Match the form to the viewer, or the margins show a light frame around a
    // dark-themed body.
    Form.Fill.Kind := TBrushKind.Solid;
    Form.Fill.Color := Viewer.BackgroundColor;

    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

end.

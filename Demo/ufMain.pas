unit ufMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.IOUtils, System.StrUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.StdCtrls, FMX.Controls.Presentation,
  uRhoMarkdownViewer;

type
  TfrmMain = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    FViewer: TRhoMarkdownViewer;
    FThemeBtn: TButton;
    FDark: Boolean;
    procedure ViewerLinkClick(Sender: TObject; const AUrl: string);
    procedure ViewerScroll(Sender: TObject);
    procedure ThemeClick(Sender: TObject);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

const
  SampleMarkdown =
    '# Rho Markdown Viewer'                                           + sLineBreak +
    ''                                                                + sLineBreak +
    'Skeleton stage. Blocks parse and stack; inline styling is not '  +
    'wired up yet, so this paragraph renders as plain text even '     +
    'though the source has **bold** and *italic* in it.'              + sLineBreak +
    ''                                                                + sLineBreak +
    '## What works right now'                                         + sLineBreak +
    ''                                                                + sLineBreak +
    'The parser produces blocks, each block becomes one Skia '        +
    'paragraph, and the paragraphs stack into a scrollable document. '+
    'Word wrap, heading sizes, and the scrollbar are all real.'       + sLineBreak +
    ''                                                                + sLineBreak +
    '### Emoji fallback'                                              + sLineBreak +
    ''                                                                + sLineBreak +
    'Font fallback is configured, so this should render as glyphs '   +
    'and not tofu boxes.'                                             + sLineBreak +
    ''                                                                + sLineBreak +
    '```pascal'                                                       + sLineBreak +
    'procedure Hello;'                                                + sLineBreak +
    'begin'                                                           + sLineBreak +
    '  WriteLn(''Hi'');'                                              + sLineBreak +
    'end;'                                                            + sLineBreak +
    '```'                                                             + sLineBreak +
    ''                                                                + sLineBreak +
    '> A block quote renders italic for now, with no quote bar.'      + sLineBreak +
    '';

procedure TfrmMain.ThemeClick(Sender: TObject);
begin
  FDark := not FDark;
  if FDark then
    FViewer.ApplyTheme(rtDark)
  else
    FViewer.ApplyTheme(rtLight);
  FThemeBtn.Text := 'Theme: ' + IfThen(FDark, 'Dark', 'Light');
end;

procedure TfrmMain.ViewerScroll(Sender: TObject);
begin
  // Shows OnScroll firing, and gives the keyboard scrolling something visible
  // to confirm against.
  Caption := Format('Markdown Viewer  -  scroll %.0f of %.0f',
    [FViewer.ScrollY, FViewer.ContentHeight]);
end;

procedure TfrmMain.ViewerLinkClick(Sender: TObject; const AUrl: string);
begin
  Caption := 'Markdown Viewer  -  clicked: ' + AUrl;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  SamplePath: string;
begin
  FThemeBtn := TButton.Create(Self);
  FThemeBtn.Parent := Self;
  FThemeBtn.Align := TAlignLayout.Top;
  FThemeBtn.Height := 32;
  FThemeBtn.Text := 'Theme: Light';
  FThemeBtn.OnClick := ThemeClick;

  FViewer := TRhoMarkdownViewer.Create(Self);
  FViewer.Parent := Self;
  FViewer.Align := TAlignLayout.Client;
  // Show the Url in the caption rather than launching a browser, so clicking
  // links while testing stays non-disruptive. Remove this handler to get the
  // default behaviour (open in the system browser).
  FViewer.OnLinkClick := ViewerLinkClick;
  FViewer.OnScroll := ViewerScroll;

  // sample.md lives beside the project source and exercises every feature the
  // layout pass implements. Fall back to the inline sample if it is missing.
  SamplePath := TPath.Combine(
    TPath.GetDirectoryName(ParamStr(0)), '..\..\sample.md');
  if TFile.Exists(SamplePath) then
    FViewer.LoadFromFile(SamplePath)
  else
    FViewer.MarkdownText := SampleMarkdown;
end;

end.

unit ufMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo.Types,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, uRhoMarkdownViewer,
  FMX.StdCtrls, FMX.Layouts, FMX.ListBox, uExamples, System.Math, FMX.Menus,
  FMX.Edit;

type
  TfrmMain = class(TForm)
    Layout1: TLayout;
    TextLayoutPanel: TLayout;
    PanelSplitter: TSplitter;
    FViewer: TRhoMarkdownViewer;
    TextMemo: TMemo;
    btnOpen: TButton;
    cboCombo: TComboBox;
    btnTheme: TButton;
    btnUpdate: TButton;
    btnNew: TButton;
    Label1: TLabel;
    btnSave: TButton;
    Layout4: TLayout;
    lblFileName: TLabel;
    btnOpenClosePanel: TSpeedButton;
    MainMenu1: TMainMenu;
    mnuFile: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    mnuNew: TMenuItem;
    mnuOpen: TMenuItem;
    MenuItem6: TMenuItem;
    mnuQuit: TMenuItem;
    MenuItem8: TMenuItem;
    // Find bar. The viewer owns matching, highlighting and scrolling; this is
    // only the UI that drives it - see the find section of the component's
    // CLAUDE.md for why the split falls there.
    FindBar: TLayout;
    lblFind: TLabel;
    edtFind: TEdit;
    btnFindPrev: TButton;
    btnFindNext: TButton;
    chkMatchCase: TCheckBox;
    chkWholeWord: TCheckBox;
    lblFindStatus: TLabel;
    btnFindClose: TButton;
    mnuFind: TMenuItem;
    procedure btnOpenClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure cboComboChange(Sender: TObject);
    procedure FViewerDragOver(Sender: TObject;
      const Data: TDragObject; const Point: TPointF;
      var Operation: TDragOperation);
    procedure FViewerDragDrop(Sender: TObject;
      const Data: TDragObject; const Point: TPointF);
    procedure btnNewClick(Sender: TObject);
    procedure btnThemeClick(Sender: TObject);
    procedure btnUpdateClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnOpenClosePanelClick(Sender: TObject);
    procedure MenuItem8Click(Sender: TObject);
    procedure mnuFindClick(Sender: TObject);
    procedure edtFindChangeTracking(Sender: TObject);
    procedure edtFindKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: WideChar; Shift: TShiftState);
    procedure btnFindNextClick(Sender: TObject);
    procedure btnFindPrevClick(Sender: TObject);
    procedure btnFindCloseClick(Sender: TObject);
    procedure FindOptionChange(Sender: TObject);
  private
    { Private declarations }
    // Guards against the two scroll handlers driving each other in a loop:
    // syncing the viewer moves the memo, whose OnViewportPositionChange would
    // otherwise fire straight back into the viewer.
    FSyncing: Boolean;
    FDark : Boolean;
    function SelectMDFileForOpening : string;
    function SelectMDFileForSaving : string;
    // Proportional two-way scroll sync between the editor (Memo1) and the
    // preview (RhoMarkdownViewer1). Positions map by fraction-of-scrollable
    // range, since the two have unrelated content heights.
    procedure MemoViewportChange(Sender: TObject;
      const OldViewportPosition, NewViewportPosition: TPointF;
      const ContentSizeChanged: Boolean);
    procedure ViewerScroll(Sender: TObject);
    // A task checkbox was toggled in the preview: the viewer has already
    // rewritten its own source, so mirror it back into the editor memo.
    procedure ViewerTaskToggle(Sender: TObject; const AText: string; AChecked: Boolean);
      procedure ChangeTheme;
    // Find bar plumbing.
    procedure ShowFindBar;
    procedure CloseFindBar;
    // Fired by the viewer whenever the search state changes - the only place
    // the match counter is written, so it cannot drift out of step.
    procedure ViewerSearchChange(Sender: TObject);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

Uses IOUtils;

Const
   VERSION = '0.5';

type
  TComboBoxHelper = class helper for TComboBox
    procedure AddWithTag(const AText: string; const ATag: string);
  end;

procedure TComboBoxHelper.AddWithTag(const AText: string; const ATag: string);
var
  Item: TListBoxItem;
begin
  Item := TListBoxItem.Create(Self);
  Item.Text := AText;
  Item.TagString := ATag;
  Self.AddObject(Item);
end;


procedure TfrmMain.btnNewClick(Sender: TObject);
begin
   FViewer.MarkdownText := '';
   TextMemo.Lines.Clear;
end;

procedure TfrmMain.btnOpenClick(Sender: TObject);
var FileName: string;
begin
  FileName := SelectMDFileForOpening;
  if FileName = '' then
    Exit;
  // LoadFromFile sets BasePath to the file's folder BEFORE parsing, so relative
  // image paths in the document resolve. Assigning MarkdownText does not.
  FViewer.LoadFromFile(FileName);
  TextMemo.Text := FViewer.MarkdownText;
  lblFileName.Text := ExtractFileName(FileName);
end;

procedure TfrmMain.btnOpenClosePanelClick(Sender: TObject);
begin
  if TextLayoutPanel.Visible then
     begin
     TextLayoutPanel.Visible := False;
     PanelSplitter.Visible := False;
     end
  else
     begin
     TextLayoutPanel.Visible := True;
     PanelSplitter.Visible := True;
     end;
end;

procedure TfrmMain.btnSaveClick(Sender: TObject);
var FileName: string;
begin
  FileName := SelectMDFileForSaving;
  if FileName = '' then
      Exit;
  lblFileName.Text := ExtractFileName (FileName);
  TFile.WriteAllText(FileName, TextMemo.Text);
end;

procedure TfrmMain.btnThemeClick(Sender: TObject);
begin
  ChangeTheme;
end;


procedure TfrmMain.btnUpdateClick(Sender: TObject);
begin
   FViewer.MarkdownText := TextMemo.text;
end;

procedure TfrmMain.ChangeTheme;
begin
  FDark := not FDark;
  if FDark then
    FViewer.ApplyTheme(rtDark)
  else
    FViewer.ApplyTheme(rtLight);
  If FDark then
     BtnTheme.Text := 'Theme: Dark'
  else BtnTheme.Text := 'Theme: Light';
end;

procedure TfrmMain.cboComboChange(Sender: TObject);
begin
   TextMemo.Text := cboCombo.Selected.TagString;
   FViewer.MarkdownText := cboCombo.Selected.TagString;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  cboCombo.AddWithTag('Example1', GetExample1);
  cboCombo.AddWithTag('Example2', GetExample2);
  cboCombo.AddWithTag('Tables', GetExample3);
  cboCombo.AddWithTag('Text Stlyes', GetExample4);
  cboCombo.AddWithTag('Containers & HTML', GetExample5);

  // Wire scroll sync in code so the .fmx carries no event bindings.
  TextMemo.OnViewportPositionChange := MemoViewportChange;
  FViewer.OnScroll := ViewerScroll;

  // Interactive task checkboxes, mirrored back into the editor.
  FViewer.AllowTaskToggle := True;
  FViewer.OnTaskToggle := ViewerTaskToggle;

  // Find. Ctrl+F opens the bar (Edit menu); the viewer handles F3 / Shift+F3
  // itself once it has focus.
  FViewer.OnSearchChange := ViewerSearchChange;
  FindBar.Visible := False;
  lblFindStatus.Text := '';
  // TMenuItem.ShortCut is a TShortCut (an integer), not a string - streaming
  // 'Ctrl+F' from the .fmx raises "Invalid property value" and takes the whole
  // form down with it. Set it through TextToShortCut instead of hard-coding
  // the magic number.
  mnuFind.ShortCut := TextToShortCut('Ctrl+F');

  lblFileName.Text := '(untitled)';
  FDark := False;

  if ParamCount > 0 then
     begin
     If FileExists (ParamStr (1)) then
        begin
        FViewer.LoadFromFile(ParamStr (1));
        TextMemo.Text := FViewer.MarkdownText;
        end;
     end;
end;

procedure TfrmMain.ViewerTaskToggle(Sender: TObject; const AText: string;
  AChecked: Boolean);
var
  SavedPos: TPointF;
begin
  // The viewer already toggled and kept its own scroll. Mirror the rewritten
  // source into the memo and restore the memo's own scroll. The viewer is not
  // dragged: MemoViewportChange ignores the ContentSizeChanged event this
  // triggers, and FSyncing covers the synchronous part.
  FSyncing := True;
  try
    SavedPos := TextMemo.ViewportPosition;
    TextMemo.Text := FViewer.MarkdownText;
    TextMemo.ViewportPosition := SavedPos;
  finally
    FSyncing := False;
  end;
end;

procedure TfrmMain.MemoViewportChange(Sender: TObject;
  const OldViewportPosition, NewViewportPosition: TPointF;
  const ContentSizeChanged: Boolean);
var
  MemoMax, ViewerMax, Frac: Single;
begin
  if FSyncing then
    Exit;
  // Only a genuine user scroll should drive the viewer. Setting Memo1.Text
  // (e.g. mirroring a task toggle) changes the content size, and FMX then posts
  // a deferred viewport-change with ContentSizeChanged=True - that is the event
  // that nudged the viewer half a line. Ignore those; sync only real scrolls.
  if ContentSizeChanged then
    Exit;
  MemoMax := Max(0, TextMemo.ContentBounds.Height - TextMemo.Height);
  if MemoMax <= 0 then
    Frac := 0
  else
    Frac := NewViewportPosition.Y / MemoMax;
  ViewerMax := Max(0, FViewer.ContentHeight - FViewer.Height);
  FSyncing := True;
  try
    FViewer.SetScrollPos(Frac * ViewerMax);
  finally
    FSyncing := False;
  end;
end;

procedure TfrmMain.MenuItem8Click(Sender: TObject);
begin
  showmessage ('Version: ' + VERSION);
end;

{ ---- find bar ----

  Everything here is host-side UI. The viewer does the matching, draws the
  highlights and scrolls a hit into view; this bar just supplies the term, the
  two options, and somewhere to show the count. }

procedure TfrmMain.mnuFindClick(Sender: TObject);
begin
  ShowFindBar;
end;

procedure TfrmMain.ShowFindBar;
var
  Seed: string;
begin
  FindBar.Visible := True;
  // Seed from the preview's selection, the way most editors do - but only a
  // single line of it, since a multi-line selection is never a useful term.
  if FViewer.HasSelection then
  begin
    Seed := Trim(FViewer.SelectedText(True));
    if (Seed <> '') and (Pos(#10, Seed) = 0) and (Pos(#13, Seed) = 0) then
      edtFind.Text := Seed;
  end;
  edtFind.SetFocus;
  edtFind.SelectAll;
  FViewer.SearchText := edtFind.Text;   // fires OnSearchChange -> the counter
end;

procedure TfrmMain.CloseFindBar;
begin
  // Drop the highlights with the bar, or the document stays marked up with a
  // search the user can no longer see the term for.
  FViewer.ClearSearch;
  FindBar.Visible := False;
end;

procedure TfrmMain.btnFindCloseClick(Sender: TObject);
begin
  CloseFindBar;
end;

procedure TfrmMain.ViewerSearchChange(Sender: TObject);
begin
  if FViewer.SearchText = '' then
    lblFindStatus.Text := ''
  else if FViewer.SearchMatchCount = 0 then
    lblFindStatus.Text := 'No matches'
  else if FViewer.SearchMatchIndex < 0 then
    lblFindStatus.Text := Format('%d matches', [FViewer.SearchMatchCount])
  else
    lblFindStatus.Text := Format('%d of %d',
      [FViewer.SearchMatchIndex + 1, FViewer.SearchMatchCount]);
end;

procedure TfrmMain.edtFindChangeTracking(Sender: TObject);
begin
  FViewer.SearchText := edtFind.Text;
  // Incremental jump. Assigning SearchText highlights but deliberately does
  // not scroll, so stepping to a hit is the host's call to make; assignment
  // also resets the current match, so this lands on the first hit at or below
  // the viewport rather than walking forward on every keystroke.
  if FViewer.SearchMatchCount > 0 then
    FViewer.FindNext;
end;

procedure TfrmMain.edtFindKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: WideChar; Shift: TShiftState);
begin
  if Key = vkReturn then
  begin
    if ssShift in Shift then
      FViewer.FindPrevious
    else
      FViewer.FindNext;
    Key := 0;
  end
  else if Key = vkEscape then
  begin
    CloseFindBar;
    Key := 0;
  end;
end;

procedure TfrmMain.btnFindNextClick(Sender: TObject);
begin
  FViewer.FindNext;
end;

procedure TfrmMain.btnFindPrevClick(Sender: TObject);
begin
  FViewer.FindPrevious;
end;

procedure TfrmMain.FindOptionChange(Sender: TObject);
begin
  FViewer.SearchCaseSensitive := chkMatchCase.IsChecked;
  FViewer.SearchWholeWords := chkWholeWord.IsChecked;
  // Both setters reset the current match, so re-land on one rather than
  // leaving the view parked where the old match used to be.
  if FViewer.SearchMatchCount > 0 then
    FViewer.FindNext;
end;

procedure TfrmMain.ViewerScroll(Sender: TObject);
var
  ViewerMax, MemoMax, Frac: Single;
begin
  if FSyncing then
    Exit;
  ViewerMax := Max(0, FViewer.ContentHeight - FViewer.Height);
  if ViewerMax <= 0 then
    Frac := 0
  else
    Frac := FViewer.ScrollY / ViewerMax;
  MemoMax := Max(0, TextMemo.ContentBounds.Height - TextMemo.Height);
  FSyncing := True;
  try
    TextMemo.ViewportPosition := PointF(TextMemo.ViewportPosition.X, Frac * MemoMax);
  finally
    FSyncing := False;
  end;
end;


function TfrmMain.SelectMDFileForOpening : string;
var
  OpenDialog: TOpenDialog;
begin
  // Create the OpenDialog component on the fly
  OpenDialog := TOpenDialog.Create(nil);
  try
    // Configure dialog properties
    OpenDialog.Title := 'Select a Markdown (.md) File';
    OpenDialog.Filter := 'Markdown Files (*.md)|*.md|All Files (*.*)|*.*';
    OpenDialog.InitialDir := GetCurrentDir; // Starts in the current directory
    OpenDialog.FilterIndex := 1;
    OpenDialog.Options := [TOpenOption.ofOverwritePrompt];

    Result := '';
    // Show the dialog
    if OpenDialog.Execute then
    begin
      Result := OpenDialog.FileName;
    end;
  finally
    // Free the memory to prevent memory leaks
    OpenDialog.Free;
  end;
end;


function TfrmMain.SelectMDFileForSaving : string;
var
  SaveDialog: TSaveDialog;
begin
  // Create the OpenDialog component on the fly
  SaveDialog := TSaveDialog.Create(nil);
  try
    // Configure dialog properties
    SaveDialog.Title := 'Select a Markdown (.md) File';
    SaveDialog.Filter := 'Markdown Files (*.md)|*.md|All Files (*.*)|*.*';
    SaveDialog.InitialDir := GetCurrentDir; // Starts in the current directory
    SaveDialog.FilterIndex := 1;
    SaveDialog.Options := [TOpenOption.ofFileMustExist];

    Result := '';
    // Show the dialog
    if SaveDialog.Execute then
    begin
      Result := SaveDialog.FileName;
    end;
  finally
    // Free the memory to prevent memory leaks
    SaveDialog.Free;
  end;
end;

procedure TfrmMain.FViewerDragDrop(Sender: TObject;
  const Data: TDragObject; const Point: TPointF);
begin
  // Loop through the file array provided by the OS
  if Length(Data.Files) > 0 then
     begin
     FViewer.LoadFromFile(Data.Files[0]);
     TextMemo.Text := FViewer.MarkdownText;
     end;
end;


procedure TfrmMain.FViewerDragOver(Sender: TObject;
  const Data: TDragObject; const Point: TPointF; var Operation: TDragOperation);
begin
  // Default to refusing the drop (displays the "no-drop" cursor)
  Operation := TDragOperation.None;

  // Check if what is hovering over the control contains external files
  if Length(Data.Files) > 0 then
  begin
    // You accept the drop by specifying the operation type.
    // This tells the OS to show the standard "+" copy cursor.
    Operation := TDragOperation.Copy;
  end;
end;

end.

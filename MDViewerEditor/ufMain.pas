unit ufMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Memo.Types,
  FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, uRhoMarkdownViewer,
  FMX.StdCtrls, FMX.Layouts, FMX.ListBox, uExamples, System.Math;

type
  TfrmMain = class(TForm)
    Layout1: TLayout;
    Layout2: TLayout;
    Splitter1: TSplitter;
    FViewer: TRhoMarkdownViewer;
    TextMemo: TMemo;
    btnOpen: TButton;
    cboCombo: TComboBox;
    btnTheme: TButton;
    btnUpdate: TButton;
    btnNew: TButton;
    Label1: TLabel;
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
  private
    { Private declarations }
    // Guards against the two scroll handlers driving each other in a loop:
    // syncing the viewer moves the memo, whose OnViewportPositionChange would
    // otherwise fire straight back into the viewer.
    FSyncing: Boolean;
    FDark : Boolean;
    function SelectMDFile : string;
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
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

Uses IOUtils;

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
  FileName := SelectMDFile;
  if FileName = '' then
    Exit;
  // LoadFromFile sets BasePath to the file's folder BEFORE parsing, so relative
  // image paths in the document resolve. Assigning MarkdownText does not.
  FViewer.LoadFromFile(FileName);
  TextMemo.Text := FViewer.MarkdownText;
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

  FDark := False;
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


function TfrmMain.SelectMDFile : string;
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
    OpenDialog.Options := [TOpenOption.ofFileMustExist];

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

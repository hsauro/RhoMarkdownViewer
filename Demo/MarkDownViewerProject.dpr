program MarkDownViewerProject;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  ufMain in 'ufMain.pas' {frmMain};

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

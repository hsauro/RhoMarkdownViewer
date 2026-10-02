program AlphaFerro;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  uFontHandling in 'uFontHandling.pas',
  ufMain in 'ufMain.pas' {frmMain},
  uExamples in 'uExamples.pas',
  ufAbout in 'ufAbout.pas';

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

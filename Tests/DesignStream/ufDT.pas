unit ufDT;

interface

uses
  System.SysUtils, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms,
  uRhoMarkdownViewer;

type
  TfrmDT = class(TForm)
    Viewer: TRhoMarkdownViewer;
  end;

var
  frmDT: TfrmDT;

implementation

{$R *.fmx}

end.

unit uRhoMarkdownViewerReg;

{
  Design-time registration for TRhoMarkdownViewer.

  This unit is compiled into the DESIGN-TIME package (dclRhoMarkdownViewer)
  only. Keeping Register out of the runtime package is what lets an application
  link the component without dragging in designide.
}

interface

procedure Register;

implementation

uses
  System.Classes,
  FMX.Types,
  uRhoMarkdownViewer;

procedure Register;
begin
  // States the FireMonkey grouping at the point of registration. Redundant in
  // practice - a TControl descendant is in the TFmxObject group by ancestry,
  // which is why the VCL only calls this for non-TControl classes such as
  // image lists and actions - but harmless and self-documenting.
  GroupDescendentsWith(TRhoMarkdownViewer, FMX.Types.TFmxObject);
  RegisterComponents('Rhody Controls', [TRhoMarkdownViewer]);
end;

end.

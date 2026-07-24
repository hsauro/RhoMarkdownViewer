program RhoMarkdownTests;

{
  DUnitX tests for the non-visual side of TRhoMarkdownViewer: the document
  model, the block/inline parser, the syntax highlighters, and HTML export.

  Deliberately console-only and framework-free - nothing here touches FMX or
  Skia, so the parse layer stays testable without a UI. The VCL version's
  renderer and control tests were dropped in the port: they asserted GDI
  integer-pixel metrics that Skia's float layout does not reproduce.
}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  uRhoMarkdownTypes in '..\Source\uRhoMarkdownTypes.pas',
  uRhoMarkdownHighlight in '..\Source\uRhoMarkdownHighlight.pas',
  uRhoMarkdownParser in '..\Source\uRhoMarkdownParser.pas',
  uRhoMarkdownHtml in '..\Source\uRhoMarkdownHtml.pas',
  Test.RhoMarkdown.Model in 'Test.RhoMarkdown.Model.pas',
  Test.RhoMarkdown.Parser in 'Test.RhoMarkdown.Parser.pas',
  Test.RhoMarkdown.Highlight in 'Test.RhoMarkdown.Highlight.pas',
  Test.RhoMarkdown.Html in 'Test.RhoMarkdown.Html.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
    Runner.AddLogger(TDUnitXXMLNUnitFileLogger.Create(
      TDUnitX.Options.XMLOutputFile));
    Results := Runner.Execute;
    if not Results.AllPassed then
      ExitCode := EXIT_ERRORS;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := EXIT_ERRORS;
    end;
  end;
end.

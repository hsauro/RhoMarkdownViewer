unit Test.RhoMarkdown.Model;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkDownModelTests = class
  public
    // NOTE the VCL version's NewBlockHasInvalidLayout test is gone with the
    // LayoutTop/LayoutHeight/LayoutWidth fields it asserted. Layout no longer
    // lives on the block - it belongs to the viewer's display list.
    [Test]
    procedure BlockOwnsInlineTokens;
  end;

implementation

uses
  uRhoMarkdownTypes;

procedure TMarkDownModelTests.BlockOwnsInlineTokens;
var
  Block: TMarkDownBlock;
begin
  Block := TMarkDownBlock.Create;
  Block.InlineTokens := TMarkDownInlineList.Create;
  Block.InlineTokens.Add(Default(TMarkDownInlineToken));
  // Explicit type argument: the untyped literal 1 leaves AreEqual's generic
  // parameter ambiguous on Win64 (the VCL project built Win32).
  Assert.AreEqual<Integer>(1, Block.InlineTokens.Count);
  Block.Free;
end;

initialization
  TDUnitX.RegisterTestFixture(TMarkDownModelTests);

end.

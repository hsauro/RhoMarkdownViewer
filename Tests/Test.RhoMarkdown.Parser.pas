unit Test.RhoMarkdown.Parser;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TMarkDownParserTests = class
  public
    [Test]
    procedure ParsesHeading;
    [Test]
    procedure ParsesHeadingClosingSequence;
    [Test]
    procedure ParsesNestedOrderedListItem;
    [Test]
    procedure ParsesParenOrderedListItem;
    [Test]
    procedure ExtractsCheckedTask;
    [Test]
    procedure RecognizesTableStart;
    [Test]
    procedure RecognizesTableStartWithShortDashRuns;
    [Test]
    procedure RejectsTableStartWithoutDashes;
    [Test]
    procedure ParseBlocksJoinsParagraphLines;
    [Test]
    procedure ParseBlocksGroupsFencedCode;
    [Test]
    procedure ParseBlocksExtractsFenceLanguage;
    [Test]
    procedure ParseBlocksLongFenceContainsBackticks;
    [Test]
    procedure ParseBlocksTildeFenceContainsBackticks;
    [Test]
    procedure ParseBlocksShortFenceDoesNotCloseLongOne;
    [Test]
    procedure ParseBlocksLongFenceKeepsSourceMap;
    [Test]
    procedure ParseBlocksParsesIndentedCode;
    [Test]
    procedure ParseBlocksIndentedCodeKeepsInteriorBlank;
    [Test]
    procedure ParseBlocksIndentedCodeDoesNotInterruptParagraph;
    [Test]
    procedure ParseBlocksIndentedCodeDeclinesAfterListItem;
    [Test]
    procedure ParseBlocksMergesQuoteLines;
    [Test]
    procedure ParseBlocksNestsQuote;
    [Test]
    procedure ParseBlocksParsesListInsideQuote;
    [Test]
    procedure ParseBlocksParenOrderedList;
    [Test]
    procedure ParseBlocksParenOrderedListKeepsSourceMap;
    [Test]
    procedure ParseBlocksNestsSecondParagraphInItem;
    [Test]
    procedure ParseBlocksNestsCodeBlockInItem;
    [Test]
    procedure ParseBlocksItemContinuationStopsAtNextItem;
    [Test]
    procedure ParseBlocksGroupsTableRows;
    [Test]
    procedure ParseBlocksSkipsLinkReferenceDefinitions;
    [Test]
    procedure ParseBlocksParsesFrontMatter;
    [Test]
    procedure ParseBlocksLoneDashesAreRule;
    [Test]
    procedure ParseBlocksParsesImageBlock;
    [Test]
    procedure ParseBlocksStripsImageTitle;
    [Test]
    procedure ParseInlineStripsImageTitle;
    [Test]
    procedure ParseBlocksParsesTaskListItem;
    [Test]
    procedure ParseBlocksHonorsStartLine;
    [Test]
    procedure ParseBlocksTreatsHashWithoutSpaceAsParagraph;
    [Test]
    procedure ParseBlocksRequiresSeparatorForTable;
    [Test]
    procedure ParseBlocksAddsHardBreakForTrailingSpaces;
    [Test]
    procedure ParseBlocksAddsHardBreakForTrailingBackslash;
    [Test]
    procedure ParseInlineParsesEmphasisCodeAndStrike;
    [Test]
    procedure ParseInlineParsesBoldItalic;
    [Test]
    procedure ParseInlineNestsEmphasis;
    [Test]
    procedure ParseInlineStylesLinkText;
    [Test]
    procedure ParseInlineIgnoresUnderscoreInsideWords;
    [Test]
    procedure ParseInlineIgnoresSpacedAsterisks;
    [Test]
    procedure ParseInlineRespectsEscapes;
    [Test]
    procedure ParseInlineMapsHtmlFormattingTags;
    [Test]
    procedure ParseInlineNestsHtmlTags;
    [Test]
    procedure ParseInlineHtmlBreakTag;
    [Test]
    procedure ParseInlineLeavesUnknownTagLiteral;
    [Test]
    procedure ParseInlineLeavesUnclosedTagLiteral;
    [Test]
    procedure ParseInlineParsesHtmlImageWithSize;
    [Test]
    procedure ParseInlineParsesHtmlImageAlign;
    [Test]
    procedure ParseBlocksParsesAlignContainerOneLine;
    [Test]
    procedure ParseBlocksParsesAlignContainerMultiLine;
    [Test]
    procedure ParseBlocksBareDivIsNotAContainer;
    [Test]
    procedure ParseBlocksUnclosedAlignContainerStaysLiteral;
    [Test]
    procedure ParseBlocksAlignContainerNests;
    [Test]
    procedure ParseInlineImageAlignDefaultsToUnset;
    [Test]
    procedure ParseInlineParsesInlineLink;
    [Test]
    procedure ParseInlineStripsLinkTitle;
    [Test]
    procedure ParseInlineResolvesReferenceLink;
    [Test]
    procedure ParseInlineResolvesShortcutReferenceLink;
    [Test]
    procedure ParseInlineLeavesUnmatchedShortcutLiteral;
    [Test]
    procedure ParseInlineParsesInlineMath;
    [Test]
    procedure ParseInlineParsesDisplayMathSpan;
    [Test]
    procedure ParseInlineLeavesCurrencyAlone;
    [Test]
    procedure ParseInlineLeavesEscapedDollarLiteral;
    [Test]
    procedure ParseInlineMathDoesNotCrossCodeSpan;
    [Test]
    procedure ParseInlineMathKeepsSourceMap;
    [Test]
    procedure ParseBlocksParsesMathFence;
    [Test]
    procedure ParseBlocksParsesDollarMathBlock;
    [Test]
    procedure ParseBlocksParsesOneLineMathBlock;
    [Test]
    procedure ParseBlocksLeavesUnclosedMathBlockAsText;
    [Test]
    procedure ParseInlineDetectsAutoLink;
    [Test]
    procedure ParseInlineEmitsHardLineBreakToken;
    [Test]
    procedure ParseInlineDetectsEmailAutoLink;
    [Test]
    procedure ParseInlineDecodesHtmlEntities;
    [Test]
    procedure ParseInlineLeavesInvalidEntityLiteral;
    [Test]
    procedure IsSetextUnderlineRecognizesUnderlines;
    [Test]
    procedure ParseBlocksParsesSetextHeadings;
    [Test]
    procedure ParseBlocksKeepsRuleWithoutParagraph;
    [Test]
    procedure ParseInlineLeavesUnterminatedEmphasisAsText;
    [Test]
    procedure ParseInlineLeavesUnterminatedCodeAsText;
    [Test]
    procedure ExtractLinkReferencesCollectsUrls;
    [Test]
    procedure CountLeadingSpacesCountsSpacesAndTabs;
    [Test]
    procedure TrimLeftOnlyRemovesLeadingWhitespaceOnly;
    [Test]
    procedure StartsWithFenceRecognizesIndentedFence;
    [Test]
    procedure IsClosingFenceRequiresSameCharAndLength;
    [Test]
    procedure IsRuleLineAcceptsRulesAndRejectsOthers;
    [Test]
    procedure IsPipeTableRowDetectsPipe;
    [Test]
    procedure SplitTableRowSplitsCells;
    [Test]
    procedure SplitTableRowKeepsEscapedPipe;
    [Test]
    procedure TryParseImageParsesAltAndUrl;
    [Test]
    procedure TryParseImageRejectsNonImage;
    [Test]
    procedure TryParseLinkReferenceParsesNameAndUrl;
    [Test]
    procedure TryParseLinkReferenceDropsTitle;
    [Test]
    procedure TryParseListItemHandlesBulletsAndNumbers;
    [Test]
    procedure TryParseListItemRejectsPlainText;
    [Test]
    procedure SourceMapMapsParagraphToSource;
    [Test]
    procedure SourceMapHandlesMultiLineParagraphJoin;
    [Test]
    procedure SourceMapHandlesHardBreakParagraph;
    [Test]
    procedure SourceMapHandlesAtxHeadingOffset;
    [Test]
    procedure SourceMapHandlesMarkupAndEntities;
    [Test]
    procedure SourceMapHandlesQuoteAcrossLines;
    [Test]
    procedure SourceMapHandlesIndentedHeading;
    [Test]
    procedure TokenMapLocatesBoldSpan;
    [Test]
    procedure TokenMapHandlesEntity;
    [Test]
    procedure TokenMapHandlesAutoLink;
    [Test]
    procedure SourceMapHandlesListItem;
    [Test]
    procedure SourceMapHandlesImageAlt;
    [Test]
    procedure SourceMapHandlesCodeBlock;
    [Test]
    procedure SourceMapHandlesTable;
    [Test]
    procedure ParseInlineParsesEmojiShortcodes;
    [Test]
    procedure TokenMapHandlesEmoji;
    [Test]
    procedure ParseInlineParsesHighlight;
    [Test]
    procedure TokenMapHandlesHighlight;
    [Test]
    procedure ParseInlineParsesSubSuper;
    [Test]
    procedure TokenMapHandlesSubSuper;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  System.UITypes,
  uRhoMarkdownTypes,
  uRhoMarkdownParser;

// CommonMark's optional closing sequence. The run of '#' only closes the
// heading when whitespace precedes it, so an interior or word-joined '#' stays.
procedure TMarkDownParserTests.ParsesHeadingClosingSequence;
var
  Text: string;
  Level: Integer;
begin
  Assert.IsTrue(TMarkDownBlockParser.TryParseHeading('### Heading ###', Text,
    Level));
  Assert.AreEqual<Integer>(3, Level);
  Assert.AreEqual('Heading', Text);

  // The closing run need not match the opening one in length.
  Assert.IsTrue(TMarkDownBlockParser.TryParseHeading('## Heading #####', Text,
    Level));
  Assert.AreEqual('Heading', Text);

  // Content that is nothing but hashes leaves an empty heading.
  Assert.IsTrue(TMarkDownBlockParser.TryParseHeading('## ##', Text, Level));
  Assert.AreEqual('', Text);

  // Not a closing sequence: no whitespace before the run.
  Assert.IsTrue(TMarkDownBlockParser.TryParseHeading('### foo#', Text, Level));
  Assert.AreEqual('foo#', Text);
  Assert.IsTrue(TMarkDownBlockParser.TryParseHeading('### a#b', Text, Level));
  Assert.AreEqual('a#b', Text);

  // A plain heading is unaffected.
  Assert.IsTrue(TMarkDownBlockParser.TryParseHeading('# Plain', Text, Level));
  Assert.AreEqual('Plain', Text);
end;

procedure TMarkDownParserTests.ParsesHeading;
var
  Text: string;
  Level: Integer;
begin
  Assert.IsTrue(TMarkDownBlockParser.TryParseHeading('### Heading', Text,
    Level));
  Assert.AreEqual<Integer>(3, Level);
  Assert.AreEqual('Heading', Text);
end;

procedure TMarkDownParserTests.ParsesNestedOrderedListItem;
var
  Text: string;
  Ordered: Boolean;
  Number: Integer;
  IndentLevel: Integer;
begin
  Assert.IsTrue(TMarkDownBlockParser.TryParseListItem('    12. Item', Text,
    Ordered, Number, IndentLevel));
  Assert.IsTrue(Ordered);
  Assert.AreEqual<Integer>(12, Number);
  Assert.AreEqual<Integer>(2, IndentLevel);
  Assert.AreEqual('Item', Text);
end;

// `1)` is as valid a GFM ordered marker as `1.`; the delimiter is not carried
// on the block, so both produce the same Ordered/Number.
procedure TMarkDownParserTests.ParsesParenOrderedListItem;
var
  Text: string;
  Ordered: Boolean;
  Number: Integer;
  IndentLevel: Integer;
begin
  Assert.IsTrue(TMarkDownBlockParser.TryParseListItem('1) Item', Text,
    Ordered, Number, IndentLevel));
  Assert.IsTrue(Ordered);
  Assert.AreEqual<Integer>(1, Number);
  Assert.AreEqual<Integer>(0, IndentLevel);
  Assert.AreEqual('Item', Text);

  // Indented, multi-digit, and starting at something other than 1 - the same
  // cases the '.' form supports.
  Assert.IsTrue(TMarkDownBlockParser.TryParseListItem('    12) Nested', Text,
    Ordered, Number, IndentLevel));
  Assert.IsTrue(Ordered);
  Assert.AreEqual<Integer>(12, Number);
  Assert.AreEqual<Integer>(2, IndentLevel);
  Assert.AreEqual('Nested', Text);

  // A ')' with no digits before it is not a marker.
  Assert.IsFalse(TMarkDownBlockParser.TryParseListItem(') no digits', Text,
    Ordered, Number, IndentLevel));
  // Nor is one with no space after it.
  Assert.IsFalse(TMarkDownBlockParser.TryParseListItem('1)no space', Text,
    Ordered, Number, IndentLevel));
end;

procedure TMarkDownParserTests.ExtractsCheckedTask;
var
  Text: string;
  IsTask: Boolean;
  Checked: Boolean;
begin
  Text := '[x] Completed';
  TMarkDownBlockParser.ExtractTaskMarker(Text, IsTask, Checked);
  Assert.IsTrue(IsTask);
  Assert.IsTrue(Checked);
  Assert.AreEqual('Completed', Text);
end;

procedure TMarkDownParserTests.RecognizesTableStart;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('| Left | Right |');
    Lines.Add('| :--- | ---: |');
    Assert.IsTrue(TMarkDownBlockParser.IsTableStart(Lines, 0));
  finally
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.RecognizesTableStartWithShortDashRuns;
var
  Lines: TStringList;
  Blocks: TMarkDownBlockList;
begin
  // GFM needs only one dash per delimiter cell. Requiring three quietly
  // demoted a "| :-- | :-- |" table to a run of paragraphs.
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('| # | Status |');
    Lines.Add('| :-- | :- |');
    Lines.Add('| M0 | done |');
    Assert.IsTrue(TMarkDownBlockParser.IsTableStart(Lines, 0));
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkTable);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.RejectsTableStartWithoutDashes;
var
  Lines: TStringList;
begin
  // A delimiter cell still needs at least one dash - a bare "| : |" or a row
  // of prose must not be mistaken for one.
  Lines := TStringList.Create;
  try
    Lines.Add('| a | b |');
    Lines.Add('| : | : |');
    Assert.IsFalse(TMarkDownBlockParser.IsTableStart(Lines, 0));
  finally
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksJoinsParagraphLines;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('alpha bravo');
    Lines.Add('charlie');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkParagraph);
    Assert.AreEqual('alpha bravo charlie', Blocks[0].Text);
    Assert.AreEqual<Integer>(0, Blocks[0].SourceStartLine);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksGroupsFencedCode;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('```');
    Lines.Add('line1');
    Lines.Add('line2');
    Lines.Add('```');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkCodeBlock);
    Assert.AreEqual('line1' + sLineBreak + 'line2', Blocks[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksExtractsFenceLanguage;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('```pascal extra args');
    Lines.Add('var X: Integer;');
    Lines.Add('```');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkCodeBlock);
    Assert.AreEqual('pascal', Blocks[0].CodeLanguage);
    Assert.AreEqual('var X: Integer;', Blocks[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksLongFenceContainsBackticks;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  // The reported case: Antimony (like Python) writes multi-line notes between
  // triple backticks, so the code itself contains ```. A four-backtick fence
  // must carry it verbatim - only a fence at least as long closes the block.
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('````antimony');
    Lines.Add('model notes ```');
    Lines.Add('This model reproduces figure 3 of the paper.');
    Lines.Add('```');
    Lines.Add('````');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkCodeBlock);
    Assert.AreEqual('antimony', Blocks[0].CodeLanguage);
    Assert.AreEqual('model notes ```' + sLineBreak +
      'This model reproduces figure 3 of the paper.' + sLineBreak + '```',
      Blocks[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksTildeFenceContainsBackticks;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  // The other escape hatch: a tilde fence is closed only by tildes, so the
  // content may contain backtick fences of any length.
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('~~~antimony');
    Lines.Add('```');
    Lines.Add('````');
    Lines.Add('~~~');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkCodeBlock);
    Assert.AreEqual('antimony', Blocks[0].CodeLanguage);
    Assert.AreEqual('```' + sLineBreak + '````', Blocks[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksShortFenceDoesNotCloseLongOne;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  // A closing fence must have nothing but whitespace after it, and must be at
  // least as long as the opener. Neither line here qualifies.
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('````');
    Lines.Add('``` still inside');
    Lines.Add('````');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.AreEqual('``` still inside', Blocks[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksLongFenceKeepsSourceMap;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
  Map: TArray<Integer>;
begin
  // The map must span the WHOLE block. The mapper used to stop at any line
  // starting with a fence, so the inner ``` truncated it - and a map that does
  // not account for every character is DISCARDED, so the symptom is an empty
  // map (verbatim copy silently degrading to plain text), not a short one.
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('````ant');
    Lines.Add('a');
    Lines.Add('```');
    Lines.Add('b');
    Lines.Add('````');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.AreEqual('a' + sLineBreak + '```' + sLineBreak + 'b',
      Blocks[0].Text);
    Map := Blocks[0].SourceMap;
    // One entry per character, plus the one-past-the-end sentinel a selection
    // ending at the block's last character needs.
    Assert.AreEqual<Integer>(Length(Blocks[0].Text) + 1, Length(Map));
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksParsesIndentedCode;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('    procedure Indented;');
    Lines.Add('    begin');
    Lines.Add('    end;');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkCodeBlock);
    // Dedented by four columns, line breaks preserved, no language.
    Assert.AreEqual('procedure Indented;' + sLineBreak + 'begin' + sLineBreak +
      'end;', Blocks[0].Text);
    Assert.AreEqual('', Blocks[0].CodeLanguage);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksIndentedCodeKeepsInteriorBlank;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('    one');
    Lines.Add('');
    Lines.Add('    two');
    Lines.Add('');            // trailing blank - dropped
    Lines.Add('not code');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(2, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkCodeBlock);
    Assert.AreEqual('one' + sLineBreak + sLineBreak + 'two', Blocks[0].Text);
    Assert.IsTrue(Blocks[1].Kind = bkParagraph);
    Assert.AreEqual('not code', Blocks[1].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksIndentedCodeDoesNotInterruptParagraph;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('a paragraph');
    Lines.Add('    still the paragraph');   // lazy continuation, not code
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkParagraph);
    Assert.AreEqual('a paragraph still the paragraph', Blocks[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksIndentedCodeDeclinesAfterListItem;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    // Right after a list item a 4-space line is a list continuation, not a new
    // top-level code block - we decline rather than hijack it.
    Lines.Add('- an item');
    Lines.Add('    continued text');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.IsTrue(Blocks[0].Kind = bkListItem);
    Assert.IsTrue(Blocks[1].Kind <> bkCodeBlock);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksMergesQuoteLines;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('> alpha');
    Lines.Add('> bravo');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    // A quote is now a container: its content lives in Children, not Text. The
    // two lines join into one child paragraph.
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkQuote);
    Assert.IsNotNull(Blocks[0].Children);
    Assert.AreEqual<Integer>(1, Blocks[0].Children.Count);
    Assert.IsTrue(Blocks[0].Children[0].Kind = bkParagraph);
    Assert.AreEqual('alpha bravo', Blocks[0].Children[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksParenOrderedList;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('1) first');
    Lines.Add('2) second');
    Lines.Add('');
    Lines.Add('   a continuation paragraph of the second item');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(2, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkListItem);
    Assert.IsTrue(Blocks[0].Ordered);
    Assert.AreEqual<Integer>(1, Blocks[0].Number);
    Assert.AreEqual('first', Blocks[0].Text);
    Assert.IsTrue(Blocks[1].Ordered);
    Assert.AreEqual<Integer>(2, Blocks[1].Number);
    Assert.AreEqual('second', Blocks[1].Text);
    // The content column is measured to the first space, not to a '.', so item
    // children nest under a ')' marker exactly as under a '.' one.
    Assert.IsNotNull(Blocks[1].Children);
    Assert.AreEqual<Integer>(1, Blocks[1].Children.Count);
    Assert.AreEqual('a continuation paragraph of the second item',
      Blocks[1].Children[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksNestsSecondParagraphInItem;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
  Item: TMarkDownBlock;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('- first paragraph of the item');
    Lines.Add('');
    Lines.Add('  second paragraph of the same item');
    Lines.Add('');
    Lines.Add('- next item');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    // Two top-level items; the second paragraph is a child of the first, not a
    // top-level block escaping the list.
    Assert.AreEqual<Integer>(2, Blocks.Count);
    Item := Blocks[0];
    Assert.IsTrue(Item.Kind = bkListItem);
    Assert.AreEqual('first paragraph of the item', Item.Text);
    Assert.IsNotNull(Item.Children);
    Assert.AreEqual<Integer>(1, Item.Children.Count);
    Assert.IsTrue(Item.Children[0].Kind = bkParagraph);
    Assert.AreEqual('second paragraph of the same item', Item.Children[0].Text);
    Assert.IsTrue(Blocks[1].Kind = bkListItem);
    Assert.AreEqual('next item', Blocks[1].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksNestsCodeBlockInItem;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
  Item: TMarkDownBlock;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('- item with code:');
    Lines.Add('');
    Lines.Add('  ```pascal');
    Lines.Add('  WriteLn(''hi'');');
    Lines.Add('  ```');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Item := Blocks[0];
    Assert.IsTrue(Item.Kind = bkListItem);
    Assert.IsNotNull(Item.Children);
    Assert.AreEqual<Integer>(1, Item.Children.Count);
    Assert.IsTrue(Item.Children[0].Kind = bkCodeBlock);
    Assert.AreEqual('pascal', Item.Children[0].CodeLanguage);
    Assert.AreEqual('WriteLn(''hi'');', Item.Children[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksItemContinuationStopsAtNextItem;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    // A nested list item is NOT pulled in as continuation content - it stays a
    // flat IndentLevel item, so existing nested-list behaviour is preserved.
    Lines.Add('- outer');
    Lines.Add('  - inner');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(2, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkListItem);
    Assert.IsNull(Blocks[0].Children);
    Assert.IsTrue(Blocks[1].Kind = bkListItem);
    Assert.AreEqual('inner', Blocks[1].Text);
    Assert.AreEqual<Integer>(1, Blocks[1].IndentLevel);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksNestsQuote;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
  Outer: TMarkDownBlock;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('> outer');
    Lines.Add('>> inner');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Outer := Blocks[0];
    Assert.IsTrue(Outer.Kind = bkQuote);
    // Outer holds the 'outer' paragraph and a nested quote for the '>>' line.
    Assert.AreEqual<Integer>(2, Outer.Children.Count);
    Assert.IsTrue(Outer.Children[0].Kind = bkParagraph);
    Assert.AreEqual('outer', Outer.Children[0].Text);
    Assert.IsTrue(Outer.Children[1].Kind = bkQuote);
    Assert.AreEqual<Integer>(1, Outer.Children[1].Children.Count);
    Assert.AreEqual('inner', Outer.Children[1].Children[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksParsesListInsideQuote;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
  Quote: TMarkDownBlock;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('> - item one');
    Lines.Add('> - item two');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Quote := Blocks[0];
    Assert.IsTrue(Quote.Kind = bkQuote);
    // The markers survive the quote strip and parse as real list items.
    Assert.AreEqual<Integer>(2, Quote.Children.Count);
    Assert.IsTrue(Quote.Children[0].Kind = bkListItem);
    Assert.AreEqual('item one', Quote.Children[0].Text);
    Assert.IsTrue(Quote.Children[1].Kind = bkListItem);
    Assert.AreEqual('item two', Quote.Children[1].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksGroupsTableRows;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('| a | b |');
    Lines.Add('| --- | --- |');
    Lines.Add('| 1 | 2 |');
    Lines.Add('plain text');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(2, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkTable);
    Assert.IsTrue(Blocks[0].Text.Contains('| 1 | 2 |'), Blocks[0].Text);
    Assert.IsTrue(Blocks[1].Kind = bkParagraph);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksSkipsLinkReferenceDefinitions;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('[ref]: https://example.com');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(0, Blocks.Count);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksParsesFrontMatter;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('---');
    Lines.Add('name: delphi-fmx');
    Lines.Add('description: A specialist');
    Lines.Add('---');
    Lines.Add('');
    Lines.Add('# Body');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    // Front matter is one block holding the inner YAML; the body follows.
    Assert.AreEqual<Integer>(2, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkFrontMatter);
    Assert.AreEqual('name: delphi-fmx' + sLineBreak + 'description: A specialist',
      Blocks[0].Text);
    Assert.IsTrue(Blocks[1].Kind = bkHeading);
    Assert.AreEqual('Body', Blocks[1].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksLoneDashesAreRule;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    // A leading '---' with NO closing fence is a thematic rule, not front
    // matter - front matter must be a closed block.
    Lines.Add('---');
    Lines.Add('');
    Lines.Add('Just a paragraph.');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.IsFalse(Blocks[0].Kind = bkFrontMatter);
    Assert.IsTrue(Blocks[0].Kind = bkRule);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksParsesImageBlock;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('![alt text](img.png)');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkImage);
    Assert.AreEqual('alt text', Blocks[0].Text);
    Assert.AreEqual('img.png', Blocks[0].Url);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksStripsImageTitle;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    // An optional title must not end up in the path. Leaving it on put quotes
    // into the filename, which failed to resolve and raised from TPath.
    Lines.Add('![alt text](img.png "The title")');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkImage);
    Assert.AreEqual('alt text', Blocks[0].Text);
    Assert.AreEqual('img.png', Blocks[0].Url);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineStripsImageTitle;
var
  Tokens: TMarkDownInlineList;
  I: Integer;
  Found: Boolean;
begin
  // Same rule on the inline path, which is a separate branch from the block one.
  Tokens := TMarkDownBlockParser.ParseInline('see ![alt](img.png "Title") here');
  try
    Found := False;
    for I := 0 to Tokens.Count - 1 do
      if Tokens[I].IsImage then
      begin
        Found := True;
        Assert.AreEqual('img.png', Tokens[I].Url);
      end;
    Assert.IsTrue(Found, 'no image token was produced');
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksParsesTaskListItem;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('- [x] Done');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkListItem);
    Assert.IsTrue(Blocks[0].IsTask);
    Assert.IsTrue(Blocks[0].TaskChecked);
    Assert.AreEqual('Done', Blocks[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

// The GitHub spelling: open tag, content and close tag all on ONE line. This is
// the form READMEs actually use, and the easy one to miss when only the
// multi-line <div> case is tested.
procedure TMarkDownParserTests.ParseBlocksParsesAlignContainerOneLine;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('<p align="center"><img src="a.png"></p>');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkAlignBlock);
    Assert.AreEqual<TMarkDownAlign>(maCenter, Blocks[0].Align);
    Assert.IsNotNull(Blocks[0].Children);
    Assert.AreEqual<Integer>(1, Blocks[0].Children.Count);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksParsesAlignContainerMultiLine;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('<div align="right">');
    Lines.Add('');
    Lines.Add('# Heading');
    Lines.Add('');
    Lines.Add('Some text.');
    Lines.Add('');
    Lines.Add('</div>');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkAlignBlock);
    Assert.AreEqual<TMarkDownAlign>(maRight, Blocks[0].Align);
    // The container holds real blocks, parsed recursively.
    Assert.AreEqual<Integer>(2, Blocks[0].Children.Count);
    Assert.IsTrue(Blocks[0].Children[0].Kind = bkHeading);
    Assert.IsTrue(Blocks[0].Children[1].Kind = bkParagraph);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

// 🔴 Only a RECOGNISED align attribute makes a container. A bare <div>, or one
// with an align we do not understand, must keep the documented default of
// rendering literally - otherwise this quietly swallows block HTML.
procedure TMarkDownParserTests.ParseBlocksBareDivIsNotAContainer;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('<div>');
    Lines.Add('literal');
    Lines.Add('</div>');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkParagraph);
  finally
    Blocks.Free;
    Lines.Free;
  end;

  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('<div align="sideways">x</div>');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkParagraph);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

// An unterminated wrapper is declined and left literal, the same way an
// unclosed inline tag is.
procedure TMarkDownParserTests.ParseBlocksUnclosedAlignContainerStaysLiteral;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('<div align="center">');
    Lines.Add('never closed');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.IsTrue(Blocks.Count >= 1);
    Assert.IsFalse(Blocks[0].Kind = bkAlignBlock);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

// A same-name nested container must not be closed by the inner </div>.
procedure TMarkDownParserTests.ParseBlocksAlignContainerNests;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('<div align="center">');
    Lines.Add('');
    Lines.Add('<div align="right">');
    Lines.Add('');
    Lines.Add('inner');
    Lines.Add('');
    Lines.Add('</div>');
    Lines.Add('');
    Lines.Add('outer');
    Lines.Add('');
    Lines.Add('</div>');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.AreEqual<TMarkDownAlign>(maCenter, Blocks[0].Align);
    // Inner container plus the 'outer' paragraph - the inner </div> must not
    // have closed the outer one.
    Assert.AreEqual<Integer>(2, Blocks[0].Children.Count);
    Assert.IsTrue(Blocks[0].Children[0].Kind = bkAlignBlock);
    Assert.AreEqual<TMarkDownAlign>(maRight, Blocks[0].Children[0].Align);
    Assert.IsTrue(Blocks[0].Children[1].Kind = bkParagraph);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksHonorsStartLine;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('# alpha');
    Lines.Add('');
    Lines.Add('# bravo');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines, 2);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkHeading);
    Assert.AreEqual('bravo', Blocks[0].Text);
    Assert.AreEqual<Integer>(2, Blocks[0].SourceStartLine);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksTreatsHashWithoutSpaceAsParagraph;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('#tag');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkParagraph);
    Assert.AreEqual('#tag', Blocks[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksRequiresSeparatorForTable;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('| a | b |');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkParagraph);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksAddsHardBreakForTrailingSpaces;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('first line  ');
    Lines.Add('second line');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkParagraph);
    Assert.AreEqual('first line'#10'second line', Blocks[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksAddsHardBreakForTrailingBackslash;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('first line\');
    Lines.Add('second line');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.AreEqual('first line'#10'second line', Blocks[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineParsesBoldItalic;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('***both***');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.IsTrue(Tokens[0].Style = [fsBold, fsItalic]);
    Assert.AreEqual('both', Tokens[0].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineIgnoresUnderscoreInsideWords;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('snake_case_name');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.IsTrue(Tokens[0].Style = []);
    Assert.AreEqual('snake_case_name', Tokens[0].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineIgnoresSpacedAsterisks;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('a * b * c');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.IsTrue(Tokens[0].Style = []);
    Assert.AreEqual('a * b * c', Tokens[0].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineParsesEmphasisCodeAndStrike;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('a **b** *c* `d` ~~e~~');
  try
    Assert.AreEqual<Integer>(8, Tokens.Count);
    Assert.IsTrue(Tokens[0].Style = []);
    Assert.AreEqual('a ', Tokens[0].Text);
    Assert.IsTrue(Tokens[1].Style = [fsBold]);
    Assert.AreEqual('b', Tokens[1].Text);
    Assert.IsTrue(Tokens[3].Style = [fsItalic]);
    Assert.AreEqual('c', Tokens[3].Text);
    Assert.IsTrue(Tokens[5].IsCode);
    Assert.AreEqual('d', Tokens[5].Text);
    Assert.IsTrue(Tokens[7].Style = [fsStrikeOut]);
    Assert.AreEqual('e', Tokens[7].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineNestsEmphasis;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('**bold _and italic_**');
  try
    Assert.AreEqual<Integer>(2, Tokens.Count);
    Assert.IsTrue(Tokens[0].Style = [fsBold]);
    Assert.AreEqual('bold ', Tokens[0].Text);
    Assert.IsTrue(Tokens[1].Style = [fsBold, fsItalic]);
    Assert.AreEqual('and italic', Tokens[1].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineStylesLinkText;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('[**bold** link](https://example.com)');
  try
    Assert.AreEqual<Integer>(2, Tokens.Count);
    Assert.IsTrue(Tokens[0].Style = [fsBold]);
    Assert.AreEqual('bold', Tokens[0].Text);
    Assert.AreEqual('https://example.com', Tokens[0].Url);
    Assert.IsTrue(Tokens[1].Style = []);
    Assert.AreEqual(' link', Tokens[1].Text);
    Assert.AreEqual('https://example.com', Tokens[1].Url);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineRespectsEscapes;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('\*not bold\*');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.IsTrue(Tokens[0].Style = []);
    Assert.AreEqual('*not bold*', Tokens[0].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineMapsHtmlFormattingTags;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline(
    'a <b>bold</b> and <i>it</i> and <mark>hi</mark> and <sub>x</sub>');
  try
    // 'a ', 'bold'(bold), ' and ', 'it'(italic), ' and ', 'hi'(highlight),
    // ' and ', 'x'(subscript)
    Assert.AreEqual<Integer>(8, Tokens.Count);
    Assert.AreEqual('bold', Tokens[1].Text);
    Assert.IsTrue(Tokens[1].Style = [fsBold]);
    Assert.AreEqual('it', Tokens[3].Text);
    Assert.IsTrue(Tokens[3].Style = [fsItalic]);
    Assert.AreEqual('hi', Tokens[5].Text);
    Assert.IsTrue(Tokens[5].IsHighlighted);
    Assert.AreEqual('x', Tokens[7].Text);
    Assert.IsTrue(Tokens[7].IsSubscript);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineNestsHtmlTags;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('<b>bold <i>and italic</i></b>');
  try
    // 'bold ' (bold), 'and italic' (bold+italic)
    Assert.AreEqual<Integer>(2, Tokens.Count);
    Assert.AreEqual('bold ', Tokens[0].Text);
    Assert.IsTrue(Tokens[0].Style = [fsBold]);
    Assert.AreEqual('and italic', Tokens[1].Text);
    Assert.IsTrue(Tokens[1].Style = [fsBold, fsItalic]);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineHtmlBreakTag;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('one<br />two');
  try
    Assert.AreEqual<Integer>(3, Tokens.Count);
    Assert.AreEqual('one', Tokens[0].Text);
    Assert.IsTrue(Tokens[1].LineBreak);
    Assert.AreEqual('two', Tokens[2].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineLeavesUnknownTagLiteral;
var
  Tokens: TMarkDownInlineList;
begin
  // A tag not on the whitelist is passed through literally, not interpreted.
  Tokens := TMarkDownBlockParser.ParseInline('a <span>x</span> b');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.AreEqual('a <span>x</span> b', Tokens[0].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineLeavesUnclosedTagLiteral;
var
  Tokens: TMarkDownInlineList;
begin
  // A whitelisted opener with no matching close stays literal.
  Tokens := TMarkDownBlockParser.ParseInline('a <b>x without close');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.AreEqual('a <b>x without close', Tokens[0].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineParsesHtmlImageWithSize;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline(
    '<img src="/Images/iridium1.png" width="80%" alt="Ir"></img>');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.IsTrue(Tokens[0].IsImage);
    Assert.AreEqual('/Images/iridium1.png', Tokens[0].Url);
    Assert.AreEqual('Ir', Tokens[0].Text);
    Assert.IsTrue(Tokens[0].ImgWidthPct);
    Assert.AreEqual(Single(0.8), Tokens[0].ImgWidth, Single(0.001));
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineParsesHtmlImageAlign;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline(
    '<img src="a.png" align="center">');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.IsTrue(Tokens[0].IsImage);
    Assert.AreEqual<TMarkDownAlign>(maCenter, Tokens[0].ImgAlign);
  finally
    Tokens.Free;
  end;

  Tokens := TMarkDownBlockParser.ParseInline('<img src="a.png" align="RIGHT">');
  try
    Assert.AreEqual<TMarkDownAlign>(maRight, Tokens[0].ImgAlign);
  finally
    Tokens.Free;
  end;
end;

// No attribute, or one that is not a placement, must stay maDefault - that is
// the sentinel the viewer's ImageAlign property fills in.
procedure TMarkDownParserTests.ParseInlineImageAlignDefaultsToUnset;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('<img src="a.png">');
  try
    Assert.AreEqual<TMarkDownAlign>(maDefault, Tokens[0].ImgAlign);
  finally
    Tokens.Free;
  end;

  Tokens := TMarkDownBlockParser.ParseInline('<img src="a.png" align="wat">');
  try
    Assert.AreEqual<TMarkDownAlign>(maDefault, Tokens[0].ImgAlign);
  finally
    Tokens.Free;
  end;

  // A markdown image carries no attributes at all.
  Tokens := TMarkDownBlockParser.ParseInline('![alt](a.png)');
  try
    Assert.IsTrue(Tokens[0].IsImage);
    Assert.AreEqual<TMarkDownAlign>(maDefault, Tokens[0].ImgAlign);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineParsesInlineLink;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('[title](https://example.com)');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.AreEqual('title', Tokens[0].Text);
    Assert.AreEqual('https://example.com', Tokens[0].Url);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineStripsLinkTitle;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('[title](https://example.com "tip")');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.AreEqual('title', Tokens[0].Text);
    Assert.AreEqual('https://example.com', Tokens[0].Url);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineResolvesReferenceLink;
var
  References: TStringList;
  Tokens: TMarkDownInlineList;
begin
  References := TStringList.Create;
  Tokens := nil;
  try
    References.Values['ref'] := 'https://example.com';
    Tokens := TMarkDownBlockParser.ParseInline('[title][ref]', References);
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.AreEqual('title', Tokens[0].Text);
    Assert.AreEqual('https://example.com', Tokens[0].Url);
  finally
    Tokens.Free;
    References.Free;
  end;
end;

// Shortcut form: `[foo]` with a matching definition, no second bracket pair.
procedure TMarkDownParserTests.ParseInlineResolvesShortcutReferenceLink;
var
  References: TStringList;
  Tokens: TMarkDownInlineList;
begin
  References := TStringList.Create;
  Tokens := nil;
  try
    References.Values['ref'] := 'https://example.com';
    Tokens := TMarkDownBlockParser.ParseInline('[ref]', References);
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.AreEqual('ref', Tokens[0].Text);
    Assert.AreEqual('https://example.com', Tokens[0].Url);

    // The collapsed form must still take precedence over the shortcut one.
    Tokens.Free;
    Tokens := TMarkDownBlockParser.ParseInline('[ref][]', References);
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.AreEqual('ref', Tokens[0].Text);
    Assert.AreEqual('https://example.com', Tokens[0].Url);
  finally
    Tokens.Free;
    References.Free;
  end;
end;

// With no matching definition, bracketed text stays literal - the guard that
// keeps ordinary prose like "[TODO] fix this" from becoming a link.
procedure TMarkDownParserTests.ParseInlineLeavesUnmatchedShortcutLiteral;
var
  References: TStringList;
  Tokens: TMarkDownInlineList;
  I: Integer;
  All: string;
begin
  References := TStringList.Create;
  Tokens := nil;
  try
    References.Values['ref'] := 'https://example.com';
    Tokens := TMarkDownBlockParser.ParseInline('[TODO] fix this', References);
    All := '';
    for I := 0 to Tokens.Count - 1 do
    begin
      All := All + Tokens[I].Text;
      Assert.AreEqual('', Tokens[I].Url);
    end;
    Assert.AreEqual('[TODO] fix this', All);
  finally
    Tokens.Free;
    References.Free;
  end;
end;

// $..$ becomes one math token carrying the LaTeX verbatim - the viewer needs
// that source both to typeset it and to fall back to when the engine is absent.
procedure TMarkDownParserTests.ParseInlineParsesInlineMath;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('the root of $x^2+1=0$ here');
  try
    Assert.AreEqual<Integer>(3, Tokens.Count);
    Assert.IsTrue(Tokens[1].IsMath);
    Assert.IsFalse(Tokens[1].MathDisplay);
    Assert.AreEqual('x^2+1=0', Tokens[1].Text);
    Assert.IsFalse(Tokens[0].IsMath);
  finally
    Tokens.Free;
  end;
end;

// $$..$$ inside a paragraph is the same token in display style.
procedure TMarkDownParserTests.ParseInlineParsesDisplayMathSpan;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('see $$\int_0^1 x\,dx$$ above');
  try
    Assert.AreEqual<Integer>(3, Tokens.Count);
    Assert.IsTrue(Tokens[1].IsMath);
    Assert.IsTrue(Tokens[1].MathDisplay);
    Assert.AreEqual('\int_0^1 x\,dx', Tokens[1].Text);
  finally
    Tokens.Free;
  end;
end;

// Prose is full of currency and none of it is math. Three separate guards are
// at work here: whitespace just inside a delimiter ("$5 and $10"), an opening
// '$' that follows a letter, and a closing '$' that precedes a digit
// ("US$100 and CA$200").
procedure TMarkDownParserTests.ParseInlineLeavesCurrencyAlone;
var
  Tokens: TMarkDownInlineList;
  I: Integer;
  All: string;
begin
  Tokens := TMarkDownBlockParser.ParseInline(
    'it costs $5 and $10, or US$100 and CA$200 today');
  try
    All := '';
    for I := 0 to Tokens.Count - 1 do
    begin
      Assert.IsFalse(Tokens[I].IsMath);
      All := All + Tokens[I].Text;
    end;
    Assert.AreEqual('it costs $5 and $10, or US$100 and CA$200 today', All);
  finally
    Tokens.Free;
  end;
end;

// An escaped \$ is a literal dollar and must never open math.
procedure TMarkDownParserTests.ParseInlineLeavesEscapedDollarLiteral;
var
  Tokens: TMarkDownInlineList;
  I: Integer;
  All: string;
begin
  Tokens := TMarkDownBlockParser.ParseInline('an escaped \$x\$ stays literal');
  try
    All := '';
    for I := 0 to Tokens.Count - 1 do
    begin
      Assert.IsFalse(Tokens[I].IsMath);
      All := All + Tokens[I].Text;
    end;
    Assert.AreEqual('an escaped $x$ stays literal', All);
  finally
    Tokens.Free;
  end;
end;

// A '$' must not pair with one INSIDE a code span. Without this guard the stray
// '$' in "CA$200" reached the '$' in `$x^2$` and swallowed every word between
// them - and because the result was a math token, that prose disappeared into a
// formula rather than merely losing its styling.
procedure TMarkDownParserTests.ParseInlineMathDoesNotCrossCodeSpan;
var
  Tokens: TMarkDownInlineList;
  I: Integer;
begin
  Tokens := TMarkDownBlockParser.ParseInline('CA$200 and `$x^2$` in code');
  try
    for I := 0 to Tokens.Count - 1 do
    begin
      Assert.IsFalse(Tokens[I].IsMath);
      // The code span still parses as code, unaffected.
      if Tokens[I].IsCode then
        Assert.AreEqual('$x^2$', Tokens[I].Text);
    end;
  finally
    Tokens.Free;
  end;
end;

// A math token keeps a full per-character source map, unlike an image. That is
// what lets a selection copy back as exact markdown whichever way the formula
// was rendered.
procedure TMarkDownParserTests.ParseInlineMathKeepsSourceMap;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
  Tokens: TMarkDownInlineList;
  I: Integer;
  Seen: Boolean;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  Seen := False;
  try
    Lines.Add('ab $x+y$ cd');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Tokens := TMarkDownBlockParser.ParseInline(Blocks[0].Text, nil,
      Blocks[0].SourceMap);
    try
      for I := 0 to Tokens.Count - 1 do
        if Tokens[I].IsMath then
        begin
          Seen := True;
          Assert.AreEqual<Integer>(Length(Tokens[I].Text) + 1,
            Length(Tokens[I].SourceMap));
          // 'x' is at offset 4: "ab $" is four characters.
          Assert.AreEqual<Integer>(4, Tokens[I].SourceMap[0]);
        end;
      Assert.IsTrue(Seen);
    finally
      Tokens.Free;
    end;
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

// GitHub spells display math as a ```math fence, so that becomes bkMath rather
// than a code block - while keeping the language, which is what an application
// without the math engine falls back to showing.
procedure TMarkDownParserTests.ParseBlocksParsesMathFence;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('```math');
    Lines.Add('E = mc^2');
    Lines.Add('```');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkMath);
    Assert.AreEqual('E = mc^2', Blocks[0].Text);
    // A fenced block keeps its source map, so math copies back verbatim.
    Assert.AreEqual<Integer>(Length(Blocks[0].Text) + 1,
      Length(Blocks[0].SourceMap));
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksParsesDollarMathBlock;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('$$');
    Lines.Add('\frac{a}{b}');
    Lines.Add('$$');
    Lines.Add('');
    Lines.Add('After.');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(2, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkMath);
    Assert.AreEqual('\frac{a}{b}', Blocks[0].Text);
    Assert.IsTrue(Blocks[1].Kind = bkParagraph);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksParsesOneLineMathBlock;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('$$ x = 1 $$');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(1, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkMath);
    Assert.AreEqual('x = 1', Blocks[0].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

// Only a CLOSED block is math - the same rule the align container and the
// front-matter card follow, so an unterminated delimiter degrades to text
// rather than swallowing the rest of the document.
procedure TMarkDownParserTests.ParseBlocksLeavesUnclosedMathBlockAsText;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('$$');
    Lines.Add('x = 1');
    Lines.Add('');
    Lines.Add('More prose.');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    for I := 0 to Blocks.Count - 1 do
      Assert.IsFalse(Blocks[I].Kind = bkMath);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineDetectsAutoLink;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('visit https://example.com today.');
  try
    Assert.AreEqual<Integer>(3, Tokens.Count);
    Assert.AreEqual('https://example.com', Tokens[1].Url);
    Assert.IsFalse(Tokens[2].LineBreak);
    Assert.AreEqual(' today.', Tokens[2].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineEmitsHardLineBreakToken;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('foo'#10'bar');
  try
    Assert.AreEqual<Integer>(3, Tokens.Count);
    Assert.AreEqual('foo', Tokens[0].Text);
    Assert.IsTrue(Tokens[1].LineBreak);
    Assert.AreEqual('bar', Tokens[2].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ExtractLinkReferencesCollectsUrls;
var
  Lines: TStringList;
  References: TStringList;
begin
  Lines := TStringList.Create;
  References := TStringList.Create;
  try
    Lines.Add('[one]: https://one.example');
    Lines.Add('[two]: https://two.example trailing title');
    TMarkDownBlockParser.ExtractLinkReferences(Lines, References);
    Assert.AreEqual('https://one.example', References.Values['one']);
    Assert.AreEqual('https://two.example', References.Values['two']);
  finally
    References.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineDetectsEmailAutoLink;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('Mail <a@b.com> now');
  try
    Assert.AreEqual<Integer>(3, Tokens.Count);
    Assert.AreEqual('Mail ', Tokens[0].Text);
    Assert.AreEqual('a@b.com', Tokens[1].Text);
    Assert.AreEqual('mailto:a@b.com', Tokens[1].Url);
    Assert.AreEqual(' now', Tokens[2].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineDecodesHtmlEntities;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('A &amp; B &copy; C &#169; D &#x2122;');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.AreEqual('A & B ' + #$00A9 + ' C ' + #$00A9 + ' D ' + #$2122,
      Tokens[0].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineLeavesInvalidEntityLiteral;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('AT&T and R&D');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.AreEqual('AT&T and R&D', Tokens[0].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.IsSetextUnderlineRecognizesUnderlines;
var
  Level: Integer;
begin
  Assert.IsTrue(TMarkDownBlockParser.IsSetextUnderline('===', Level));
  Assert.AreEqual<Integer>(1, Level);
  Assert.IsTrue(TMarkDownBlockParser.IsSetextUnderline('-----', Level));
  Assert.AreEqual<Integer>(2, Level);
  Assert.IsFalse(TMarkDownBlockParser.IsSetextUnderline('-x-', Level));
  Assert.IsFalse(TMarkDownBlockParser.IsSetextUnderline('', Level));
end;

procedure TMarkDownParserTests.ParseBlocksParsesSetextHeadings;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('Title One');
    Lines.Add('===');
    Lines.Add('');
    Lines.Add('Title Two');
    Lines.Add('---');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(2, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkHeading);
    Assert.AreEqual<Integer>(1, Blocks[0].Level);
    Assert.AreEqual('Title One', Blocks[0].Text);
    Assert.IsTrue(Blocks[1].Kind = bkHeading);
    Assert.AreEqual<Integer>(2, Blocks[1].Level);
    Assert.AreEqual('Title Two', Blocks[1].Text);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseBlocksKeepsRuleWithoutParagraph;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('text');
    Lines.Add('');
    Lines.Add('---');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual<Integer>(2, Blocks.Count);
    Assert.IsTrue(Blocks[0].Kind = bkParagraph);
    Assert.IsTrue(Blocks[1].Kind = bkRule);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineLeavesUnterminatedEmphasisAsText;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('**unterminated');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.IsTrue(Tokens[0].Style = []);
    Assert.AreEqual('**unterminated', Tokens[0].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineLeavesUnterminatedCodeAsText;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('`code');
  try
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.IsFalse(Tokens[0].IsCode);
    Assert.AreEqual('`code', Tokens[0].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.CountLeadingSpacesCountsSpacesAndTabs;
begin
  Assert.AreEqual<Integer>(3, TMarkDownBlockParser.CountLeadingSpaces('   x'));
  Assert.AreEqual<Integer>(4, TMarkDownBlockParser.CountLeadingSpaces(#9'x'));
  Assert.AreEqual<Integer>(6, TMarkDownBlockParser.CountLeadingSpaces('  '#9'x'));
  Assert.AreEqual<Integer>(0, TMarkDownBlockParser.CountLeadingSpaces('x'));
end;

procedure TMarkDownParserTests.TrimLeftOnlyRemovesLeadingWhitespaceOnly;
begin
  Assert.AreEqual('abc  ', TMarkDownBlockParser.TrimLeftOnly('   abc  '));
  Assert.AreEqual('x', TMarkDownBlockParser.TrimLeftOnly(#9#9'x'));
  Assert.AreEqual('abc', TMarkDownBlockParser.TrimLeftOnly('abc'));
end;

procedure TMarkDownParserTests.StartsWithFenceRecognizesIndentedFence;
begin
  Assert.IsTrue(TMarkDownBlockParser.StartsWithFence('```'));
  Assert.IsTrue(TMarkDownBlockParser.StartsWithFence('```pascal'));
  Assert.IsTrue(TMarkDownBlockParser.StartsWithFence('   ```'));
  Assert.IsFalse(TMarkDownBlockParser.StartsWithFence('``'));
  Assert.IsFalse(TMarkDownBlockParser.StartsWithFence('text'));
  // Longer runs and tilde fences open a block too.
  Assert.IsTrue(TMarkDownBlockParser.StartsWithFence('````antimony'));
  Assert.IsTrue(TMarkDownBlockParser.StartsWithFence('~~~'));
  Assert.IsFalse(TMarkDownBlockParser.StartsWithFence('~~strike~~'));
  // A backtick fence's info string may not contain a backtick, or a line that
  // is really inline code would open a block.
  Assert.IsFalse(TMarkDownBlockParser.StartsWithFence('``` `a` ```'));
end;

procedure TMarkDownParserTests.IsClosingFenceRequiresSameCharAndLength;
begin
  // Same character, at least as long, nothing but whitespace after it.
  Assert.IsTrue(TMarkDownBlockParser.IsClosingFence('```', '`', 3));
  Assert.IsTrue(TMarkDownBlockParser.IsClosingFence('````', '`', 3));
  Assert.IsTrue(TMarkDownBlockParser.IsClosingFence('```  ', '`', 3));
  Assert.IsFalse(TMarkDownBlockParser.IsClosingFence('```', '`', 4));
  Assert.IsFalse(TMarkDownBlockParser.IsClosingFence('```pascal', '`', 3));
  Assert.IsFalse(TMarkDownBlockParser.IsClosingFence('~~~', '`', 3));
  Assert.IsTrue(TMarkDownBlockParser.IsClosingFence('~~~', '~', 3));
end;

procedure TMarkDownParserTests.IsRuleLineAcceptsRulesAndRejectsOthers;
begin
  Assert.IsTrue(TMarkDownBlockParser.IsRuleLine('---'));
  Assert.IsTrue(TMarkDownBlockParser.IsRuleLine('***'));
  Assert.IsTrue(TMarkDownBlockParser.IsRuleLine('___'));
  Assert.IsTrue(TMarkDownBlockParser.IsRuleLine('- - -'));
  Assert.IsFalse(TMarkDownBlockParser.IsRuleLine('--'));
  Assert.IsFalse(TMarkDownBlockParser.IsRuleLine('-*-'));
  Assert.IsFalse(TMarkDownBlockParser.IsRuleLine('abc'));
end;

procedure TMarkDownParserTests.IsPipeTableRowDetectsPipe;
begin
  Assert.IsTrue(TMarkDownBlockParser.IsPipeTableRow('| a | b |'));
  Assert.IsTrue(TMarkDownBlockParser.IsPipeTableRow('a | b'));
  Assert.IsFalse(TMarkDownBlockParser.IsPipeTableRow('plain'));
  Assert.IsFalse(TMarkDownBlockParser.IsPipeTableRow(''));
end;

// An escaped pipe is content, not a column separator - without this a cell
// containing '|' silently shifts every later column in the row. The escape is
// also resolved here rather than in ParseRuns, which would leave the backslash
// visible inside a code span.
procedure TMarkDownParserTests.SplitTableRowKeepsEscapedPipe;
var
  Cells: TStringList;
begin
  Cells := TStringList.Create;
  try
    TMarkDownBlockParser.SplitTableRow('| a \| b | c |' , Cells);
    Assert.AreEqual<Integer>(2, Cells.Count);
    Assert.AreEqual('a | b', Cells[0]);
    Assert.AreEqual('c', Cells[1]);

    // A trailing escaped pipe is the last cell's content, not the row's
    // closing delimiter.
    TMarkDownBlockParser.SplitTableRow('| a | b \|', Cells);
    Assert.AreEqual<Integer>(2, Cells.Count);
    Assert.AreEqual('a', Cells[0]);
    Assert.AreEqual('b |', Cells[1]);
  finally
    Cells.Free;
  end;
end;

procedure TMarkDownParserTests.SplitTableRowSplitsCells;
var
  Cells: TStringList;
begin
  Cells := TStringList.Create;
  try
    TMarkDownBlockParser.SplitTableRow('| a | b |', Cells);
    Assert.AreEqual<Integer>(2, Cells.Count);
    Assert.AreEqual('a', Cells[0]);
    Assert.AreEqual('b', Cells[1]);

    TMarkDownBlockParser.SplitTableRow('one | two', Cells);
    Assert.AreEqual<Integer>(2, Cells.Count);
    Assert.AreEqual('one', Cells[0]);
    Assert.AreEqual('two', Cells[1]);
  finally
    Cells.Free;
  end;
end;

procedure TMarkDownParserTests.TryParseImageParsesAltAndUrl;
var
  AltText: string;
  Url: string;
begin
  Assert.IsTrue(TMarkDownBlockParser.TryParseImage('![alt](pic.png)', AltText, Url));
  Assert.AreEqual('alt', AltText);
  Assert.AreEqual('pic.png', Url);
end;

procedure TMarkDownParserTests.TryParseImageRejectsNonImage;
var
  AltText: string;
  Url: string;
begin
  Assert.IsFalse(TMarkDownBlockParser.TryParseImage('![alt]', AltText, Url));
  Assert.IsFalse(TMarkDownBlockParser.TryParseImage('plain text', AltText, Url));
end;

procedure TMarkDownParserTests.TryParseLinkReferenceParsesNameAndUrl;
var
  Name: string;
  Url: string;
begin
  Assert.IsTrue(TMarkDownBlockParser.TryParseLinkReference(
    '[ref]: https://example.com', Name, Url));
  Assert.AreEqual('ref', Name);
  Assert.AreEqual('https://example.com', Url);
  Assert.IsFalse(TMarkDownBlockParser.TryParseLinkReference('not a ref', Name, Url));
end;

procedure TMarkDownParserTests.TryParseLinkReferenceDropsTitle;
var
  Name: string;
  Url: string;
begin
  Assert.IsTrue(TMarkDownBlockParser.TryParseLinkReference(
    '[ref]: https://example.com "Title"', Name, Url));
  Assert.AreEqual('https://example.com', Url);
end;

procedure TMarkDownParserTests.TryParseListItemHandlesBulletsAndNumbers;
var
  Text: string;
  Ordered: Boolean;
  Number: Integer;
  IndentLevel: Integer;
begin
  Assert.IsTrue(TMarkDownBlockParser.TryParseListItem('* bullet', Text,
    Ordered, Number, IndentLevel));
  Assert.IsFalse(Ordered);
  Assert.AreEqual('bullet', Text);

  Assert.IsTrue(TMarkDownBlockParser.TryParseListItem('+ plus', Text,
    Ordered, Number, IndentLevel));
  Assert.IsFalse(Ordered);
  Assert.AreEqual('plus', Text);

  Assert.IsTrue(TMarkDownBlockParser.TryParseListItem('3. third', Text,
    Ordered, Number, IndentLevel));
  Assert.IsTrue(Ordered);
  Assert.AreEqual<Integer>(3, Number);
  Assert.AreEqual('third', Text);
end;

procedure TMarkDownParserTests.TryParseListItemRejectsPlainText;
var
  Text: string;
  Ordered: Boolean;
  Number: Integer;
  IndentLevel: Integer;
begin
  Assert.IsFalse(TMarkDownBlockParser.TryParseListItem('plain text', Text,
    Ordered, Number, IndentLevel));
end;

// Verifies the invariant that every character of Block.Text maps to a document
// offset holding the same character - except the synthetic spaces/newlines that
// join wrapped source lines, which map to the CR of the line break they stand
// for. Also checks the map has the expected length and trailing sentinel.
procedure AssertSourceMapValid(Lines: TStringList; Block: TMarkDownBlock);
var
  Doc: string;
  I: Integer;
  Off: Integer;
  SrcCh: Char;
  BlkCh: Char;
begin
  Doc := Lines.Text;
  Assert.AreEqual<Integer>(Length(Block.Text) + 1, Length(Block.SourceMap),
    'map length for "' + Block.Text + '"');
  for I := 0 to Length(Block.Text) - 1 do
  begin
    Off := Block.SourceMap[I];
    Assert.IsTrue((Off >= 0) and (Off < Length(Doc)),
      Format('offset %d out of range at index %d', [Off, I]));
    SrcCh := Doc[Off + 1];
    BlkCh := Block.Text[I + 1];
    if CharInSet(BlkCh, [' ', #10]) then
      Assert.IsTrue((SrcCh = BlkCh) or (SrcCh = #13),
        Format('join at index %d maps to offset %d (ord %d)',
          [I, Off, Ord(SrcCh)]))
    else
      Assert.AreEqual(BlkCh, SrcCh,
        Format('index %d "%s" maps to offset %d "%s"', [I, BlkCh, Off, SrcCh]));
  end;
end;

procedure TMarkDownParserTests.SourceMapMapsParagraphToSource;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('Hello world');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    AssertSourceMapValid(Lines, Blocks[0]);
    Assert.AreEqual<Integer>(0, Blocks[0].SourceMap[0]);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.SourceMapHandlesMultiLineParagraphJoin;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('alpha bravo');
    Lines.Add('charlie');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual('alpha bravo charlie', Blocks[0].Text);
    AssertSourceMapValid(Lines, Blocks[0]);
    // 'charlie' begins at the start of the second source line.
    Assert.AreEqual<Integer>(Length('alpha bravo') + 2,
      Blocks[0].SourceMap[Length('alpha bravo ')]);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

// The list-item source map locates Text by searching the line, so it is
// marker-agnostic - this guards verbatim markdown copy over a ')' list.
procedure TMarkDownParserTests.ParseBlocksParenOrderedListKeepsSourceMap;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('7) an item with **bold** in it');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.IsTrue(Blocks[0].Kind = bkListItem);
    Assert.AreEqual('an item with **bold** in it', Blocks[0].Text);
    AssertSourceMapValid(Lines, Blocks[0]);
    // Text starts after '7) '.
    Assert.AreEqual<Integer>(3, Blocks[0].SourceMap[0]);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.SourceMapHandlesHardBreakParagraph;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('alpha  ');
    Lines.Add('bravo');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual('alpha'#10'bravo', Blocks[0].Text);
    AssertSourceMapValid(Lines, Blocks[0]);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.SourceMapHandlesAtxHeadingOffset;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('## Heading');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual('Heading', Blocks[0].Text);
    AssertSourceMapValid(Lines, Blocks[0]);
    Assert.AreEqual<Integer>(3, Blocks[0].SourceMap[0]);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.SourceMapHandlesMarkupAndEntities;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
  I: Integer;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    // A single-line paragraph is identical to its source, so each character
    // must map to its own offset - including markup and entity characters.
    Lines.Add('Text **bold** and &copy; end');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    AssertSourceMapValid(Lines, Blocks[0]);
    for I := 0 to Length(Blocks[0].Text) - 1 do
      Assert.AreEqual(I, Blocks[0].SourceMap[I]);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.SourceMapHandlesQuoteAcrossLines;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('> alpha');
    Lines.Add('> bravo');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    // A quote is now a container. Its child paragraph carries the text but no
    // source map (Phase A of the container work): the child's lines are
    // stripped copies, so precise offsets are deferred and the viewer falls
    // back to its nearest-neighbour copy heuristic. See
    // Docs/container-blocks-plan.md (Phase C would restore precise maps).
    Assert.IsTrue(Blocks[0].Kind = bkQuote);
    Assert.AreEqual('alpha bravo', Blocks[0].Children[0].Text);
    Assert.AreEqual<Integer>(0, Length(Blocks[0].Children[0].SourceMap));
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.SourceMapHandlesIndentedHeading;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('   ### Deep');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.AreEqual('Deep', Blocks[0].Text);
    AssertSourceMapValid(Lines, Blocks[0]);
    Assert.AreEqual<Integer>(7, Blocks[0].SourceMap[0]);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.TokenMapLocatesBoldSpan;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
  Tokens: TMarkDownInlineList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  Tokens := nil;
  try
    Lines.Add('a **b** c');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Tokens := TMarkDownBlockParser.ParseInline(Blocks[0].Text, nil,
      Blocks[0].SourceMap);
    Assert.AreEqual<Integer>(3, Tokens.Count);
    // The bold 'b' sits at offset 4 in "a **b** c".
    Assert.AreEqual('b', Tokens[1].Text);
    Assert.IsTrue(fsBold in Tokens[1].Style);
    Assert.AreEqual<Integer>(2, Length(Tokens[1].SourceMap));
    Assert.AreEqual<Integer>(4, Tokens[1].SourceMap[0]);
    // The trailing " c": the 'c' is at offset 8.
    Assert.AreEqual(' c', Tokens[2].Text);
    Assert.AreEqual<Integer>(7, Tokens[2].SourceMap[0]);
    Assert.AreEqual<Integer>(8, Tokens[2].SourceMap[1]);
  finally
    Tokens.Free;
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.TokenMapHandlesEntity;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
  Tokens: TMarkDownInlineList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  Tokens := nil;
  try
    Lines.Add('&copy; x');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Tokens := TMarkDownBlockParser.ParseInline(Blocks[0].Text, nil,
      Blocks[0].SourceMap);
    Assert.AreEqual<Integer>(1, Tokens.Count);
    Assert.AreEqual(#$00A9 + ' x', Tokens[0].Text);
    // The decoded entity spans &copy; (offsets 0..5); the rendered glyph maps to
    // the '&' at 0, then the space at 6 and 'x' at 7 follow, end at 8.
    Assert.AreEqual<Integer>(4, Length(Tokens[0].SourceMap));
    Assert.AreEqual<Integer>(0, Tokens[0].SourceMap[0]);
    Assert.AreEqual<Integer>(6, Tokens[0].SourceMap[1]);
    Assert.AreEqual<Integer>(7, Tokens[0].SourceMap[2]);
    Assert.AreEqual<Integer>(8, Tokens[0].SourceMap[3]);
  finally
    Tokens.Free;
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.TokenMapHandlesAutoLink;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
  Tokens: TMarkDownInlineList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  Tokens := nil;
  try
    Lines.Add('see <https://x.io> ok');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Tokens := TMarkDownBlockParser.ParseInline(Blocks[0].Text, nil,
      Blocks[0].SourceMap);
    Assert.AreEqual<Integer>(3, Tokens.Count);
    Assert.AreEqual('https://x.io', Tokens[1].Text);
    Assert.AreEqual('https://x.io', Tokens[1].Url);
    // The display text begins just after '<', at offset 5.
    Assert.AreEqual<Integer>(Length('https://x.io') + 1, Length(Tokens[1].SourceMap));
    Assert.AreEqual<Integer>(5, Tokens[1].SourceMap[0]);
  finally
    Tokens.Free;
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.SourceMapHandlesListItem;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('- buy **milk**');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.IsTrue(Blocks[0].Kind = bkListItem);
    Assert.AreEqual('buy **milk**', Blocks[0].Text);
    AssertSourceMapValid(Lines, Blocks[0]);
    Assert.AreEqual<Integer>(2, Blocks[0].SourceMap[0]);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.SourceMapHandlesImageAlt;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('![a cat](cat.png)');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.IsTrue(Blocks[0].Kind = bkImage);
    Assert.AreEqual('a cat', Blocks[0].Text);
    AssertSourceMapValid(Lines, Blocks[0]);
    Assert.AreEqual<Integer>(2, Blocks[0].SourceMap[0]);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.SourceMapHandlesCodeBlock;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('```');
    Lines.Add('one');
    Lines.Add('two');
    Lines.Add('```');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.IsTrue(Blocks[0].Kind = bkCodeBlock);
    Assert.AreEqual('one'#13#10'two', Blocks[0].Text);
    AssertSourceMapValid(Lines, Blocks[0]);
    // 'one' starts on the second source line (after the fence + CRLF).
    Assert.AreEqual<Integer>(Length('```') + 2, Blocks[0].SourceMap[0]);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.SourceMapHandlesTable;
var
  Blocks: TMarkDownBlockList;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  Blocks := nil;
  try
    Lines.Add('| a | b |');
    Lines.Add('| --- | --- |');
    Lines.Add('| 1 | 2 |');
    Blocks := TMarkDownBlockParser.ParseBlocks(Lines);
    Assert.IsTrue(Blocks[0].Kind = bkTable);
    AssertSourceMapValid(Lines, Blocks[0]);
    Assert.AreEqual<Integer>(0, Blocks[0].SourceMap[0]);
  finally
    Blocks.Free;
    Lines.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineParsesEmojiShortcodes;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('Hello :smile: world :warning:!');
  try
    Assert.AreEqual<Integer>(5, Tokens.Count);
    Assert.AreEqual('Hello ', Tokens[0].Text);
    Assert.AreEqual(#$D83D#$DE0A, Tokens[1].Text);
    Assert.AreEqual(' world ', Tokens[2].Text);
    Assert.AreEqual(#$26A0#$FE0F, Tokens[3].Text);
    Assert.AreEqual('!', Tokens[4].Text);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.TokenMapHandlesEmoji;
var
  Tokens: TMarkDownInlineList;
  Map: TArray<Integer>;
  I: Integer;
begin
  SetLength(Map, 12);
  for I := 0 to 11 do
    Map[I] := I * 10;

  Tokens := TMarkDownBlockParser.ParseInline('A :smile: B', nil, Map);
  try
    Assert.AreEqual<Integer>(3, Tokens.Count);
    Assert.AreEqual('A ', Tokens[0].Text);
    Assert.AreEqual(#$D83D#$DE0A, Tokens[1].Text);
    Assert.AreEqual(' B', Tokens[2].Text);

    Assert.AreEqual<Integer>(3, Length(Tokens[1].SourceMap));
    Assert.AreEqual<Integer>(20, Tokens[1].SourceMap[0]);
    Assert.AreEqual<Integer>(20, Tokens[1].SourceMap[1]);
    Assert.AreEqual<Integer>(90, Tokens[1].SourceMap[2]);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineParsesHighlight;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('some ==highlighted== text');
  try
    Assert.AreEqual<Integer>(3, Tokens.Count);
    Assert.AreEqual('some ', Tokens[0].Text);
    Assert.IsFalse(Tokens[0].IsHighlighted);

    Assert.AreEqual('highlighted', Tokens[1].Text);
    Assert.IsTrue(Tokens[1].IsHighlighted);

    Assert.AreEqual(' text', Tokens[2].Text);
    Assert.IsFalse(Tokens[2].IsHighlighted);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.TokenMapHandlesHighlight;
var
  Tokens: TMarkDownInlineList;
  Map: TArray<Integer>;
  I: Integer;
begin
  SetLength(Map, 10);
  for I := 0 to 9 do
    Map[I] := I * 10;

  Tokens := TMarkDownBlockParser.ParseInline('A ==B== C', nil, Map);
  try
    Assert.AreEqual<Integer>(3, Tokens.Count);
    Assert.AreEqual('A ', Tokens[0].Text);
    Assert.AreEqual('B', Tokens[1].Text);
    Assert.AreEqual(' C', Tokens[2].Text);

    Assert.IsTrue(Tokens[1].IsHighlighted);
    Assert.AreEqual<Integer>(2, Length(Tokens[1].SourceMap));
    Assert.AreEqual<Integer>(40, Tokens[1].SourceMap[0]);
    Assert.AreEqual<Integer>(50, Tokens[1].SourceMap[1]);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.ParseInlineParsesSubSuper;
var
  Tokens: TMarkDownInlineList;
begin
  Tokens := TMarkDownBlockParser.ParseInline('x^2^ and H~2~O');
  try
    Assert.AreEqual<Integer>(5, Tokens.Count);
    Assert.AreEqual('x', Tokens[0].Text);
    Assert.IsFalse(Tokens[0].IsSuperscript);
    Assert.IsFalse(Tokens[0].IsSubscript);

    Assert.AreEqual('2', Tokens[1].Text);
    Assert.IsTrue(Tokens[1].IsSuperscript);
    Assert.IsFalse(Tokens[1].IsSubscript);

    Assert.AreEqual(' and H', Tokens[2].Text);
    Assert.IsFalse(Tokens[2].IsSuperscript);
    Assert.IsFalse(Tokens[2].IsSubscript);

    Assert.AreEqual('2', Tokens[3].Text);
    Assert.IsFalse(Tokens[3].IsSuperscript);
    Assert.IsTrue(Tokens[3].IsSubscript);

    Assert.AreEqual('O', Tokens[4].Text);
    Assert.IsFalse(Tokens[4].IsSuperscript);
    Assert.IsFalse(Tokens[4].IsSubscript);
  finally
    Tokens.Free;
  end;
end;

procedure TMarkDownParserTests.TokenMapHandlesSubSuper;
var
  Tokens: TMarkDownInlineList;
  Map: TArray<Integer>;
  I: Integer;
begin
  SetLength(Map, 12);
  for I := 0 to 11 do
    Map[I] := I * 10;

  Tokens := TMarkDownBlockParser.ParseInline('A ^B^ ~C~ D', nil, Map);
  try
    Assert.AreEqual<Integer>(5, Tokens.Count);
    Assert.AreEqual('A ', Tokens[0].Text);
    Assert.AreEqual('B', Tokens[1].Text);
    Assert.AreEqual(' ', Tokens[2].Text);
    Assert.AreEqual('C', Tokens[3].Text);
    Assert.AreEqual(' D', Tokens[4].Text);

    Assert.IsTrue(Tokens[1].IsSuperscript);
    Assert.AreEqual<Integer>(2, Length(Tokens[1].SourceMap));
    Assert.AreEqual<Integer>(30, Tokens[1].SourceMap[0]);
    Assert.AreEqual<Integer>(40, Tokens[1].SourceMap[1]);

    Assert.IsTrue(Tokens[3].IsSubscript);
    Assert.AreEqual<Integer>(2, Length(Tokens[3].SourceMap));
    Assert.AreEqual<Integer>(70, Tokens[3].SourceMap[0]);
    Assert.AreEqual<Integer>(80, Tokens[3].SourceMap[1]);
  finally
    Tokens.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMarkDownParserTests);

end.

unit uRhoMarkdownTypes;

{
  Document model for TRhoMarkdownViewer: blocks, inline tokens, and the
  source-position maps that tie them back to the markdown text.

  Framework-free by design - this unit knows nothing about FMX, Skia, or
  painting, so the parser, the HTML exporter, and the tests can all use it
  without dragging in a UI. Layout results do NOT live here; they belong to
  the viewer's display list (see uRhoMarkdownViewer), which works in TRectF
  because Skia measures in floats.
}

interface

uses
  System.Generics.Collections,
  System.UITypes,
  uRhoMarkdownHighlight;

const
  // System.UITypes declares TFontStyle with SCOPEDENUMS on, so the bare
  // fsBold/fsItalic/... spellings do not exist there - under VCL they came from
  // Vcl.Graphics, which re-exports them as constants. FMX has no equivalent, so
  // we re-export them here. This keeps the ported parser and HTML exporter
  // (which use the bare names throughout) compiling unchanged.
  fsBold = System.UITypes.TFontStyle.fsBold;
  fsItalic = System.UITypes.TFontStyle.fsItalic;
  fsUnderline = System.UITypes.TFontStyle.fsUnderline;
  fsStrikeOut = System.UITypes.TFontStyle.fsStrikeOut;

type
  TMarkDownBlockKind = (bkParagraph, bkHeading, bkQuote, bkListItem,
    bkCodeBlock, bkRule, bkTable, bkImage);

  // An inline run carries combinable emphasis (Style) so spans can nest,
  // e.g. bold containing italic, or a link whose text is bold. IsCode marks a
  // monospace code span, Url (when non-empty) marks the run as part of a link,
  // and LineBreak marks a hard line break (Text is empty for break tokens).
  //
  // These map one-to-one onto ISkParagraphBuilder.PushStyle/AddText pairs: the
  // style stack expresses the same nesting Style/Url/IsCode encode here.
  TMarkDownInlineToken = record
    Text: string;
    Style: TFontStyles;
    IsCode: Boolean;
    Url: string;
    LineBreak: Boolean;
    IsHighlighted: Boolean;
    IsSuperscript: Boolean;
    IsSubscript: Boolean;
    // An inline image: Url is the image source and Text is the alt text, shown
    // if the image cannot be loaded. Distinguishes an image from a link, which
    // also carries a Url.
    IsImage: Boolean;
    // Explicit size requested by an HTML <img width=.. height=..>. Zero means
    // unset (markdown ![]() images and attribute-less <img> use the default
    // fit-to-width sizing). When Pct is set the value is a fraction of the
    // content width (0.8 = "80%"); otherwise it is a pixel count. An explicit
    // width is allowed to upscale, unlike the default path.
    ImgWidth: Single;
    ImgWidthPct: Boolean;
    ImgHeight: Single;
    ImgHeightPct: Boolean;
    // Maps each character of Text to its 0-based document offset, with one
    // trailing entry for the position just past the last character (same shape
    // as TMarkDownBlock.SourceMap). Empty when the token was parsed without a
    // block source map.
    SourceMap: TArray<Integer>;
  end;

  TMarkDownInlineList = TList<TMarkDownInlineToken>;

  // Forward-declared so a block can hold a list of child blocks (containers).
  TMarkDownBlock = class;
  TMarkDownBlockList = TObjectList<TMarkDownBlock>;

  TMarkDownBlock = class
  private
    FHighlightTokens: TArray<TSourceToken>;
    FHighlightComputed: Boolean;
  public
    Kind: TMarkDownBlockKind;
    Text: string;
    Url: string;
    Level: Integer;
    IndentLevel: Integer;
    Ordered: Boolean;
    Number: Integer;
    IsTask: Boolean;
    TaskChecked: Boolean;
    CodeLanguage: string;
    SourceStartLine: Integer;
    // Maps each character of Text back to its 0-based offset in the original
    // document. SourceMap[i] is the offset of Text[i+1]; SourceMap has one
    // extra trailing entry for the position just past the last character.
    // Synthetic characters Text gains during block assembly (the spaces or
    // newlines that join wrapped source lines) map to the line break they
    // stand for. Empty when the block carries no mappable text.
    SourceMap: TArray<Integer>;
    InlineTokens: TMarkDownInlineList;
    // Child blocks for a container (a quote, and later a list item): the content
    // parsed from inside the container's stripped lines. nil for a leaf block.
    // Owned - freed with this block. A container carries its content here rather
    // than in Text, so nesting (a quote in a quote, a list in a quote) is just
    // recursion. See Docs/container-blocks-plan.md.
    Children: TMarkDownBlockList;
    destructor Destroy; override;
    // Syntax-highlight tokens for a code block, tokenized once on first request
    // and cached for the block's lifetime (blocks are rebuilt on every parse,
    // so the cache invalidates naturally). Returns nil when CodeLanguage has no
    // registered highlighter, which signals the plain (unhighlighted) path.
    // The paint path must use this accessor rather than re-tokenizing.
    function HighlightTokens: TArray<TSourceToken>;
  end;

implementation

destructor TMarkDownBlock.Destroy;
begin
  InlineTokens.Free;
  Children.Free;   // TObjectList - frees the child blocks it owns, recursively
  inherited Destroy;
end;

function TMarkDownBlock.HighlightTokens: TArray<TSourceToken>;
var
  Highlighter: IMarkdownSyntaxHighlighter;
begin
  if not FHighlightComputed then
  begin
    Highlighter := TMarkdownSyntaxHighlighterRegistry.GetHighlighter(CodeLanguage);
    if Highlighter <> nil then
      FHighlightTokens := Highlighter.Highlight(Text)
    else
      FHighlightTokens := nil;
    FHighlightComputed := True;
  end;
  Result := FHighlightTokens;
end;

end.

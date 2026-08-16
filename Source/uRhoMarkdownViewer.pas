unit uRhoMarkdownViewer;

{
  TRhoMarkdownViewer - a Skia-backed markdown viewer control for FMX.

  Architecture (mirrors ../RhoEditor, which solved this first):
    TControl
      +- FContent : TSkPaintBox   client-aligned, IS the viewport
      +- FVScroll : TScrollBar    we own scrolling; no TScrollBox

  Content coordinates are absolute from the top of the document. Screen
  coordinates are content minus FScrollY. Painters subtract it; hit-testing
  adds it back.

  LAYOUT IS SEPARATE FROM PAINT. EnsureLayout builds FLayout - a display list
  of positioned paragraphs - and is re-run only when the text, width, font, or
  colours change. ContentPaint just walks that list. Do not move measurement
  into the paint path; that fusion is exactly what made the VCL predecessor
  re-lay-out the whole document on every scroll tick.

  Not yet implemented: selection inside table cells, and inline (as opposed to
  block-level) images.
}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Math,
  System.Character,
  System.IOUtils,
  System.Generics.Collections,
  System.Skia,
  FMX.Controls,
  FMX.Types,
  FMX.StdCtrls,
  FMX.Platform,
  FMX.Skia,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  Winapi.ShellAPI,
  {$ENDIF}
  {$IFDEF MACOS}
  Posix.Stdlib,
  {$ENDIF}
  uRhoMarkdownTypes,
  uRhoMarkdownHighlight,
  uRhoMarkdownParser,
  uRhoMarkdownHtml;

type
  // A run of characters inside one paragraph that belongs to a link.
  // Offsets are 0-based UTF-16 code units - verified: ISkParagraph range
  // indices are UTF-16, matching Delphi's native string indexing, so no
  // conversion is needed even though AddText marshals to UTF-8 internally.
  TRhoLinkSpan = record
    StartChar: Integer;
    EndChar: Integer;      // exclusive
    Url: string;
  end;

  // A link's on-screen footprint, resolved once at layout time. X is absolute
  // (horizontal position never scrolls); Y is relative to the block's Top, so
  // hit-testing just adds Top - ScrollY. A link wrapped across lines has
  // several rects.
  TRhoLinkHit = record
    Url: string;
    Rects: TArray<TRectF>;
  end;

  // Something occupying a placeholder slot in a paragraph: either an inline
  // image or a super/subscript run drawn at a shifted baseline. Exactly one of
  // Image and Para is set.
  TRhoPlaceholder = record
    Image: ISkImage;
    Para: ISkParagraph;
    Rect: TRectF;          // filled from GetRectsForPlaceholders after layout
  end;

  // One laid-out table cell. Rect is relative to the table block's top-left,
  // so the whole table shifts with a scroll by offsetting the block once.
  TRhoTableCell = record
    Paragraph: ISkParagraph;
    Rect: TRectF;
    // Where this cell's text sits inside the table block's flattened
    // PlainText. Flattening (rather than giving TRhoDocPos a cell index) is
    // what lets selection treat a table like any other block.
    TextStart: Integer;
    TextLen: Integer;
  end;

  TRhoTableRow = TArray<TRhoTableCell>;

  // One key/value row of a YAML front-matter card. Keys share one column width
  // (KeyLeft..KeyLeft+key column), values wrap in the rest. Tops are relative to
  // the block's top-left, like table cells.
  TRhoMetaRow = record
    KeyPara: ISkParagraph;
    ValuePara: ISkParagraph;
    Top: Single;
    Height: Single;
    // Where each paragraph's text sits inside the block's flattened PlainText,
    // exactly as TRhoTableCell does it - this is what lets selection and search
    // highlight a card row instead of silently drawing nothing. The ': '
    // separator between them belongs to neither and so never highlights, the
    // same way a table's TAB separators do not.
    KeyStart: Integer;
    KeyLen: Integer;
    ValueStart: Integer;
    ValueLen: Integer;
  end;

  // One laid-out block. This is the display list: hit-testing, link rects, and
  // selection will all read this rather than being rebuilt during paint.
  TRhoBlockLayout = record
    Block: TMarkDownBlock;
    Paragraph: ISkParagraph;   // nil for rules and tables
    Marker: ISkParagraph;      // list bullet / number; nil otherwise
    Top: Single;               // block top, content coords
    Height: Single;            // full block height, including any padding
    TextLeft: Single;          // where Paragraph paints
    TextTop: Single;           // where Paragraph paints, content coords
    MarkerLeft: Single;
    BoxLeft: Single;           // extent of code background / quote bar / rule
    BoxRight: Single;
    Rows: TArray<TRhoTableRow>; // tables only; Rows[0] is the header
    MetaRows: TArray<TRhoMetaRow>; // front-matter card only
    MetaKeyLeft: Single;        // where key paragraphs paint (relative to BoxLeft)
    MetaValueLeft: Single;      // where value paragraphs paint (relative to BoxLeft)
    Image: ISkImage;           // block images only; nil means alt text was used
    ImageRect: TRectF;         // relative to the block top-left
    // Everything spliced into the text flow as a placeholder - inline images
    // and raised/lowered super/subscript runs - in the order added. Rects come
    // from GetRectsForPlaceholders after layout, so Skia decides placement.
    Placeholders: TArray<TRhoPlaceholder>;
    Links: TArray<TRhoLinkHit>; // every link in this block, cells included
    // The text Paragraph actually renders, and per-character 0-based offsets
    // back into the markdown source (-1 where a character has no source, e.g.
    // a decoded entity's replacement or a synthetic break). Together these let
    // a selection be copied either as plain text or as exact markdown.
    PlainText: string;
    CharSource: TArray<Integer>;
    // Text that logically precedes PlainText but is not part of the paragraph -
    // a list item's bullet, number, or checkbox, which are drawn as a separate
    // Marker paragraph. Used ONLY when building a plain-text copy. It must not
    // go into PlainText: that would make it longer than Skia's paragraph text
    // and skew every selection and link offset in the block.
    CopyPrefix: string;
  end;

  // A quote's vertical bar, resolved at layout time. A quote is a container, so
  // its content is flattened into the display list like any other block; the bar
  // is recorded separately as a span covering the quote's children. Nested
  // quotes produce several bars at increasing Left, which is how `>>` renders as
  // two bars. Top/Bottom are content coords (paint subtracts the scroll).
  TRhoQuoteBar = record
    Left: Single;
    Top: Single;
    Bottom: Single;
  end;

  TRhoLinkEvent = procedure(Sender: TObject; const AUrl: string) of object;

  // Fired after a task checkbox is toggled (only when AllowTaskToggle is on).
  // AChecked is the new state; AText is the item's rendered text, so a handler
  // can identify which task changed without reaching into the block list. The
  // source has already been rewritten and reparsed by the time this fires.
  TRhoTaskToggleEvent = procedure(Sender: TObject; const AText: string;
    AChecked: Boolean) of object;

  TRhoTheme = (rtLight, rtDark);

  // Document-wide horizontal placement for images. A single <img align=..>
  // overrides this for itself; markdown's own ![alt](url) has nowhere to put an
  // attribute, so this property is the only way to place those.
  TRhoImageAlign = (riaLeft, riaCenter, riaRight);

  // Per-token-kind colours for fenced code blocks, published as an expandable
  // node in the Object Inspector.
  //
  // TAlphaColors.Null means "unset - use the viewer's TextColor". That is what
  // lets a colour the host never touched follow the theme, while an explicitly
  // assigned one always wins (TAlphaColor properties cannot declare a `default`,
  // so streamed values are indistinguishable from untouched ones otherwise).
  TRhoSyntaxColors = class(TPersistent)
  private
    FPlainColor: TAlphaColor;
    FKeywordColor: TAlphaColor;
    FCommentColor: TAlphaColor;
    FStringColor: TAlphaColor;
    FNumberColor: TAlphaColor;
    FTypeColor: TAlphaColor;
    FPreprocessorColor: TAlphaColor;
    FSymbolColor: TAlphaColor;
    FOnChange: TNotifyEvent;
    procedure SetColor(var AField: TAlphaColor; const AValue: TAlphaColor);
    procedure SetPlainColor(const AValue: TAlphaColor);
    procedure SetKeywordColor(const AValue: TAlphaColor);
    procedure SetCommentColor(const AValue: TAlphaColor);
    procedure SetStringColor(const AValue: TAlphaColor);
    procedure SetNumberColor(const AValue: TAlphaColor);
    procedure SetTypeColor(const AValue: TAlphaColor);
    procedure SetPreprocessorColor(const AValue: TAlphaColor);
    procedure SetSymbolColor(const AValue: TAlphaColor);
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
    // Seeds the whole palette for a theme. The one place syntax colours are
    // defined - add a language-specific variant here, not at the call site.
    procedure ApplyTheme(ATheme: TRhoTheme);
    function ColorFor(AKind: TSourceTokenKind): TAlphaColor;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property PlainColor: TAlphaColor read FPlainColor write SetPlainColor;
    property KeywordColor: TAlphaColor read FKeywordColor write SetKeywordColor;
    property CommentColor: TAlphaColor read FCommentColor write SetCommentColor;
    property StringColor: TAlphaColor read FStringColor write SetStringColor;
    property NumberColor: TAlphaColor read FNumberColor write SetNumberColor;
    property TypeColor: TAlphaColor read FTypeColor write SetTypeColor;
    property PreprocessorColor: TAlphaColor read FPreprocessorColor
      write SetPreprocessorColor;
    property SymbolColor: TAlphaColor read FSymbolColor write SetSymbolColor;
  end;

  // A position in the document: which block, and how far into that block's
  // rendered text (0-based UTF-16, the same unit ISkParagraph uses). Ordered
  // by block then offset, which is what makes selection comparisons trivial.
  TRhoDocPos = record
    Block: Integer;
    Offset: Integer;
  end;

  // One search hit. Matching is deliberately WITHIN a block - a match never
  // spans a block boundary - so a hit is (block, start, length) rather than a
  // pair of TRhoDocPos. Start is an offset into FLayout[Block].PlainText, the
  // same 0-based UTF-16 unit TRhoDocPos uses.
  TRhoSearchMatch = record
    Block: Integer;      // index into FLayout
    Start: Integer;
    Len: Integer;
  end;

  TRhoMarkdownViewer = class(TControl)
  private
    FContent: TSkPaintBox;
    FVScroll: TScrollBar;

    FMarkdown: TStrings;
    FBlocks: TMarkDownBlockList;
    FReferences: TStringList;

    FLayout: TArray<TRhoBlockLayout>;
    FQuoteBars: TArray<TRhoQuoteBar>;
    FLayoutValid: Boolean;
    FLayoutWidth: Single;
    FContentHeight: Single;
    FScrollY: Single;
    FUpdatingScrollBar: Boolean;

    FBackgroundColor: TAlphaColor;
    FTextColor: TAlphaColor;
    FLinkColor: TAlphaColor;
    FCodeBackgroundColor: TAlphaColor;
    FQuoteBarColor: TAlphaColor;
    FRuleColor: TAlphaColor;
    FHeadingRuleColor: TAlphaColor;
    FHighlightColor: TAlphaColor;
    FFontFamily: string;
    FCodeFontFamily: string;
    FFontSize: Single;
    FContentPadding: Single;
    FImageAlign: TRhoImageAlign;
    FBasePath: string;
    FHoveredLink: string;
    FPressedLink: string;
    FOnLinkClick: TRhoLinkEvent;
    FOnScroll: TNotifyEvent;
    // Clickable task checkboxes. When FAllowTaskToggle is set, a click on a
    // task item's checkbox rewrites its [ ]/[x] in the markdown source and
    // reparses. FPressedTask is the FLayout index the mouse went down on (-1
    // for none), so a toggle fires only if press and release land on the same
    // box - the Copy-button pattern.
    FAllowTaskToggle: Boolean;
    FPressedTask: Integer;
    FOnTaskToggle: TRhoTaskToggleEvent;
    FSyntaxColors: TRhoSyntaxColors;
    FSelectionColor: TAlphaColor;
    // Floating "Copy" button on code blocks. FHoveredCode is the index into
    // FLayout of the code block under the pointer (-1 for none); FCopiedCode
    // is the one showing "Copied!" feedback, cleared by FCopiedTimer.
    FShowCodeCopyButton: Boolean;
    FHoveredCode: Integer;
    FCopiedCode: Integer;
    FCopyButtonHot: Boolean;
    FCopyButtonPressed: Boolean;
    FCopiedTimer: TTimer;
    FCopyLabel: ISkParagraph;
    FCopiedLabel: ISkParagraph;
    FSelAnchor: TRhoDocPos;
    FSelCaret: TRhoDocPos;
    FSelecting: Boolean;
    // Auto-scroll while drag-selecting past the viewport edge. The timer is
    // what makes the view keep scrolling when the pointer is held still
    // outside the control - MouseMove alone would scroll one step and stop.
    FAutoScrollTimer: TTimer;
    FAutoScrollStep: Single;
    FDragX: Single;
    FDragY: Single;
    // Find. FSearchMatches is derived from FLayout, so it is dropped whenever
    // the layout is (InvalidateLayout) and rebuilt lazily by
    // EnsureSearchMatches - FSearchValid is what tracks that. FSearchIndex is
    // the current match (-1 for none) and deliberately SURVIVES a re-layout:
    // PlainText does not depend on the width, so the same match list comes
    // back after a resize and the reader keeps their place.
    FSearchText: string;
    FSearchCaseSensitive: Boolean;
    FSearchWholeWords: Boolean;
    FSearchHighlightColor: TAlphaColor;
    FSearchCurrentColor: TAlphaColor;
    FSearchMatches: TArray<TRhoSearchMatch>;
    FSearchIndex: Integer;
    FSearchValid: Boolean;
    FOnSearchChange: TNotifyEvent;
    // Decoded images, keyed on resolved absolute path. A key present with a nil
    // value is a remembered failure, so a broken path is not retried on every
    // re-layout.
    FImageCache: TDictionary<string, ISkImage>;

    procedure MarkdownChanged(Sender: TObject);
    function GetBlockCount: Integer;
    function GetMarkdownText: string;
    procedure SetMarkdownText(const AValue: string);
    procedure SetMarkdown(AValue: TStrings);
    procedure SetBackgroundColor(const AValue: TAlphaColor);
    procedure SetTextColor(const AValue: TAlphaColor);
    procedure SetLinkColor(const AValue: TAlphaColor);
    procedure SetCodeBackgroundColor(const AValue: TAlphaColor);
    procedure SetQuoteBarColor(const AValue: TAlphaColor);
    procedure SetRuleColor(const AValue: TAlphaColor);
    procedure SetHeadingRuleColor(const AValue: TAlphaColor);
    procedure SetHighlightColor(const AValue: TAlphaColor);
    procedure SetFontFamily(const AValue: string);
    procedure SetCodeFontFamily(const AValue: string);
    procedure SetFontSize(const AValue: Single);
    procedure SetContentPadding(const AValue: Single);
    procedure SetImageAlign(const AValue: TRhoImageAlign);
    // Folds a token/block override together with the ImageAlign property, and
    // turns the result into a left offset inside AContentWidth.
    function ResolveImageAlign(
      const AOverride: TMarkDownAlign): TRhoImageAlign;
    function ImageOffsetFor(const AAlign: TRhoImageAlign;
      const AImageWidth, AContentWidth: Single): Single;
    function TryLoneImageAlign(ATokens: TMarkDownInlineList;
      out AAlign: TRhoImageAlign): Boolean;

    procedure Reparse;
    function InlineTokensFor(ABlock: TMarkDownBlock): TMarkDownInlineList;

    function BodyFamilies: TArray<string>;
    function CodeFamilies: TArray<string>;
    function BaseTextStyle(const ASize: Single;
      const ABold, AItalic: Boolean): ISkTextStyle;
    function StyleForToken(const AToken: TMarkDownInlineToken;
      const ABaseSize: Single; const ABaseBold, ABaseItalic: Boolean)
      : ISkTextStyle;
    function SyntaxColorFor(AKind: TSourceTokenKind): TAlphaColor;

    function BuildTokens(ATokens: TMarkDownInlineList; const AFallbackText: string;
      const AWidth, ASize: Single; const ABold, AItalic: Boolean;
      const AAlign: TSkTextAlign; out ASpans: TArray<TRhoLinkSpan>;
      out APlainText: string; out ACharSource: TArray<Integer>;
      out APlaceholders: TArray<TRhoPlaceholder>): ISkParagraph;
    // AAlign is the alignment inherited from an enclosing <p>/<div align=..>
    // container; maDefault means "none", which leaves the existing behaviour
    // (left, except for a paragraph that is nothing but one image).
    function BuildInline(ABlock: TMarkDownBlock; const AWidth, ASize: Single;
      const ABold, AItalic: Boolean; const AAlign: TMarkDownAlign;
      out ASpans: TArray<TRhoLinkSpan>;
      var ALayout: TRhoBlockLayout): ISkParagraph;
    function BuildCellText(const AText: string; const AWidth: Single;
      const ABold: Boolean; const AAlign: TSkTextAlign;
      out ASpans: TArray<TRhoLinkSpan>; out APlain: string): ISkParagraph;
    procedure CollectLinkRects(const AParagraph: ISkParagraph;
      const ASpans: TArray<TRhoLinkSpan>; const AOriginX, AOriginY: Single;
      var ALinks: TArray<TRhoLinkHit>);
    procedure DoLinkClick(const AUrl: string);
    procedure OpenUrl(const AUrl: string);
    // Index into FLayout of the heading whose slug matches AName, or -1.
    function FindAnchor(const AName: string): Integer;
    // Lays the document out at the current content width if it is not already
    // valid, so anchor lookups work before the first paint.
    procedure EnsureLayoutForCurrentWidth;
    // Index into FLayout of the task list item whose checkbox is at (AX, AY) in
    // viewport coordinates, or -1. The checkbox geometry matches PaintDecorations.
    function TaskAt(const AX, AY: Single): Integer;
    // Flips the [ ]/[x] of the task at FLayout[AIndex] in the markdown source,
    // reparses, and fires OnTaskToggle. A no-op if the block is not a task.
    procedure ToggleTask(const AIndex: Integer);
    procedure SetSelectionColor(const AValue: TAlphaColor);
    procedure SetSyntaxColors(AValue: TRhoSyntaxColors);
    procedure SyntaxColorsChanged(Sender: TObject);
    function PosAt(const AX, AY: Single): TRhoDocPos;
    function SelectionRange(out AFrom, ATo: TRhoDocPos): Boolean;
    procedure PaintSelection(const ACanvas: ISkCanvas;
      const AIndex: Integer; const AScrollY: Single);
    function SourceOffsetAt(const APos: TRhoDocPos;
      const AForward: Boolean): Integer;

    procedure SetSearchText(const AValue: string);
    procedure SetSearchCaseSensitive(const AValue: Boolean);
    procedure SetSearchWholeWords(const AValue: Boolean);
    procedure SetSearchHighlightColor(const AValue: TAlphaColor);
    procedure SetSearchCurrentColor(const AValue: TAlphaColor);
    function GetSearchMatchCount: Integer;
    // Drops the match list without touching FSearchIndex. Called from
    // InvalidateLayout, because a match indexes into FLayout.
    procedure InvalidateSearchMatches;
    // Scans FLayout for FSearchText. Assumes a valid layout; go through
    // EnsureSearchMatches rather than calling this directly.
    procedure RebuildSearchMatches;
    procedure EnsureSearchMatches;
    // Advances to the next/previous match, wrapping. With no current match it
    // starts from the viewport rather than the top of the document.
    function StepSearch(const AForward: Boolean): Boolean;
    // Rects covering [AStart, AEnd) of a block's rendered text, in CONTENT
    // coordinates (X absolute, Y from the document top). Several rects when the
    // range wraps a line or spans table cells / front-matter rows.
    //
    // The ONE place a character range becomes geometry: selection and search
    // both go through it, so a block kind that highlights for one highlights
    // for the other. Add a multi-paragraph block kind here and both work.
    procedure CollectRangeRects(const ABlock, AStart, AEnd: Integer;
      var ARects: TArray<TRectF>);
    procedure ScrollMatchIntoView(const AMatch: TRhoSearchMatch);
    procedure PaintSearchMatches(const ACanvas: ISkCanvas;
      const AIndex: Integer; const AScrollY: Single);
    procedure DoSearchChange;
    function TableOffsetAt(const ALayout: TRhoBlockLayout;
      const AX, AContentY: Single): Integer;
    procedure UpdateAutoScroll(const AY: Single);
    procedure AutoScrollTick(Sender: TObject);
    procedure SetShowCodeCopyButton(const AValue: Boolean);
    procedure EnsureCopyLabels;
    function CodeButtonRect(const ALayout: TRhoBlockLayout;
      const AScreenTop: Single): TRectF;
    // Index into FLayout of the code block whose Copy button is at (AX, AY),
    // or -1. AOverButton reports whether the point is on the button itself
    // rather than merely inside the block.
    function CodeBlockAt(const AX, AY: Single; out AOverButton: Boolean): Integer;
    procedure CopyCodeBlock(AIndex: Integer);
    procedure CopiedTick(Sender: TObject);
    procedure ContentMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Single);
    procedure ContentMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure ContentMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure ContentMouseLeave(Sender: TObject);
    procedure LayoutTable(ABlock: TMarkDownBlock; const AContentLeft,
      AContentWidth: Single; var ALayout: TRhoBlockLayout);
    // Lays out a YAML front-matter block as a two-column key/value card.
    procedure LayoutFrontMatter(ABlock: TMarkDownBlock; const AContentLeft,
      AContentWidth: Single; var ALayout: TRhoBlockLayout);
    // Chrome and text are separate passes for tables and front-matter cards
    // alike, because the selection / search highlight layer paints BETWEEN
    // them. Merge them again and an opaque highlight hides the text.
    procedure PaintFrontMatterPanel(const ACanvas: ISkCanvas;
      const ALayout: TRhoBlockLayout; const AScreenTop: Single);
    procedure PaintFrontMatterText(const ACanvas: ISkCanvas;
      const ALayout: TRhoBlockLayout; const AScreenTop: Single);
    function ResolveImagePath(const AUrl: string): string;
    function ImageFor(const AUrl: string): ISkImage;
    procedure SetBasePath(const AValue: string);
    procedure PaintTableChrome(const ACanvas: ISkCanvas;
      const ALayout: TRhoBlockLayout; const AScreenTop: Single);
    procedure PaintTableText(const ACanvas: ISkCanvas;
      const ALayout: TRhoBlockLayout; const AScreenTop: Single);
    function BuildCode(ABlock: TMarkDownBlock;
      const AWidth: Single): ISkParagraph;
    function BuildRun(const AText: string;
      const AStyle: ISkTextStyle): ISkParagraph;
    function BuildMarker(const AText: string;
      const ASize: Single): ISkParagraph;
    function HeadingSize(ALevel: Integer): Single;
    procedure LayoutBlock(ABlock: TMarkDownBlock; const AContentLeft,
      AContentWidth: Single; var ALayout: TRhoBlockLayout;
      const AInQuote: Boolean = False;
      const AAlign: TMarkDownAlign = maDefault);
    // Counts the leaf (non-container) blocks in a tree, so EnsureLayout can size
    // the flat display list once before filling it.
    function CountLeaves(ABlocks: TMarkDownBlockList): Integer;
    // Lays a block sequence out, recursing into container children and
    // flattening every leaf into FLayout in document order. AContentLeft grows
    // with each nesting level; a quote also records a bar span in FQuoteBars.
    procedure LayoutBlocks(ABlocks: TMarkDownBlockList;
      const AContentLeft, AContentWidth: Single; const AInQuote: Boolean;
      const AAlign: TMarkDownAlign;
      const AGap: Single; var AIndex: Integer; var AY: Single);
    procedure EnsureLayout(const AWidth: Single);

    procedure UpdateScrollBar;
    procedure ScrollBarChange(Sender: TObject);
    function ViewportHeight: Single;
    function LineStep: Single;
    function PageStep: Single;

    procedure PaintDecorations(const ACanvas: ISkCanvas;
      const ALayout: TRhoBlockLayout; const AScreenTop: Single);
    procedure PaintCodeButton(const ACanvas: ISkCanvas;
      const ALayout: TRhoBlockLayout; const AScreenTop: Single;
      const AIndex: Integer);
    procedure PaintDocument(const ACanvas: ISkCanvas;
      const AWidth, AHeight, AScrollY: Single);
    procedure ContentPaint(ASender: TObject; const ACanvas: ISkCanvas;
      const ADest: TRectF; const AOpacity: Single);
    procedure ContentResize(Sender: TObject);
  protected
    procedure Loaded; override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer;
      var Handled: Boolean); override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar;
      Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Drag-and-drop targeting. See the implementation: without this the internal
    // paint box swallows every drop and the published OnDrag* events never fire.
    function FindTarget(P: TPointF; const Data: TDragObject): IControl; override;

    procedure LoadFromFile(const AFileName: string);

    // Sets every colour surface from one curated palette, syntax colours
    // included. Deliberately a METHOD, not a published property: a published
    // Theme would re-apply on .fmx load and clobber colours the host had set
    // by hand. Every colour stays individually overridable afterwards.
    procedure ApplyTheme(ATheme: TRhoTheme);
    // Drops the cached layout and repaints. Call after anything that changes
    // measurement or appearance: text, width, font, padding, or colour.
    procedure InvalidateLayout;
    procedure RedrawContent;
    // Scroll position in content coordinates, clamped to the document.
    procedure SetScrollPos(const AY: Single);

    // Scrolls the heading whose GitHub-style slug matches AName to the top of
    // the view, and reports whether one was found. A leading '#' is optional, so
    // a link target can be passed straight through. This is what makes in-page
    // anchor links and tables of contents work; see RhoHeadingSlug.
    function ScrollToAnchor(const AName: string): Boolean;

    // HTML export of the current document. AsHtml returns a fragment for
    // embedding; AsHtmlDocument wraps it in a complete page. Both go through
    // the same parser the viewer renders with, so the output matches what is
    // on screen. uRhoMarkdownHtml also exposes MarkdownToHtml /
    // MarkdownToHtmlDocument as plain functions, for converting without a
    // control.
    function AsHtml: string;
    function AsHtmlDocument(const ATitle: string = ''): string;

    // Headless rendering. Lays the document out at AWidth and returns its full
    // height, without needing the control to be parented or shown - so a
    // console tool can render markdown to an image through the real layout and
    // paint path. See Tools/MarkdownRender.
    function MeasureDocument(const AWidth: Single): Single;
    procedure RenderToCanvas(const ACanvas: ISkCanvas;
      const AWidth, AHeight: Single; const AScrollY: Single = 0);

    property MarkdownText: string read GetMarkdownText write SetMarkdownText;
    property ScrollY: Single read FScrollY;
    property ContentHeight: Single read FContentHeight;
    property BlockCount: Integer read GetBlockCount;
    // Url of the link at a point in viewport coordinates, or '' if none.
    function LinkAt(const AX, AY: Single): string;

    function HasSelection: Boolean;
    procedure SelectAll;
    procedure ClearSelection;
    // The current selection, either as the markdown that produced it or as the
    // rendered plain text.
    function SelectedText(APlainText: Boolean = False): string;
    procedure CopySelection(APlainText: Boolean = False);

    // ---- find ----
    //
    // The component owns the MECHANISM only: matching against the rendered
    // text, highlighting, and scrolling a match into view - none of which a
    // host can reach, since they need the display list and the paint pass. The
    // find bar itself (edit box, Ctrl+F, up/down buttons, match counter) is the
    // host's, so it can style it to fit its own UI.
    //
    // Typical wiring: assign SearchText as the user types (highlights appear
    // immediately; nothing scrolls), then call FindNext from the Enter key or
    // the down button. F3 / Shift+F3 are handled here already.
    //
    // Matching is WITHIN a block: a phrase spanning a paragraph break is not
    // found. Blocks that render no text (rules, images) never match, and a
    // front-matter card highlights nothing because its rows are separate
    // paragraphs - FindNext still scrolls to it.

    // Moves to the next/previous match, wrapping at the ends, and scrolls it
    // into view. Returns False only when there are no matches at all. With no
    // current match, FindNext starts at the first match at or below the top of
    // the viewport - what the reader is looking at, not the top of the file.
    function FindNext: Boolean;
    function FindPrevious: Boolean;
    // Clears SearchText and every highlight.
    procedure ClearSearch;
    // Number of matches in the document, 0 when SearchText is ''. Reading it
    // lays the document out if that has not happened yet.
    property SearchMatchCount: Integer read GetSearchMatchCount;
    // 0-based index of the current match, or -1 when none is current (before
    // the first FindNext, or after SearchText changes).
    property SearchMatchIndex: Integer read FSearchIndex;
  published
    // Fired when a link is clicked. With no handler assigned the Url is opened
    // in the system browser.
    property OnLinkClick: TRhoLinkEvent read FOnLinkClick write FOnLinkClick;
    // Fires on any actual change of scroll position, from any source - wheel,
    // scrollbar, keyboard or drag auto-scroll. Use it to sync an external
    // editor or status display.
    property OnScroll: TNotifyEvent read FOnScroll write FOnScroll;
    // When True, clicking a task list checkbox toggles it and rewrites the
    // markdown source. Off by default, keeping the viewer read-only.
    property AllowTaskToggle: Boolean read FAllowTaskToggle
      write FAllowTaskToggle default False;
    // Fired after a checkbox toggle (see TRhoTaskToggleEvent). Only reached
    // when AllowTaskToggle is on.
    property OnTaskToggle: TRhoTaskToggleEvent read FOnTaskToggle
      write FOnTaskToggle;
    // Fires whenever the search state changes - the text, the options, or the
    // current match. Use it to update a match counter; read SearchMatchCount
    // and SearchMatchIndex from the handler. Never fired from the paint pass.
    property OnSearchChange: TNotifyEvent read FOnSearchChange
      write FOnSearchChange;
    property Markdown: TStrings read FMarkdown write SetMarkdown;

    // What to find. Setting it re-highlights but does NOT scroll; call
    // FindNext for that. Set it to '' to clear the highlights.
    property SearchText: string read FSearchText write SetSearchText;
    property SearchCaseSensitive: Boolean read FSearchCaseSensitive
      write SetSearchCaseSensitive default False;
    // When True, a match must be delimited by non-word characters. "Word" is
    // letters, digits and underscore, Unicode-aware.
    property SearchWholeWords: Boolean read FSearchWholeWords
      write SetSearchWholeWords default False;

    // TAlphaColor properties take no `default` - the constants exceed MaxInt.
    property BackgroundColor: TAlphaColor read FBackgroundColor
      write SetBackgroundColor;
    property TextColor: TAlphaColor read FTextColor write SetTextColor;
    property LinkColor: TAlphaColor read FLinkColor write SetLinkColor;
    property CodeBackgroundColor: TAlphaColor read FCodeBackgroundColor
      write SetCodeBackgroundColor;
    property QuoteBarColor: TAlphaColor read FQuoteBarColor
      write SetQuoteBarColor;
    property RuleColor: TAlphaColor read FRuleColor write SetRuleColor;
    // Colour of the H1/H2 underline rule, independent of RuleColor (which the
    // horizontal rule, table borders, checkboxes and copy button still use).
    // ApplyTheme sets it to match RuleColor, so by default the rules look the
    // same. Set it to TAlphaColors.Null to switch the heading rules off - the
    // clNone-to-disable behaviour the VCL predecessor had.
    property HeadingRuleColor: TAlphaColor read FHeadingRuleColor
      write SetHeadingRuleColor;
    property HighlightColor: TAlphaColor read FHighlightColor
      write SetHighlightColor;
    property SelectionColor: TAlphaColor read FSelectionColor
      write SetSelectionColor;
    // Every search match gets SearchHighlightColor; the current one gets
    // SearchCurrentMatchColor instead, so it stands out from its neighbours.
    // TAlphaColors.Null on either suppresses that highlight.
    property SearchHighlightColor: TAlphaColor read FSearchHighlightColor
      write SetSearchHighlightColor;
    property SearchCurrentMatchColor: TAlphaColor read FSearchCurrentColor
      write SetSearchCurrentColor;
    // Floating "Copy" button shown when the pointer is over a fenced code
    // block. Set False for a completely static preview.
    property ShowCodeCopyButton: Boolean read FShowCodeCopyButton
      write SetShowCodeCopyButton default True;
    // Expandable node in the Object Inspector; also settable in code.
    property SyntaxColors: TRhoSyntaxColors read FSyntaxColors
      write SetSyntaxColors;

    property FontFamily: string read FFontFamily write SetFontFamily;
    property CodeFontFamily: string read FCodeFontFamily write SetCodeFontFamily;
    // Single, so no `default` either.
    property FontSize: Single read FFontSize write SetFontSize;
    property ContentPadding: Single read FContentPadding write SetContentPadding;
    // Where images sit in the content width. Applies to markdown ![alt](url)
    // images and to any <img> that does not carry its own align attribute.
    property ImageAlign: TRhoImageAlign read FImageAlign write SetImageAlign
      default riaLeft;
    // Folder that relative image paths resolve against. LoadFromFile sets this
    // to the markdown file's own folder, so images "just work" for a loaded doc.
    property BasePath: string read FBasePath write SetBasePath;

    // TControl keeps these PUBLIC, so a directly-derived control must
    // re-publish them or it cannot be laid out in the designer.
    property Align;
    property Anchors;
    property Enabled;
    // Size is the one that STREAMS: TControl declares Width and Height with
    // `stored False`, so they are convenience accessors only. Omitting Size
    // means a form holding this component fails to load with
    // "Property Size.Width does not exist".
    property Size;
    property Height;
    property Width;
    property Position;
    property Margins;
    property Padding;
    property Opacity;
    property Visible;
    property TabOrder;
    property HitTest;
    property ShowHint;
    property PopupMenu;

    property OnClick;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyUp;

    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseWheel;

    property OnResize;

    property OnDragEnter;
    property OnDragLeave;
    property OnDragOver;
    property OnDragDrop;
    property OnDragEnd;
  end;

// Turns heading text into a GitHub-compatible anchor slug: lower-cased, with
// everything that is not a letter, digit, space, hyphen or underscore removed,
// and spaces turned into hyphens. Exposed so a host can build a table of
// contents whose links match what ScrollToAnchor resolves.
function RhoHeadingSlug(const AText: string): string;

implementation

function RhoHeadingSlug(const AText: string): string;
var
  I: Integer;
  Ch: Char;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    for I := 1 to Length(AText) do
    begin
      Ch := AText[I];
      // IsLetterOrDigit is Unicode-aware, so non-ASCII headings slug sensibly
      // rather than losing every accented character.
      if Ch.IsLetterOrDigit then
        SB.Append(Ch.ToLower)
      else if Ch = ' ' then
        SB.Append('-')
      else if (Ch = '-') or (Ch = '_') then
        SB.Append(Ch);
      // Everything else (punctuation, symbols) is dropped, as on GitHub.
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

const
  // VS-ish light baseline, and VS Code Dark+ for the dark variant.
  LightPlain = TAlphaColors.Null;   // follow TextColor
  LightKeyword = TAlphaColor($FF0000FF);
  LightComment = TAlphaColor($FF008000);
  LightString = TAlphaColor($FFA31515);
  // Purple, not VS Code Light+'s $FF098658. That green sits too close to the
  // comment green above to tell apart at code-block size - numbers and
  // comments read as the same colour. Purple collides with nothing else in
  // this palette.
  LightNumber = TAlphaColor($FF6F42C1);
  LightType = TAlphaColor($FF2B91AF);
  LightPreproc = TAlphaColor($FF808080);
  LightSymbol = TAlphaColor($FF505050);

  DarkPlain = TAlphaColors.Null;
  DarkKeyword = TAlphaColor($FF569CD6);
  DarkComment = TAlphaColor($FF6A9955);
  DarkString = TAlphaColor($FFCE9178);
  // Light purple, for the same reason: Dark+'s $FFB5CEA8 pale green is too
  // near the comment green.
  DarkNumber = TAlphaColor($FFD2A8FF);
  DarkType = TAlphaColor($FF4EC9B0);
  DarkPreproc = TAlphaColor($FF9B9B9B);
  DarkSymbol = TAlphaColor($FFB4B4B4);

// True if any UTF-16 unit is half of a surrogate pair. Such a character spans
// two positions, which would break the one-placeholder-per-position alignment
// the super/subscript path depends on.
function HasSurrogate(const S: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if S[I].IsSurrogate then
      Exit(True);
  Result := False;
end;

{ TRhoSyntaxColors }

constructor TRhoSyntaxColors.Create;
begin
  inherited Create;
  ApplyTheme(rtLight);
end;

procedure TRhoSyntaxColors.SetColor(var AField: TAlphaColor;
  const AValue: TAlphaColor);
begin
  if AField = AValue then
    Exit;
  AField := AValue;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TRhoSyntaxColors.SetPlainColor(const AValue: TAlphaColor);
begin SetColor(FPlainColor, AValue); end;
procedure TRhoSyntaxColors.SetKeywordColor(const AValue: TAlphaColor);
begin SetColor(FKeywordColor, AValue); end;
procedure TRhoSyntaxColors.SetCommentColor(const AValue: TAlphaColor);
begin SetColor(FCommentColor, AValue); end;
procedure TRhoSyntaxColors.SetStringColor(const AValue: TAlphaColor);
begin SetColor(FStringColor, AValue); end;
procedure TRhoSyntaxColors.SetNumberColor(const AValue: TAlphaColor);
begin SetColor(FNumberColor, AValue); end;
procedure TRhoSyntaxColors.SetTypeColor(const AValue: TAlphaColor);
begin SetColor(FTypeColor, AValue); end;
procedure TRhoSyntaxColors.SetPreprocessorColor(const AValue: TAlphaColor);
begin SetColor(FPreprocessorColor, AValue); end;
procedure TRhoSyntaxColors.SetSymbolColor(const AValue: TAlphaColor);
begin SetColor(FSymbolColor, AValue); end;

procedure TRhoSyntaxColors.Assign(ASource: TPersistent);
var
  S: TRhoSyntaxColors;
begin
  if ASource is TRhoSyntaxColors then
  begin
    S := TRhoSyntaxColors(ASource);
    FPlainColor := S.FPlainColor;
    FKeywordColor := S.FKeywordColor;
    FCommentColor := S.FCommentColor;
    FStringColor := S.FStringColor;
    FNumberColor := S.FNumberColor;
    FTypeColor := S.FTypeColor;
    FPreprocessorColor := S.FPreprocessorColor;
    FSymbolColor := S.FSymbolColor;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end
  else
    inherited Assign(ASource);
end;

procedure TRhoSyntaxColors.ApplyTheme(ATheme: TRhoTheme);
begin
  if ATheme = rtDark then
  begin
    FPlainColor := DarkPlain;
    FKeywordColor := DarkKeyword;
    FCommentColor := DarkComment;
    FStringColor := DarkString;
    FNumberColor := DarkNumber;
    FTypeColor := DarkType;
    FPreprocessorColor := DarkPreproc;
    FSymbolColor := DarkSymbol;
  end
  else
  begin
    FPlainColor := LightPlain;
    FKeywordColor := LightKeyword;
    FCommentColor := LightComment;
    FStringColor := LightString;
    FNumberColor := LightNumber;
    FTypeColor := LightType;
    FPreprocessorColor := LightPreproc;
    FSymbolColor := LightSymbol;
  end;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

function TRhoSyntaxColors.ColorFor(AKind: TSourceTokenKind): TAlphaColor;
begin
  case AKind of
    stKeyword:      Result := FKeywordColor;
    stComment:      Result := FCommentColor;
    stString:       Result := FStringColor;
    stNumber:       Result := FNumberColor;
    stType:         Result := FTypeColor;
    stPreprocessor: Result := FPreprocessorColor;
    stSymbol:       Result := FSymbolColor;
  else
    Result := FPlainColor;
  end;
end;

const
  // Font fallback: the primary family first, then a platform emoji face so the
  // parser's :smile:/:warning: shortcodes render as emoji instead of tofu.
  // ISkParagraph does the run splitting - unlike a bare ISkFont, which is why
  // RhoEditor could not do this.
  // SymbolFontFamily is a second fallback: the emoji fonts cover pictographic
  // codepoints but not all of the symbol/dingbat ranges markdown reaches for
  // (arrows, check marks, box drawing), which otherwise render as tofu.
  {$IFDEF MSWINDOWS}
  DefaultFontFamily = 'Segoe UI';
  DefaultCodeFontFamily = 'Consolas';
  EmojiFontFamily = 'Segoe UI Emoji';
  SymbolFontFamily = 'Segoe UI Symbol';
  {$ENDIF}
  {$IFDEF MACOS}
  DefaultFontFamily = 'Helvetica Neue';
  DefaultCodeFontFamily = 'Menlo';
  EmojiFontFamily = 'Apple Color Emoji';
  SymbolFontFamily = 'Apple Symbols';
  {$ENDIF}

  ScrollBarSize = 16;
  WheelStep = 40;
  AutoScrollMargin  = 24;   // edge zone that starts a drag-scroll
  AutoScrollMaxStep = 24;   // cap, so a fast drag does not fly off
  AutoScrollInterval = 30;  // ms between drag-scroll steps

  // Geometry, carried over from the VCL predecessor so documents lay out the
  // same way. Scaled by FontSize where it should track text size.
  ListIndentPerLevel = 16;   // per nesting level
  ListTextIndent     = 22;   // marker gutter width
  ListMarkerGap      = 4;    // minimum space between an ordered marker and text
  QuoteBarWidth      = 4;
  QuoteTextIndent    = 13;
  CodePadding        = 8;
  RuleThickness      = 1;
  CheckBoxSize       = 13;   // task checkbox; see TaskBoxGap
  // A checkbox needs more clearance than a number does. Its stroked border is
  // hard ink right at the box edge, where a glyph carries side bearing inside
  // its advance -- so an identical numeric gap reads much tighter for the box.
  TaskBoxGap         = 6;
  TableCellPadH      = 8;
  TableCellPadV      = 4;
  CodeButtonInset    = 6;
  CodeButtonPadH     = 8;
  CodeButtonPadV     = 3;
  CodeButtonScale    = 0.8;   // label size, as a fraction of FontSize
  CopiedFeedbackMs   = 1200;  // how long "Copied!" stays up

  // Heading sizes as multiples of FontSize, H1..H6.
  HeadingScale: array [1 .. 6] of Single = (2.0, 1.6, 1.35, 1.15, 1.0, 0.9);

  // Vertical gap after a block, as a multiple of FontSize.
  BlockGapScale = 0.6;
  // Extra space under an H1/H2 rule.
  HeadingRuleGap = 4;

  SuperSubScale = 0.75;
  // How far a super/subscript baseline shifts, as a fraction of the base size.
  SuperSubShift = 0.33;
  CodeSpanScale = 0.95;

constructor TRhoMarkdownViewer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FShowCodeCopyButton := True;
  FHoveredCode := -1;
  FCopiedCode := -1;
  FPressedTask := -1;
  FSelAnchor.Block := -1;
  FSelCaret.Block := -1;
  FSearchIndex := -1;

  // Created before ApplyTheme, which retunes it. OnChange is hooked up after
  // the initial theme so construction does not trigger a pointless re-layout.
  FSyntaxColors := TRhoSyntaxColors.Create;
  ApplyTheme(rtLight);
  FSyntaxColors.OnChange := SyntaxColorsChanged;
  FFontFamily := DefaultFontFamily;
  FCodeFontFamily := DefaultCodeFontFamily;
  FFontSize := 14;
  FContentPadding := 12;
  FImageAlign := riaLeft;

  FMarkdown := TStringList.Create;
  TStringList(FMarkdown).OnChange := MarkdownChanged;
  FReferences := TStringList.Create;
  FBlocks := TMarkDownBlockList.Create(True);
  FImageCache := TDictionary<string, ISkImage>.Create;

  Width := 400;
  Height := 300;
  CanFocus := True;

  // FMX does not clip children to the parent by default, so a child positioned
  // past the edge paints over whatever sits beside the control.
  ClipChildren := True;

  // NOTE Stored := False on every internally-created child. FMX streams a
  // control's children into the .fmx; without this, dropping the component on
  // a form writes them to the form file and the constructor creates them again
  // on load - duplicate scrollbars and paint box.
  FVScroll := TScrollBar.Create(Self);
  FVScroll.Stored := False;
  FVScroll.Parent := Self;
  FVScroll.Orientation := TOrientation.Vertical;
  FVScroll.Align := TAlignLayout.Right;
  FVScroll.Width := ScrollBarSize;
  FVScroll.OnChange := ScrollBarChange;

  FContent := TSkPaintBox.Create(Self);
  FContent.Stored := False;
  FContent.Parent := Self;
  FContent.Align := TAlignLayout.Client;
  FContent.HitTest := True;
  FContent.AutoCapture := True;   // keep getting MouseMove during drag-select
  FContent.OnDraw := ContentPaint;
  // Width-dependent re-layout must hang off FContent.OnResize, NOT our own
  // Resize: FContent is realigned AFTER Resize runs, so inside Resize the paint
  // box still reports its previous width.
  FContent.OnResize := ContentResize;
  FContent.OnMouseMove := ContentMouseMove;
  FContent.OnMouseDown := ContentMouseDown;
  FContent.OnMouseUp := ContentMouseUp;
  FContent.OnMouseLeave := ContentMouseLeave;

  FAutoScrollTimer := TTimer.Create(Self);
  FAutoScrollTimer.Stored := False;
  FAutoScrollTimer.Enabled := False;
  FAutoScrollTimer.Interval := AutoScrollInterval;
  FAutoScrollTimer.OnTimer := AutoScrollTick;

  FCopiedTimer := TTimer.Create(Self);
  FCopiedTimer.Stored := False;
  FCopiedTimer.Enabled := False;
  FCopiedTimer.Interval := CopiedFeedbackMs;
  FCopiedTimer.OnTimer := CopiedTick;
end;

destructor TRhoMarkdownViewer.Destroy;
begin
  FSyntaxColors.Free;
  FImageCache.Free;
  FBlocks.Free;
  FReferences.Free;
  FMarkdown.Free;
  inherited Destroy;
end;

function TRhoMarkdownViewer.FindTarget(P: TPointF;
  const Data: TDragObject): IControl;
begin
  // FMX picks a drop target with TControl.FindTarget, which recurses into
  // children FIRST and returns the first one that claims the point - only
  // returning Self if none does. We are a composite control: FContent (the
  // client-aligned, hit-testable paint box) covers the whole client area, so it
  // always won, and since it has no drag handlers the drop was silently refused
  // and our own published OnDragOver / OnDragDrop never fired.
  //
  // Claim any hit inside our bounds for the control itself, so a host's drag
  // handlers behave exactly as they would on a simple control. The form then
  // calls OUR DragEnter/DragOver/DragDrop, and passes points already converted
  // to our local coordinates, so no fixing up is needed. Making FContent
  // HitTest := False would "fix" this too, but would break clicking, link
  // hit-testing and drag-selection - do not do that.
  Result := inherited FindTarget(P, Data);
  if Result <> nil then
    Result := Self;
end;

procedure TRhoMarkdownViewer.Loaded;
begin
  inherited Loaded;
  // Streamed Markdown arrives during csLoading, when MarkdownChanged has
  // nothing useful to lay out against yet. Parse once here instead.
  Reparse;
end;

function TRhoMarkdownViewer.GetBlockCount: Integer;
begin
  Result := FBlocks.Count;
end;

{ ---- text in ---- }

procedure TRhoMarkdownViewer.MarkdownChanged(Sender: TObject);
begin
  if csLoading in ComponentState then
    Exit;
  Reparse;
end;

function TRhoMarkdownViewer.GetMarkdownText: string;
begin
  Result := FMarkdown.Text;
end;

procedure TRhoMarkdownViewer.SetMarkdownText(const AValue: string);
begin
  FMarkdown.Text := AValue;   // fires MarkdownChanged
end;

procedure TRhoMarkdownViewer.SetMarkdown(AValue: TStrings);
begin
  FMarkdown.Assign(AValue);
end;

procedure TRhoMarkdownViewer.LoadFromFile(const AFileName: string);
begin
  // Set BasePath first: assigning the text triggers the reparse and layout,
  // and image paths resolve during layout.
  FBasePath := TPath.GetDirectoryName(TPath.GetFullPath(AFileName));
  FImageCache.Clear;
  // UTF-8 must be passed explicitly. TStrings.LoadFromFile without an encoding
  // falls back to DefaultEncoding - TEncoding.Default, i.e. ANSI/CP1252 on
  // Windows - whenever the file has no BOM, and most markdown is BOM-less
  // UTF-8. That splits every multi-byte character into its raw bytes: an en
  // dash (U+2013 = E2 80 93) renders as "a EUR "". Passing UTF8 still honours a
  // BOM when there is one (GetBufferEncoding overrides the argument), so this
  // reads UTF-8, UTF-8-with-BOM and UTF-16 correctly.
  FMarkdown.LoadFromFile(AFileName, TEncoding.UTF8);
end;

procedure TRhoMarkdownViewer.SetBasePath(const AValue: string);
begin
  if FBasePath = AValue then
    Exit;
  FBasePath := AValue;
  FImageCache.Clear;   // cached failures were relative to the old base
  InvalidateLayout;
end;

function TRhoMarkdownViewer.ResolveImagePath(const AUrl: string): string;
begin
  Result := Trim(AUrl);
  if Result = '' then
    Exit;
  // Remote URLs are not fetched - that would make layout do network I/O.
  if Result.StartsWith('http://', True) or Result.StartsWith('https://', True) then
    Exit('');
  // A root-relative path (`/Images/x.png`, as GitHub renders in a README) is
  // resolved against BasePath rather than the drive root: strip the leading
  // slash so it combines with the document folder, matching GitHub's behaviour.
  while (Length(Result) > 0) and CharInSet(Result[1], ['/', '\']) do
    Result := Copy(Result, 2, MaxInt);
  // A malformed destination must never take down the host. TPath.Combine and
  // GetFullPath raise on invalid path characters, and a markdown document is
  // untrusted input - treat anything unusable as "no image" so it falls back to
  // alt text like any other broken path.
  try
    if TPath.IsRelativePath(Result) and (FBasePath <> '') then
      Result := TPath.Combine(FBasePath, Result);
    Result := TPath.GetFullPath(Result);
  except
    Result := '';
  end;
end;

function TRhoMarkdownViewer.ImageFor(const AUrl: string): ISkImage;
var
  Path: string;
begin
  Path := ResolveImagePath(AUrl);
  if Path = '' then
    Exit(nil);

  // A remembered nil means "we already tried and it failed" - do not retry on
  // every re-layout.
  if FImageCache.TryGetValue(Path, Result) then
    Exit;

  Result := nil;
  if TFile.Exists(Path) then
    try
      Result := TSkImage.MakeFromEncodedFile(Path);
    except
      // A corrupt or unsupported file must not take down a whole render;
      // it falls back to alt text like a missing one.
      Result := nil;
    end;
  FImageCache.Add(Path, Result);
end;

procedure TRhoMarkdownViewer.Reparse;
begin
  FReferences.Clear;
  TMarkDownBlockParser.ExtractLinkReferences(FMarkdown, FReferences);
  FreeAndNil(FBlocks);
  FBlocks := TMarkDownBlockParser.ParseBlocks(FMarkdown);
  InvalidateLayout;
end;

function TRhoMarkdownViewer.InlineTokensFor(ABlock: TMarkDownBlock)
  : TMarkDownInlineList;
begin
  // Parsed once per block and cached on it. Blocks are rebuilt on every
  // reparse, so the cache invalidates naturally.
  if ABlock.InlineTokens = nil then
    ABlock.InlineTokens := TMarkDownBlockParser.ParseInline(ABlock.Text,
      FReferences, ABlock.SourceMap);
  Result := ABlock.InlineTokens;
end;

{ ---- appearance ----

  Every one of these is a live setter. A plain field write would silently do
  nothing, which was a real bug in RhoEditor - keep them setters. Colours other
  than the background need a full re-layout, because a colour is baked into the
  paragraph's text style when the paragraph is built.
}

procedure TRhoMarkdownViewer.SetBackgroundColor(const AValue: TAlphaColor);
begin
  if FBackgroundColor = AValue then
    Exit;
  FBackgroundColor := AValue;
  RedrawContent;   // painted directly, not baked into a paragraph
end;

procedure TRhoMarkdownViewer.SetTextColor(const AValue: TAlphaColor);
begin
  if FTextColor = AValue then
    Exit;
  FTextColor := AValue;
  InvalidateLayout;
end;

procedure TRhoMarkdownViewer.SetLinkColor(const AValue: TAlphaColor);
begin
  if FLinkColor = AValue then
    Exit;
  FLinkColor := AValue;
  InvalidateLayout;
end;

procedure TRhoMarkdownViewer.SetCodeBackgroundColor(const AValue: TAlphaColor);
begin
  if FCodeBackgroundColor = AValue then
    Exit;
  FCodeBackgroundColor := AValue;
  InvalidateLayout;   // code spans carry it as a text-style background
end;

procedure TRhoMarkdownViewer.SetQuoteBarColor(const AValue: TAlphaColor);
begin
  if FQuoteBarColor = AValue then
    Exit;
  FQuoteBarColor := AValue;
  RedrawContent;   // decoration only
end;

procedure TRhoMarkdownViewer.SetRuleColor(const AValue: TAlphaColor);
begin
  if FRuleColor = AValue then
    Exit;
  FRuleColor := AValue;
  RedrawContent;   // decoration only
end;

procedure TRhoMarkdownViewer.SetHeadingRuleColor(const AValue: TAlphaColor);
begin
  if FHeadingRuleColor = AValue then
    Exit;
  FHeadingRuleColor := AValue;
  RedrawContent;   // decoration only
end;

procedure TRhoMarkdownViewer.SetHighlightColor(const AValue: TAlphaColor);
begin
  if FHighlightColor = AValue then
    Exit;
  FHighlightColor := AValue;
  InvalidateLayout;
end;

procedure TRhoMarkdownViewer.SetFontFamily(const AValue: string);
begin
  if FFontFamily = AValue then
    Exit;
  FFontFamily := AValue;
  InvalidateLayout;
end;

procedure TRhoMarkdownViewer.SetCodeFontFamily(const AValue: string);
begin
  if FCodeFontFamily = AValue then
    Exit;
  FCodeFontFamily := AValue;
  InvalidateLayout;
end;

procedure TRhoMarkdownViewer.SetFontSize(const AValue: Single);
begin
  if SameValue(FFontSize, AValue) or (AValue <= 0) then
    Exit;
  FFontSize := AValue;
  InvalidateLayout;
end;

procedure TRhoMarkdownViewer.SetContentPadding(const AValue: Single);
begin
  if SameValue(FContentPadding, AValue) or (AValue < 0) then
    Exit;
  FContentPadding := AValue;
  InvalidateLayout;
end;

procedure TRhoMarkdownViewer.SetImageAlign(const AValue: TRhoImageAlign);
begin
  if FImageAlign = AValue then
    Exit;
  FImageAlign := AValue;
  // Placement is baked into the display list (a block image's ImageRect, an
  // inline one's paragraph alignment), so this is a re-layout, not a repaint.
  InvalidateLayout;
end;

function TRhoMarkdownViewer.ResolveImageAlign(
  const AOverride: TMarkDownAlign): TRhoImageAlign;
begin
  case AOverride of
    maLeft:   Result := riaLeft;
    maCenter: Result := riaCenter;
    maRight:  Result := riaRight;
  else
    // maDefault: nothing was specified on the image itself, so the
    // document-wide property decides.
    Result := FImageAlign;
  end;
end;

function TRhoMarkdownViewer.ImageOffsetFor(const AAlign: TRhoImageAlign;
  const AImageWidth, AContentWidth: Single): Single;
begin
  case AAlign of
    riaCenter: Result := Max(0, (AContentWidth - AImageWidth) / 2);
    riaRight:  Result := Max(0, AContentWidth - AImageWidth);
  else
    Result := 0;
  end;
end;

// An inline image is placed by aligning the whole paragraph, which is only
// meaningful when the image IS the paragraph -- centring a line of prose because
// it happens to contain an icon would be wrong. So this reports True only for a
// block whose sole content is one image, plus whitespace.
function TRhoMarkdownViewer.TryLoneImageAlign(ATokens: TMarkDownInlineList;
  out AAlign: TRhoImageAlign): Boolean;
var
  I, Images: Integer;
  Found: TMarkDownInlineToken;
begin
  Result := False;
  AAlign := riaLeft;
  if (ATokens = nil) or (ATokens.Count = 0) then
    Exit;

  Images := 0;
  for I := 0 to ATokens.Count - 1 do
    if ATokens[I].IsImage then
    begin
      Inc(Images);
      if Images > 1 then
        Exit;
      Found := ATokens[I];
    end
    else if ATokens[I].LineBreak or (Trim(ATokens[I].Text) <> '') then
      Exit;

  if Images <> 1 then
    Exit;
  AAlign := ResolveImageAlign(Found.ImgAlign);
  Result := True;
end;

{ ---- text styles ---- }

function TRhoMarkdownViewer.BodyFamilies: TArray<string>;
begin
  Result := [FFontFamily, EmojiFontFamily, SymbolFontFamily];
end;

function TRhoMarkdownViewer.CodeFamilies: TArray<string>;
begin
  Result := [FCodeFontFamily, EmojiFontFamily, SymbolFontFamily];
end;

function TRhoMarkdownViewer.BaseTextStyle(const ASize: Single;
  const ABold, AItalic: Boolean): ISkTextStyle;
begin
  Result := TSkTextStyle.Create;
  Result.Color := FTextColor;
  Result.FontFamilies := BodyFamilies;
  Result.FontSize := ASize;
  if ABold and AItalic then
    Result.FontStyle := TSkFontStyle.BoldItalic
  else if ABold then
    Result.FontStyle := TSkFontStyle.Bold
  else if AItalic then
    Result.FontStyle := TSkFontStyle.Italic
  else
    Result.FontStyle := TSkFontStyle.Normal;
end;

function TRhoMarkdownViewer.StyleForToken(const AToken: TMarkDownInlineToken;
  const ABaseSize: Single; const ABaseBold, ABaseItalic: Boolean): ISkTextStyle;
var
  Bold, Italic: Boolean;
  Size: Single;
  Decorations: TSkTextDecorations;
  BackPaint: ISkPaint;
begin
  // A token's emphasis is combinable and nests, so it ADDS to the block's base
  // style rather than replacing it: a bold run inside an already-bold heading
  // stays bold, and italic inside bold gives bold-italic.
  Bold := ABaseBold or (fsBold in AToken.Style);
  Italic := ABaseItalic or (fsItalic in AToken.Style);

  Size := ABaseSize;
  if AToken.IsCode then
    Size := Size * CodeSpanScale;
  // KNOWN GAP: super/subscript are only shrunk, not raised or lowered, so
  // ^2^ and ~2~ currently look identical. ISkTextStyle exposes no baseline
  // shift; doing it properly means laying the run out separately and splicing
  // it in with AddPlaceholder, which carries its own baseline offset.
  if AToken.IsSuperscript or AToken.IsSubscript then
    Size := Size * SuperSubScale;

  Result := BaseTextStyle(Size, Bold, Italic);

  if AToken.IsCode then
    Result.FontFamilies := CodeFamilies;

  Decorations := [];
  if fsStrikeOut in AToken.Style then
    Include(Decorations, TSkTextDecoration.LineThrough);
  if fsUnderline in AToken.Style then
    Include(Decorations, TSkTextDecoration.Underline);

  if AToken.Url <> '' then
  begin
    Result.Color := FLinkColor;
    Include(Decorations, TSkTextDecoration.Underline);
    Result.DecorationColor := FLinkColor;
  end;

  if Decorations <> [] then
    Result.Decorations := Decorations;

  // Code spans and ==highlight== get a background behind the glyphs. Skia takes
  // this as a paint, not a colour.
  if AToken.IsCode or AToken.IsHighlighted then
  begin
    BackPaint := TSkPaint.Create;
    if AToken.IsHighlighted then
      BackPaint.Color := FHighlightColor
    else
      BackPaint.Color := FCodeBackgroundColor;
    Result.SetBackgroundColor(BackPaint);
  end;
end;

function TRhoMarkdownViewer.SyntaxColorFor(AKind: TSourceTokenKind): TAlphaColor;
begin
  Result := FSyntaxColors.ColorFor(AKind);
  // Null means the host never set this one, so it follows the body text and
  // therefore the theme.
  if Result = TAlphaColors.Null then
    Result := FTextColor;
end;

procedure TRhoMarkdownViewer.SetSyntaxColors(AValue: TRhoSyntaxColors);
begin
  FSyntaxColors.Assign(AValue);
end;

procedure TRhoMarkdownViewer.SyntaxColorsChanged(Sender: TObject);
begin
  // Colours are baked into paragraphs when they are built, so a colour change
  // is a re-layout, not just a repaint.
  InvalidateLayout;
end;

procedure TRhoMarkdownViewer.ApplyTheme(ATheme: TRhoTheme);
begin
  if ATheme = rtDark then
  begin
    FBackgroundColor := $FF1E1E1E;
    FTextColor := $FFD4D4D4;
    FLinkColor := $FF4EA1F7;
    FCodeBackgroundColor := $FF252526;
    FQuoteBarColor := $FF4A4A4F;
    FRuleColor := $FF3E3E42;
    FHeadingRuleColor := FRuleColor;
    FHighlightColor := $FF6B5D1B;
    FSelectionColor := $70417FBF;
    // Distinct from FHighlightColor, or a search hit inside a ==mark== span
    // would be invisible.
    FSearchHighlightColor := $80C77F00;
    FSearchCurrentColor := $FFC77F00;
  end
  else
  begin
    FBackgroundColor := TAlphaColors.White;
    FTextColor := TAlphaColors.Black;
    FLinkColor := $FF0366D6;
    FCodeBackgroundColor := $FFF4F4F4;
    FQuoteBarColor := $FFD0D7DE;
    FRuleColor := $FFD0D7DE;
    FHeadingRuleColor := FRuleColor;
    FHighlightColor := $FFFFF3A3;
    FSelectionColor := $60318CE7;
    FSearchHighlightColor := $80FFB300;
    FSearchCurrentColor := $FFFF9800;
  end;
  // Retunes the code palette too, so one call themes the whole control.
  FSyntaxColors.ApplyTheme(ATheme);   // fires OnChange -> InvalidateLayout
end;

{ ---- paragraph building ---- }

function TRhoMarkdownViewer.BuildTokens(ATokens: TMarkDownInlineList;
  const AFallbackText: string; const AWidth, ASize: Single;
  const ABold, AItalic: Boolean; const AAlign: TSkTextAlign;
  out ASpans: TArray<TRhoLinkSpan>; out APlainText: string;
  out ACharSource: TArray<Integer>;
  out APlaceholders: TArray<TRhoPlaceholder>): ISkParagraph;
var
  ParaStyle: ISkParagraphStyle;
  Builder: ISkParagraphBuilder;
  Plain: TStringBuilder;
  I, J, K, Pos, SpanCount: Integer;
  Emitted: string;
  Img: ISkImage;
  ImgW, ImgH, Shift: Single;
  RunStyle: ISkTextStyle;
  RunPara: ISkParagraph;
  Ph: TRhoPlaceholder;

  // Records what a token contributed: the rendered text, and where each of its
  // characters came from in the markdown source (-1 when unknown).
  //
  // AToBuilder is False only for a placeholder: AddPlaceholder already puts a
  // position into the paragraph's text, so adding one ourselves would both
  // draw a stray object-replacement glyph and double-count the offset. We
  // still have to advance our own bookkeeping to stay aligned with Skia.
  procedure Emit(const AText: string; const AMap: TArray<Integer>;
    const AToBuilder: Boolean = True);
  var
    K: Integer;
  begin
    if AToBuilder then
      Builder.AddText(AText);
    Plain.Append(AText);
    if Length(ACharSource) < Pos + Length(AText) then
      SetLength(ACharSource, Max(64, (Pos + Length(AText)) * 2));
    for K := 0 to Length(AText) - 1 do
      if K < Length(AMap) then
        ACharSource[Pos + K] := AMap[K]
      else
        ACharSource[Pos + K] := -1;
    Inc(Pos, Length(AText));
  end;

begin
  ParaStyle := TSkParagraphStyle.Create;
  ParaStyle.TextStyle := BaseTextStyle(ASize, ABold, AItalic);
  ParaStyle.TextAlign := AAlign;
  Builder := TSkParagraphBuilder.Create(ParaStyle);

  SetLength(ASpans, 0);
  SetLength(ACharSource, 0);
  SetLength(APlaceholders, 0);
  SpanCount := 0;
  Pos := 0;   // running offset in UTF-16 units, matching Skia's range indices

  Plain := TStringBuilder.Create;
  try
    if (ATokens = nil) or (ATokens.Count = 0) then
      // No inline structure (or empty): fall back to the raw text so content
      // never silently disappears.
      Emit(AFallbackText, nil)
    else
      for I := 0 to ATokens.Count - 1 do
      begin
        if ATokens[I].IsImage then
        begin
          Img := ImageFor(ATokens[I].Url);
          if Img <> nil then
          begin
            // A placeholder occupies exactly one position in the paragraph text
            // (U+FFFC), so Emit one character to keep offsets aligned for links
            // and selection.
            ImgW := Img.Width;
            ImgH := Img.Height;
            if ATokens[I].ImgWidth > 0 then
            begin
              // An HTML <img> gave an explicit width: honour it (and upscale if
              // asked), deriving height from the aspect ratio unless one was
              // given too. A percentage is of the content width.
              if ATokens[I].ImgWidthPct then
                ImgW := ATokens[I].ImgWidth * AWidth
              else
                ImgW := ATokens[I].ImgWidth;
              if ATokens[I].ImgHeight > 0 then
              begin
                if ATokens[I].ImgHeightPct then
                  ImgH := ATokens[I].ImgHeight * AWidth
                else
                  ImgH := ATokens[I].ImgHeight;
              end
              else if Img.Width > 0 then
                ImgH := Img.Height * (ImgW / Img.Width);
              // Still never overflow the content width, keeping aspect.
              if ImgW > AWidth then
              begin
                ImgH := ImgH * (AWidth / ImgW);
                ImgW := AWidth;
              end;
            end
            else if ImgW > AWidth then
            begin
              // Default: scale down to fit the line width, never upscaling.
              ImgH := ImgH * (AWidth / ImgW);
              ImgW := AWidth;
            end;
            Builder.AddPlaceholder(TSkPlaceholderStyle.Create(ImgW, ImgH,
              TSkPlaceholderAlignment.Baseline, TSkTextBaseline.Alphabetic, 0));
            Ph := Default(TRhoPlaceholder);
            Ph.Image := Img;
            APlaceholders := APlaceholders + [Ph];
            Emit(#$FFFC, nil, False);   // bookkeeping only - see Emit
            Continue;
          end;
          // Could not load it: fall back to the alt text, italicised so it
          // reads as a substitute rather than as body copy.
          if ATokens[I].Text <> '' then
          begin
            Builder.PushStyle(BaseTextStyle(ASize, ABold, True));
            Emit(ATokens[I].Text, nil);
            Builder.Pop;
          end;
          Continue;
        end;

        if ATokens[I].LineBreak then
        begin
          // A hard break carries no text of its own, but it does occupy
          // positions in the paragraph - so it must still be emitted.
          Emit(sLineBreak, nil);
          Continue;
        end;
        if ATokens[I].Text = '' then
          Continue;

        // Super/subscript: ISkTextStyle has no baseline shift, so the run is
        // laid out separately and spliced in as a placeholder, whose
        // BaselineOffset does the raising and lowering.
        //
        // ONE PLACEHOLDER PER CHARACTER. A placeholder occupies exactly one
        // position in the paragraph, so emitting one per character keeps
        // PlainText the same length as Skia's text - offsets stay aligned for
        // links and selection - while the real characters (not U+FFFC) land in
        // the copy buffer. Emitting a single placeholder for the whole run
        // would desynchronise the two for any run longer than one character,
        // which is exactly the case chemistry needs (C~6~H~12~O~6~).
        //
        // The cost is no kerning between the characters of a run, which is
        // negligible for the digits these almost always are. Surrogate pairs
        // are excluded: one would span two positions and break the alignment
        // this relies on, so such a run falls through to the unshifted path.
        if (ATokens[I].IsSuperscript or ATokens[I].IsSubscript) and
           not HasSurrogate(ATokens[I].Text) then
        begin
          RunStyle := StyleForToken(ATokens[I], ASize, ABold, AItalic);
          Shift := ASize * SuperSubShift;
          if ATokens[I].IsSubscript then
            Shift := -Shift;
          for K := 1 to Length(ATokens[I].Text) do
          begin
            RunPara := BuildRun(ATokens[I].Text[K], RunStyle);
            Builder.AddPlaceholder(TSkPlaceholderStyle.Create(
              RunPara.LongestLine, RunPara.Height,
              TSkPlaceholderAlignment.Baseline, TSkTextBaseline.Alphabetic,
              RunPara.AlphabeticBaseline + Shift));
            Ph := Default(TRhoPlaceholder);
            Ph.Para := RunPara;
            APlaceholders := APlaceholders + [Ph];
          end;
          Emit(ATokens[I].Text, ATokens[I].SourceMap, False);
          Continue;
        end;

        Emitted := ATokens[I].Text;
        Builder.PushStyle(StyleForToken(ATokens[I], ASize, ABold, AItalic));
        J := Pos;
        Emit(Emitted, ATokens[I].SourceMap);
        Builder.Pop;

        if ATokens[I].Url <> '' then
        begin
          if SpanCount = Length(ASpans) then
            SetLength(ASpans, Max(4, SpanCount * 2));
          ASpans[SpanCount].StartChar := J;
          ASpans[SpanCount].EndChar := Pos;
          ASpans[SpanCount].Url := ATokens[I].Url;
          Inc(SpanCount);
        end;
      end;

    APlainText := Plain.ToString;
  finally
    Plain.Free;
  end;

  SetLength(ASpans, SpanCount);
  SetLength(ACharSource, Pos);
  Result := Builder.Build;
  Result.Layout(AWidth);
end;

// Turns link spans into on-screen rects, once, at layout time. Doing this here
// rather than per mouse-move keeps hit-testing to pure rect arithmetic and
// gives us the geometry a hover highlight would need later.
procedure TRhoMarkdownViewer.CollectLinkRects(const AParagraph: ISkParagraph;
  const ASpans: TArray<TRhoLinkSpan>; const AOriginX, AOriginY: Single;
  var ALinks: TArray<TRhoLinkHit>);
var
  I, J, Base: Integer;
  Boxes: TArray<TSkTextBox>;
begin
  if (AParagraph = nil) or (Length(ASpans) = 0) then
    Exit;

  Base := Length(ALinks);
  SetLength(ALinks, Base + Length(ASpans));
  for I := 0 to High(ASpans) do
  begin
    ALinks[Base + I].Url := ASpans[I].Url;
    Boxes := AParagraph.GetRectsForRange(ASpans[I].StartChar, ASpans[I].EndChar,
      TSkRectHeightStyle.Tight, TSkRectWidthStyle.Tight);
    SetLength(ALinks[Base + I].Rects, Length(Boxes));
    for J := 0 to High(Boxes) do
    begin
      ALinks[Base + I].Rects[J] := Boxes[J].Rect;
      ALinks[Base + I].Rects[J].Offset(AOriginX, AOriginY);
    end;
  end;
end;

function TRhoMarkdownViewer.BuildInline(ABlock: TMarkDownBlock;
  const AWidth, ASize: Single; const ABold, AItalic: Boolean;
  const AAlign: TMarkDownAlign;
  out ASpans: TArray<TRhoLinkSpan>; var ALayout: TRhoBlockLayout): ISkParagraph;
var
  Boxes: TArray<TSkTextBox>;
  I: Integer;
  Tokens: TMarkDownInlineList;
  ImgAlign: TRhoImageAlign;
  Align: TSkTextAlign;
begin
  Tokens := InlineTokensFor(ABlock);

  // An enclosing <p>/<div align=..> wins: it was written around this block
  // deliberately, and it aligns text as well as images. Failing that, a
  // paragraph that is nothing but one image is placed by aligning the paragraph
  // itself; Skia then positions the placeholder, and paint reads the rect back
  // as usual.
  Align := TSkTextAlign.Left;
  case AAlign of
    maCenter: Align := TSkTextAlign.Center;
    maRight:  Align := TSkTextAlign.Right;
    maLeft:   Align := TSkTextAlign.Left;
  else
    if TryLoneImageAlign(Tokens, ImgAlign) then
      case ImgAlign of
        riaCenter: Align := TSkTextAlign.Center;
        riaRight:  Align := TSkTextAlign.Right;
      end;
  end;

  Result := BuildTokens(Tokens, ABlock.Text, AWidth, ASize,
    ABold, AItalic, Align, ASpans, ALayout.PlainText,
    ALayout.CharSource, ALayout.Placeholders);

  // Skia decides where the placeholders ended up; read the rects back in the
  // order they were added, which matches ALayout.Placeholders.
  if Length(ALayout.Placeholders) > 0 then
  begin
    Boxes := Result.GetRectsForPlaceholders;
    for I := 0 to High(ALayout.Placeholders) do
      if I <= High(Boxes) then
        ALayout.Placeholders[I].Rect := Boxes[I].Rect
      else
        ALayout.Placeholders[I].Rect := TRectF.Empty;
  end;
end;

function TRhoMarkdownViewer.BuildCellText(const AText: string;
  const AWidth: Single; const ABold: Boolean; const AAlign: TSkTextAlign;
  out ASpans: TArray<TRhoLinkSpan>; out APlain: string): ISkParagraph;
var
  Tokens: TMarkDownInlineList;
  Map: TArray<Integer>;
  Phs: TArray<TRhoPlaceholder>;
begin
  // Table cells are not blocks, so their tokens are not cached anywhere - we
  // own this list and must free it. The per-character source map is discarded:
  // cell tokens are parsed without one, so a table's characters have no source
  // offsets and markdown copy relies on the neighbouring blocks instead.
  Tokens := TMarkDownBlockParser.ParseInline(AText, FReferences);
  try
    Result := BuildTokens(Tokens, AText, AWidth, FFontSize, ABold, False,
      AAlign, ASpans, APlain, Map, Phs);
  finally
    Tokens.Free;
  end;
end;

function TRhoMarkdownViewer.BuildCode(ABlock: TMarkDownBlock;
  const AWidth: Single): ISkParagraph;
var
  ParaStyle: ISkParagraphStyle;
  Builder: ISkParagraphBuilder;
  BaseStyle, RunStyle: ISkTextStyle;
  Tokens: TArray<TSourceToken>;
  I: Integer;
  Size: Single;
begin
  Size := FFontSize * CodeSpanScale;

  BaseStyle := TSkTextStyle.Create;
  BaseStyle.Color := FTextColor;
  BaseStyle.FontFamilies := CodeFamilies;
  BaseStyle.FontSize := Size;

  ParaStyle := TSkParagraphStyle.Create;
  ParaStyle.TextStyle := BaseStyle;
  Builder := TSkParagraphBuilder.Create(ParaStyle);

  // Cached on the block and computed once - never re-tokenize per paint.
  // Returns nil when the fence had no recognised language, which is the plain
  // unhighlighted path.
  Tokens := ABlock.HighlightTokens;

  if Length(Tokens) = 0 then
    Builder.AddText(ABlock.Text)
  else
    // Every lexer tiles its input exactly (contiguous, gap-free, non-empty
    // tokens whose concatenation reproduces the source), so emitting them in
    // order reproduces the block text. TestTokenStreamInvariants* enforces it.
    for I := 0 to High(Tokens) do
    begin
      RunStyle := TSkTextStyle.Create;
      RunStyle.Color := SyntaxColorFor(Tokens[I].Kind);
      RunStyle.FontFamilies := CodeFamilies;
      RunStyle.FontSize := Size;
      Builder.PushStyle(RunStyle);
      Builder.AddText(Tokens[I].Text);
      Builder.Pop;
    end;

  Result := Builder.Build;
  Result.Layout(AWidth);
end;

// One styled run laid out on its own, for splicing into a placeholder slot.
function TRhoMarkdownViewer.BuildRun(const AText: string;
  const AStyle: ISkTextStyle): ISkParagraph;
var
  ParaStyle: ISkParagraphStyle;
  Builder: ISkParagraphBuilder;
begin
  ParaStyle := TSkParagraphStyle.Create;
  ParaStyle.TextStyle := AStyle;
  Builder := TSkParagraphBuilder.Create(ParaStyle);
  Builder.AddText(AText);
  Result := Builder.Build;
  Result.Layout(10000);   // never wraps
end;

function TRhoMarkdownViewer.BuildMarker(const AText: string;
  const ASize: Single): ISkParagraph;
var
  ParaStyle: ISkParagraphStyle;
  Builder: ISkParagraphBuilder;
begin
  ParaStyle := TSkParagraphStyle.Create;
  ParaStyle.TextStyle := BaseTextStyle(ASize, False, False);
  Builder := TSkParagraphBuilder.Create(ParaStyle);
  Builder.AddText(AText);
  Result := Builder.Build;
  // Markers never wrap; give them room and use LongestLine to place them.
  Result.Layout(10000);
end;

function TRhoMarkdownViewer.HeadingSize(ALevel: Integer): Single;
begin
  Result := FFontSize * HeadingScale[EnsureRange(ALevel, 1, 6)];
end;

{ ---- tables ---- }

function AlignmentFromSpec(const ASpec: string): TSkTextAlign;
var
  S: string;
  LeadingColon, TrailingColon: Boolean;
begin
  // The markdown alignment row: :--- left, ---: right, :---: centre.
  S := Trim(ASpec);
  LeadingColon := (S <> '') and (S[1] = ':');
  TrailingColon := (S <> '') and (S[Length(S)] = ':');
  if LeadingColon and TrailingColon then
    Result := TSkTextAlign.Center
  else if TrailingColon then
    Result := TSkTextAlign.Right
  else
    Result := TSkTextAlign.Left;
end;

procedure TRhoMarkdownViewer.LayoutTable(ABlock: TMarkDownBlock;
  const AContentLeft, AContentWidth: Single; var ALayout: TRhoBlockLayout);
var
  Lines, Cells: TStringList;
  Aligns: TArray<TSkTextAlign>;
  RowTexts: TArray<TArray<string>>;
  ColWidths: TArray<Single>;
  ColCount, R, C, I: Integer;
  Natural, Total, Avail, Scale, X, Y, RowHeight: Single;
  Probe: ISkParagraph;
  IsHeader: Boolean;
  Spans: TArray<TRhoLinkSpan>;
  CellPlain: string;
  Flat: TStringBuilder;
begin
  Lines := TStringList.Create;
  Cells := TStringList.Create;
  Flat := TStringBuilder.Create;
  try
    Lines.Text := ABlock.Text;

    // Collect the data rows, skipping the alignment row (index 1) but reading
    // the alignments out of it first.
    ColCount := 0;
    SetLength(RowTexts, 0);
    for I := 0 to Lines.Count - 1 do
    begin
      if Trim(Lines[I]) = '' then
        Continue;
      TMarkDownBlockParser.SplitTableRow(Lines[I], Cells);

      if (I = 1) and TMarkDownBlockParser.IsPipeTableRow(Lines[I]) and
         (Pos('-', Lines[I]) > 0) then
      begin
        SetLength(Aligns, Cells.Count);
        for C := 0 to Cells.Count - 1 do
          Aligns[C] := AlignmentFromSpec(Cells[C]);
        Continue;
      end;

      SetLength(RowTexts, Length(RowTexts) + 1);
      SetLength(RowTexts[High(RowTexts)], Cells.Count);
      for C := 0 to Cells.Count - 1 do
        RowTexts[High(RowTexts)][C] := Cells[C];
      ColCount := Max(ColCount, Cells.Count);
    end;

    if (ColCount = 0) or (Length(RowTexts) = 0) then
    begin
      ALayout.Height := 0;
      Exit;
    end;

    // Alignments may be missing or short; default the rest to left.
    if Length(Aligns) < ColCount then
    begin
      I := Length(Aligns);
      SetLength(Aligns, ColCount);
      for C := I to ColCount - 1 do
        Aligns[C] := TSkTextAlign.Left;
    end;

    // Pass 1: natural column widths. MaxIntrinsicWidth is the width the cell
    // would take with no wrapping, which is what we want before deciding
    // whether the table has to be squeezed.
    SetLength(ColWidths, ColCount);
    for R := 0 to High(RowTexts) do
      for C := 0 to High(RowTexts[R]) do
      begin
        Probe := BuildCellText(RowTexts[R][C], 100000, R = 0, TSkTextAlign.Left,
          Spans, CellPlain);
        // Round up and add a pixel of slack. Laying a cell out at exactly its
        // MaxIntrinsicWidth makes Skia's line breaker wrap the last word on
        // float rounding - "$100.00" comes out as "$100.0" over "0".
        Natural := Ceil(Probe.MaxIntrinsicWidth) + 1 + TableCellPadH * 2;
        if Natural > ColWidths[C] then
          ColWidths[C] := Natural;
      end;

    // Pass 2: if the natural widths overflow, scale them down proportionally
    // and let the cells wrap.
    Total := 0;
    for C := 0 to ColCount - 1 do
      Total := Total + ColWidths[C];
    Avail := Max(1, AContentWidth);
    if Total > Avail then
    begin
      Scale := Avail / Total;
      for C := 0 to ColCount - 1 do
        ColWidths[C] := Max(TableCellPadH * 2 + 1, ColWidths[C] * Scale);
    end;

    // Pass 3: lay each cell out at its final column width and stack the rows.
    SetLength(ALayout.Rows, Length(RowTexts));
    Y := 0;
    X := 0;
    for R := 0 to High(RowTexts) do
    begin
      IsHeader := R = 0;
      SetLength(ALayout.Rows[R], ColCount);
      RowHeight := 0;
      X := 0;
      for C := 0 to ColCount - 1 do
      begin
        if C <= High(RowTexts[R]) then
        begin
          ALayout.Rows[R][C].Paragraph := BuildCellText(RowTexts[R][C],
            Max(1, ColWidths[C] - TableCellPadH * 2), IsHeader, Aligns[C],
            Spans, CellPlain);
          // Cell paragraph origin, in the same space the block's link rects
          // use: absolute X, Y relative to the block top.
          CollectLinkRects(ALayout.Rows[R][C].Paragraph, Spans,
            AContentLeft + X + TableCellPadH, Y + TableCellPadV, ALayout.Links);
        end
        else
        begin
          ALayout.Rows[R][C].Paragraph := nil;   // ragged row: empty cell
          CellPlain := '';
        end;

        // Flatten into the block's selectable text: TAB between cells, newline
        // between rows. Tab-separated is what makes a copied table paste
        // straight into a spreadsheet - the VCL predecessor did the same.
        if C > 0 then
          Flat.Append(#9);
        ALayout.Rows[R][C].TextStart := Flat.Length;
        ALayout.Rows[R][C].TextLen := Length(CellPlain);
        Flat.Append(CellPlain);
        if C = ColCount - 1 then
          Flat.Append(sLineBreak);

        if ALayout.Rows[R][C].Paragraph <> nil then
          RowHeight := Max(RowHeight, ALayout.Rows[R][C].Paragraph.Height);
        ALayout.Rows[R][C].Rect := RectF(X, Y, X + ColWidths[C], Y);
        X := X + ColWidths[C];
      end;

      RowHeight := RowHeight + TableCellPadV * 2;
      // Now the row height is known, give every cell in it the same bottom.
      for C := 0 to ColCount - 1 do
        ALayout.Rows[R][C].Rect.Bottom := Y + RowHeight;
      Y := Y + RowHeight;
    end;

    ALayout.Height := Y;
    ALayout.BoxRight := AContentLeft + X;

    ALayout.PlainText := Flat.ToString;
    // Cell tokens are parsed without a source map, so no character in a table
    // maps back to the markdown. -1 throughout is honest: SourceOffsetAt then
    // scans out to the neighbouring blocks, so a selection spanning a table
    // plus surrounding text still yields correct verbatim markdown, while a
    // table-only selection falls back to the tab-separated plain text.
    SetLength(ALayout.CharSource, Length(ALayout.PlainText));
    for I := 0 to High(ALayout.CharSource) do
      ALayout.CharSource[I] := -1;
  finally
    Flat.Free;
    Cells.Free;
    Lines.Free;
  end;
end;

// Chrome and text are separate passes because the selection and search
// highlights go BETWEEN them. Painting a table in one pass put the cell text
// under the highlight, which an opaque current-match colour then hid.
procedure TRhoMarkdownViewer.PaintTableChrome(const ACanvas: ISkCanvas;
  const ALayout: TRhoBlockLayout; const AScreenTop: Single);
var
  Paint: ISkPaint;
  R, C: Integer;
  Cell: TRectF;
begin
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;

  for R := 0 to High(ALayout.Rows) do
    for C := 0 to High(ALayout.Rows[R]) do
    begin
      Cell := ALayout.Rows[R][C].Rect;
      Cell.Offset(ALayout.BoxLeft, AScreenTop);

      // Header row gets a tinted background.
      if R = 0 then
      begin
        Paint.Style := TSkPaintStyle.Fill;
        Paint.Color := FCodeBackgroundColor;
        ACanvas.DrawRect(Cell, Paint);
      end;

      Paint.Style := TSkPaintStyle.Stroke;
      Paint.StrokeWidth := 1;
      Paint.Color := FRuleColor;
      ACanvas.DrawRect(Cell, Paint);
    end;
end;

procedure TRhoMarkdownViewer.PaintTableText(const ACanvas: ISkCanvas;
  const ALayout: TRhoBlockLayout; const AScreenTop: Single);
var
  R, C: Integer;
  Cell: TRectF;
begin
  for R := 0 to High(ALayout.Rows) do
    for C := 0 to High(ALayout.Rows[R]) do
      if ALayout.Rows[R][C].Paragraph <> nil then
      begin
        Cell := ALayout.Rows[R][C].Rect;
        Cell.Offset(ALayout.BoxLeft, AScreenTop);
        ALayout.Rows[R][C].Paragraph.Paint(ACanvas,
          Cell.Left + TableCellPadH, Cell.Top + TableCellPadV);
      end;
end;

{ ---- front matter ---- }

// Splits YAML-ish front matter into key/value rows. Intentionally shallow: a
// top-level, unindented "key: value" starts a row; an indented or colon-less
// line continues the previous value; matching surrounding quotes are stripped.
// Enough for skill.md / Jekyll headers, not a YAML parser.
function ParseFrontMatterPairs(const AText: string): TArray<TPair<string, string>>;
var
  Lines: TStringList;
  I, ColonPos: Integer;
  Line, Key, Val: string;
  Pairs: TList<TPair<string, string>>;

  function Unquoted(const S: string): string;
  begin
    Result := Trim(S);
    if (Length(Result) >= 2) and
      (((Result[1] = '"') and (Result[Length(Result)] = '"')) or
       ((Result[1] = '''') and (Result[Length(Result)] = ''''))) then
      Result := Copy(Result, 2, Length(Result) - 2);
  end;

begin
  Pairs := TList<TPair<string, string>>.Create;
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      if Trim(Line) = '' then
        Continue;
      ColonPos := Pos(':', Line);
      // A new key: a colon, with a non-blank name, on an unindented line.
      if (ColonPos > 1) and (Line[1] <> ' ') and (Line[1] <> #9) then
      begin
        Key := Trim(Copy(Line, 1, ColonPos - 1));
        Val := Unquoted(Copy(Line, ColonPos + 1, MaxInt));
        Pairs.Add(TPair<string, string>.Create(Key, Val));
      end
      else if Pairs.Count > 0 then
      begin
        // Continuation of the previous value (indented, or a list item).
        Val := Pairs[Pairs.Count - 1].Value;
        if Val <> '' then
          Val := Val + ' ';
        Val := Val + Trim(Line);
        Pairs[Pairs.Count - 1] :=
          TPair<string, string>.Create(Pairs[Pairs.Count - 1].Key, Val);
      end
      else
        // A value with no key (rare); show it in the value column.
        Pairs.Add(TPair<string, string>.Create('', Unquoted(Line)));
    end;
    Result := Pairs.ToArray;
  finally
    Lines.Free;
    Pairs.Free;
  end;
end;

procedure TRhoMarkdownViewer.LayoutFrontMatter(ABlock: TMarkDownBlock;
  const AContentLeft, AContentWidth: Single; var ALayout: TRhoBlockLayout);
const
  ColGap = 12;
var
  Pairs: TArray<TPair<string, string>>;
  I: Integer;
  MaxKeyW, ValW, Y, RowH: Single;
  ParaStyle: ISkParagraphStyle;
  Builder: ISkParagraphBuilder;
  ValPara: ISkParagraph;
  Flat: TStringBuilder;
begin
  ALayout.BoxLeft := AContentLeft;
  ALayout.BoxRight := AContentLeft + AContentWidth;

  Pairs := ParseFrontMatterPairs(ABlock.Text);
  SetLength(ALayout.MetaRows, Length(Pairs));
  if Length(Pairs) = 0 then
  begin
    // Empty front matter: a slim panel rather than nothing, so it is visible.
    ALayout.Height := FFontSize + CodePadding * 2;
    ALayout.PlainText := '';
    Exit;
  end;

  // Key column: widest bold key, capped so a long key cannot crush the values.
  MaxKeyW := 0;
  for I := 0 to High(Pairs) do
  begin
    ALayout.MetaRows[I].KeyPara :=
      BuildRun(Pairs[I].Key, BaseTextStyle(FFontSize, True, False));
    MaxKeyW := Max(MaxKeyW, ALayout.MetaRows[I].KeyPara.LongestLine);
  end;
  // A pixel of slack: laying a key out at exactly its intrinsic width makes
  // Skia wrap the last glyph on float rounding (the same trap as table columns).
  MaxKeyW := Min(Ceil(MaxKeyW) + 1, (AContentWidth - CodePadding * 2) * 0.4);

  ALayout.MetaKeyLeft := CodePadding;
  ALayout.MetaValueLeft := CodePadding + MaxKeyW + ColGap;
  ValW := Max(1, AContentWidth - ALayout.MetaValueLeft - CodePadding);

  Flat := TStringBuilder.Create;
  try
    Y := CodePadding;
    for I := 0 to High(Pairs) do
    begin
      ParaStyle := TSkParagraphStyle.Create;
      ParaStyle.TextStyle := BaseTextStyle(FFontSize, False, False);
      Builder := TSkParagraphBuilder.Create(ParaStyle);
      Builder.AddText(Pairs[I].Value);
      ValPara := Builder.Build;
      ValPara.Layout(ValW);
      ALayout.MetaRows[I].ValuePara := ValPara;

      // A capped key may wrap; re-lay it at the column width so its height counts.
      ALayout.MetaRows[I].KeyPara.Layout(MaxKeyW);
      RowH := Max(ALayout.MetaRows[I].KeyPara.Height, ValPara.Height);
      ALayout.MetaRows[I].Top := Y;
      ALayout.MetaRows[I].Height := RowH;
      Y := Y + RowH + TableCellPadV;

      // Record each paragraph's slice of the flattened text as it is built,
      // so a selection or search hit can be mapped back to the row that draws
      // it. Flat.Length is the running offset.
      if Flat.Length > 0 then
        Flat.Append(sLineBreak);
      ALayout.MetaRows[I].KeyStart := Flat.Length;
      ALayout.MetaRows[I].KeyLen := Length(Pairs[I].Key);
      Flat.Append(Pairs[I].Key).Append(': ');
      ALayout.MetaRows[I].ValueStart := Flat.Length;
      ALayout.MetaRows[I].ValueLen := Length(Pairs[I].Value);
      Flat.Append(Pairs[I].Value);
    end;
    Y := Y - TableCellPadV;   // drop the gap after the last row
    ALayout.Height := Y + CodePadding;
    // Selectable/copyable as reconstructed "key: value" lines.
    ALayout.PlainText := Flat.ToString;
  finally
    Flat.Free;
  end;
end;

// Split for the same reason as the table: the highlight layer paints between
// the panel and the text.
procedure TRhoMarkdownViewer.PaintFrontMatterPanel(const ACanvas: ISkCanvas;
  const ALayout: TRhoBlockLayout; const AScreenTop: Single);
var
  Paint: ISkPaint;
  R: TRectF;
begin
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.Color := FCodeBackgroundColor;
  R := RectF(ALayout.BoxLeft, AScreenTop, ALayout.BoxRight,
    AScreenTop + ALayout.Height);
  ACanvas.DrawRoundRect(R, 4, 4, Paint);
end;

procedure TRhoMarkdownViewer.PaintFrontMatterText(const ACanvas: ISkCanvas;
  const ALayout: TRhoBlockLayout; const AScreenTop: Single);
var
  I: Integer;
begin
  for I := 0 to High(ALayout.MetaRows) do
  begin
    if ALayout.MetaRows[I].KeyPara <> nil then
      ALayout.MetaRows[I].KeyPara.Paint(ACanvas,
        ALayout.BoxLeft + ALayout.MetaKeyLeft,
        AScreenTop + ALayout.MetaRows[I].Top);
    if ALayout.MetaRows[I].ValuePara <> nil then
      ALayout.MetaRows[I].ValuePara.Paint(ACanvas,
        ALayout.BoxLeft + ALayout.MetaValueLeft,
        AScreenTop + ALayout.MetaRows[I].Top);
  end;
end;

{ ---- block layout ---- }

procedure TRhoMarkdownViewer.LayoutBlock(ABlock: TMarkDownBlock;
  const AContentLeft, AContentWidth: Single; var ALayout: TRhoBlockLayout;
  const AInQuote: Boolean; const AAlign: TMarkDownAlign);
var
  Indent, Avail, Size, Scale: Single;
  MarkerText: string;
  Spans: TArray<TRhoLinkSpan>;
begin
  ALayout := Default(TRhoBlockLayout);
  ALayout.Block := ABlock;
  ALayout.BoxLeft := AContentLeft;
  ALayout.BoxRight := AContentLeft + AContentWidth;
  ALayout.TextLeft := AContentLeft;

  case ABlock.Kind of
    bkRule:
      begin
        // No paragraph; PaintDecorations strokes the line.
        ALayout.Height := FFontSize * 1.2;
        Exit;
      end;

    bkCodeBlock:
      begin
        ALayout.TextLeft := AContentLeft + CodePadding;
        ALayout.Paragraph := BuildCode(ABlock,
          Max(1, AContentWidth - CodePadding * 2));
        ALayout.Height := ALayout.Paragraph.Height + CodePadding * 2;
        // Make code selectable. BuildCode renders exactly Block.Text - either
        // as one run, or as highlight tokens, which tile the input exactly -
        // so the block's own SourceMap lines up character for character.
        ALayout.PlainText := ABlock.Text;
        ALayout.CharSource := ABlock.SourceMap;
        Exit;
      end;

    bkQuote:
      begin
        ALayout.TextLeft := AContentLeft + QuoteTextIndent;
        ALayout.Paragraph := BuildInline(ABlock, Max(1, AContentWidth - QuoteTextIndent), FFontSize, False, True, AAlign, Spans, ALayout);
        ALayout.Height := ALayout.Paragraph.Height;
        CollectLinkRects(ALayout.Paragraph, Spans, ALayout.TextLeft, 0,
          ALayout.Links);
        Exit;
      end;

    bkListItem:
      begin
        Indent := Max(0, ABlock.IndentLevel) * ListIndentPerLevel;
        ALayout.BoxLeft := AContentLeft + Indent;
        ALayout.TextLeft := AContentLeft + Indent + ListTextIndent;
        Avail := Max(1, AContentWidth - Indent - ListTextIndent);
        ALayout.Paragraph := BuildInline(ABlock, Avail, FFontSize, False, False, AAlign, Spans, ALayout);
        ALayout.Height := ALayout.Paragraph.Height;
        CollectLinkRects(ALayout.Paragraph, Spans, ALayout.TextLeft, 0,
          ALayout.Links);

        // Nesting is carried into a copied list as indentation.
        ALayout.CopyPrefix := StringOfChar(' ', Max(0, ABlock.IndentLevel) * 2);

        // A task item draws a checkbox instead of a bullet.
        if not ABlock.IsTask then
        begin
          if ABlock.Ordered then
            MarkerText := IntToStr(ABlock.Number) + '.'
          else
            MarkerText := #$25CF;   // bullet
          ALayout.CopyPrefix := ALayout.CopyPrefix + MarkerText + ' ';
          ALayout.Marker := BuildMarker(MarkerText, FFontSize);
          if ABlock.Ordered then
            // Right-align the number against the text column, keeping a gap.
            // Centring it worked only while the marker was narrower than the
            // gutter: at two digits '10.' filled the gutter and butted straight
            // against the text. Right-aligning also lines the periods up, and
            // lets a wide number (100.) spill left the way a browser does.
            ALayout.MarkerLeft := Max(0,
              ALayout.TextLeft - ListMarkerGap - ALayout.Marker.LongestLine)
          else
            // A bullet is a fixed narrow glyph; centring it in the gutter is
            // right and matches the rendering already verified.
            ALayout.MarkerLeft := ALayout.BoxLeft +
              Max(0, (ListTextIndent - ALayout.Marker.LongestLine) / 2);
        end
        else
        begin
          // The checkbox is drawn, not typeset, so give copy a text stand-in.
          if ABlock.TaskChecked then
            ALayout.CopyPrefix := ALayout.CopyPrefix + '[x] '
          else
            ALayout.CopyPrefix := ALayout.CopyPrefix + '[ ] ';
          // Right-aligned against the text column like an ordered marker, so
          // the clearance is a fixed quantity rather than whatever centring
          // happens to leave over.
          ALayout.MarkerLeft := Max(ALayout.BoxLeft,
            ALayout.TextLeft - TaskBoxGap - CheckBoxSize);
        end;
        Exit;
      end;

    bkHeading:
      begin
        Size := HeadingSize(ABlock.Level);
        ALayout.Paragraph := BuildInline(ABlock, AContentWidth, Size, True, False, AAlign, Spans, ALayout);
        ALayout.Height := ALayout.Paragraph.Height;
        CollectLinkRects(ALayout.Paragraph, Spans, ALayout.TextLeft, 0,
          ALayout.Links);
        // H1 and H2 carry an underline rule, so they need room for it.
        if ABlock.Level <= 2 then
          ALayout.Height := ALayout.Height + HeadingRuleGap + RuleThickness;
        Exit;
      end;

    bkTable:
      begin
        LayoutTable(ABlock, AContentLeft, AContentWidth, ALayout);
        // A table that parsed to nothing usable falls back to its raw text
        // rather than vanishing.
        if Length(ALayout.Rows) = 0 then
        begin
          ALayout.Paragraph := BuildInline(ABlock, AContentWidth, FFontSize, False, False, AAlign, Spans, ALayout);
          ALayout.Height := ALayout.Paragraph.Height;
          CollectLinkRects(ALayout.Paragraph, Spans, ALayout.TextLeft, 0,
            ALayout.Links);
        end;
        Exit;
      end;

    bkFrontMatter:
      begin
        LayoutFrontMatter(ABlock, AContentLeft, AContentWidth, ALayout);
        Exit;
      end;

    bkImage:
      begin
        ALayout.Image := ImageFor(ABlock.Url);
        if ALayout.Image = nil then
        begin
          // Missing, unreadable, or remote: fall back to the alt text so the
          // reader sees something rather than a blank gap.
          ALayout.Paragraph := BuildInline(ABlock, AContentWidth, FFontSize, False, True, AAlign, Spans, ALayout);
          ALayout.Height := ALayout.Paragraph.Height;
          Exit;
        end;

        // Scale to fit the content width, but never upscale past natural size.
        Scale := 1;
        if ALayout.Image.Width > AContentWidth then
          Scale := AContentWidth / ALayout.Image.Width;
        ALayout.ImageRect := RectF(0, 0,
          ALayout.Image.Width * Scale, ALayout.Image.Height * Scale);
        // Markdown gives a block image nowhere to carry an attribute, so its
        // placement comes from an enclosing <p>/<div align=..> if there is one,
        // and otherwise from the ImageAlign property (that is what maDefault
        // resolves to). Paint offsets ImageRect by BoxLeft, so shifting it here
        // is the whole change.
        ALayout.ImageRect.Offset(
          ImageOffsetFor(ResolveImageAlign(AAlign),
            ALayout.ImageRect.Width, AContentWidth), 0);
        ALayout.Height := ALayout.ImageRect.Height;
        Exit;
      end;
  end;

  // bkParagraph and anything else. Paragraphs inside a quote render italic, the
  // way the quote's single text block did before quotes became containers.
  ALayout.Paragraph := BuildInline(ABlock, AContentWidth, FFontSize, False, AInQuote, AAlign, Spans, ALayout);
  ALayout.Height := ALayout.Paragraph.Height;
  CollectLinkRects(ALayout.Paragraph, Spans, ALayout.TextLeft, 0, ALayout.Links);
end;

function TRhoMarkdownViewer.CountLeaves(ABlocks: TMarkDownBlockList): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to ABlocks.Count - 1 do
    if ABlocks[I].Kind in [bkQuote, bkAlignBlock] then
    begin
      // A quote and an alignment container are pure containers - not themselves
      // leaves, only their descendants are. Counting one as a leaf would leave a
      // stale, nil-Block slot in FLayout that paint walks.
      // 🔴 This rule is encoded HERE and in LayoutBlocks; the two must agree.
      if ABlocks[I].Children <> nil then
        Inc(Result, CountLeaves(ABlocks[I].Children));
    end
    else
    begin
      // A list item renders itself (marker + text) AND may carry child blocks -
      // count both.
      Inc(Result);
      if ABlocks[I].Children <> nil then
        Inc(Result, CountLeaves(ABlocks[I].Children));
    end;
end;

procedure TRhoMarkdownViewer.LayoutBlocks(ABlocks: TMarkDownBlockList;
  const AContentLeft, AContentWidth: Single; const AInQuote: Boolean;
  const AAlign: TMarkDownAlign;
  const AGap: Single; var AIndex: Integer; var AY: Single);
var
  I: Integer;
  Block: TMarkDownBlock;
  Bar: TRhoQuoteBar;
  ChildLeft: Single;
begin
  for I := 0 to ABlocks.Count - 1 do
  begin
    Block := ABlocks[I];
    if Block.Kind = bkAlignBlock then
    begin
      // A pure container that contributes no geometry of its own: same left and
      // width, no chrome, no leaf in FLayout - it only hands an alignment down.
      // 🔴 Adding a leaf here would desynchronise it from CountLeaves.
      if Block.Children <> nil then
        LayoutBlocks(Block.Children, AContentLeft, AContentWidth, AInQuote,
          Block.Align, AGap, AIndex, AY);
    end
    else if Block.Kind = bkQuote then
    begin
      // Lay the children out indented; the bar spans their vertical extent.
      Bar.Left := AContentLeft;
      Bar.Top := AY;
      if Block.Children <> nil then
        LayoutBlocks(Block.Children, AContentLeft + QuoteTextIndent,
          Max(1, AContentWidth - QuoteTextIndent), True, AAlign, AGap,
          AIndex, AY);
      // Exclude the trailing gap the last child added, so the bar ends at the
      // content, not in the gap before the next block.
      Bar.Bottom := Max(Bar.Top, AY - AGap);
      FQuoteBars := FQuoteBars + [Bar];
    end
    else
    begin
      LayoutBlock(Block, AContentLeft, AContentWidth, FLayout[AIndex], AInQuote,
        AAlign);
      FLayout[AIndex].Top := AY;
      if Block.Kind = bkCodeBlock then
        FLayout[AIndex].TextTop := AY + CodePadding
      else
        FLayout[AIndex].TextTop := AY;
      // A list item's children (a second paragraph, a code block) sit under its
      // text, aligned to the text column, so capture it before advancing.
      ChildLeft := FLayout[AIndex].TextLeft;
      AY := AY + FLayout[AIndex].Height + AGap;
      Inc(AIndex);
      if Block.Children <> nil then
        LayoutBlocks(Block.Children, ChildLeft,
          Max(1, AContentWidth - (ChildLeft - AContentLeft)), AInQuote, AAlign,
          AGap, AIndex, AY);
    end;
  end;
end;

procedure TRhoMarkdownViewer.EnsureLayout(const AWidth: Single);
var
  Idx: Integer;
  Y, Gap: Single;
begin
  if FLayoutValid and SameValue(FLayoutWidth, AWidth) then
    Exit;
  if AWidth <= 0 then
    Exit;

  SetLength(FLayout, CountLeaves(FBlocks));
  FQuoteBars := nil;
  Gap := FFontSize * BlockGapScale;
  Y := FContentPadding;
  Idx := 0;

  LayoutBlocks(FBlocks, FContentPadding, AWidth, False, maDefault, Gap, Idx, Y);

  if Length(FLayout) > 0 then
    FContentHeight := Y - Gap + FContentPadding
  else
    FContentHeight := 0;

  FLayoutWidth := AWidth;
  FLayoutValid := True;

  // A shorter document may leave us scrolled past the new end.
  if FScrollY > Max(0, FContentHeight - ViewportHeight) then
    FScrollY := Max(0, FContentHeight - ViewportHeight);
  UpdateScrollBar;
end;

procedure TRhoMarkdownViewer.InvalidateLayout;
begin
  FLayoutValid := False;
  FCopyLabel := nil;   // rebuilt with the current font and colours
  FCopiedLabel := nil;
  FLayout := nil;
  // Matches index into FLayout, so they go with it. FSearchIndex is kept: the
  // rebuilt list is identical unless the document itself changed.
  InvalidateSearchMatches;
  RedrawContent;
end;

{ ---- geometry ---- }

function TRhoMarkdownViewer.ViewportHeight: Single;
begin
  if Assigned(FContent) then
    Result := FContent.Height
  else
    Result := 0;
end;

{ ---- scrolling ---- }

procedure TRhoMarkdownViewer.UpdateScrollBar;
var
  MaxScroll: Single;
begin
  if not Assigned(FVScroll) then
    Exit;

  MaxScroll := Max(0, FContentHeight - ViewportHeight);
  FUpdatingScrollBar := True;
  try
    FVScroll.Min := 0;
    FVScroll.Max := FContentHeight;
    FVScroll.ViewportSize := ViewportHeight;
    FVScroll.Enabled := MaxScroll > 0;
    FVScroll.Value := FScrollY;
  finally
    FUpdatingScrollBar := False;
  end;
end;

procedure TRhoMarkdownViewer.ScrollBarChange(Sender: TObject);
begin
  if FUpdatingScrollBar then
    Exit;
  SetScrollPos(FVScroll.Value);
end;

procedure TRhoMarkdownViewer.SetScrollPos(const AY: Single);
var
  NewY: Single;
begin
  NewY := Max(0, Min(AY, Max(0, FContentHeight - ViewportHeight)));
  if SameValue(NewY, FScrollY) then
    Exit;
  FScrollY := NewY;
  UpdateScrollBar;
  RedrawContent;
  // The single choke point for scrolling - wheel, scrollbar, keyboard and
  // drag auto-scroll all arrive here - so OnScroll fires exactly once per
  // actual movement, and never for a no-op such as paging at the end.
  if Assigned(FOnScroll) then
    FOnScroll(Self);
end;

procedure TRhoMarkdownViewer.KeyDown(var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  // F3 / Shift+F3 step through search matches - the platform convention. Only
  // while a search is active, so the key is left alone otherwise.
  if (Key = vkF3) and (FSearchText <> '') then
  begin
    if ssShift in Shift then
      FindPrevious
    else
      FindNext;
    Key := 0;
    Exit;
  end;

  // ssCommand as well as ssCtrl, so the shortcuts are native on macOS.
  if (ssCtrl in Shift) or (ssCommand in Shift) then
    case Key of
      vkC:
        begin
          // Shift gives the rendered text; plain Ctrl+C gives the markdown.
          CopySelection(ssShift in Shift);
          Key := 0;
          Exit;
        end;
      vkA:
        begin
          SelectAll;
          Key := 0;
          Exit;
        end;
    end;

  if Key = vkEscape then
  begin
    ClearSelection;
    Key := 0;
    Exit;
  end;

  // Space pages down, Shift+Space pages up - the reading convention.
  // Tested via KeyChar, not Key: FMX delivers printable keys as a character
  // and commonly leaves Key at 0, so a `vkSpace` case never fires. Both are
  // cleared so the keypress is not also handled as text input.
  if (KeyChar = ' ') or (Key = vkSpace) then
  begin
    if ssShift in Shift then
      SetScrollPos(FScrollY - PageStep)
    else
      SetScrollPos(FScrollY + PageStep);
    Key := 0;
    KeyChar := #0;
    Exit;
  end;

  // Keyboard scrolling. Everything routes through SetScrollPos, so clamping
  // and OnScroll are handled in one place.
  case Key of
    vkUp:
      SetScrollPos(FScrollY - LineStep);
    vkDown:
      SetScrollPos(FScrollY + LineStep);
    vkPrior:                                  // Page Up
      SetScrollPos(FScrollY - PageStep);
    vkNext:                                   // Page Down
      SetScrollPos(FScrollY + PageStep);
    vkHome:
      SetScrollPos(0);
    vkEnd:
      SetScrollPos(FContentHeight);           // clamped to the last page
  else
    inherited KeyDown(Key, KeyChar, Shift);
    Exit;
  end;
  Key := 0;
end;

// One "line" of scroll. Derived from the body font so it tracks FontSize
// rather than being a fixed pixel count.
function TRhoMarkdownViewer.LineStep: Single;
begin
  Result := FFontSize * 1.5;
end;

// A page keeps a couple of lines of overlap, so the reader has context across
// the jump rather than landing on a completely fresh screen.
function TRhoMarkdownViewer.PageStep: Single;
begin
  Result := Max(LineStep, ViewportHeight - LineStep * 2);
end;

procedure TRhoMarkdownViewer.MouseWheel(Shift: TShiftState; WheelDelta: Integer;
  var Handled: Boolean);
begin
  inherited MouseWheel(Shift, WheelDelta, Handled);
  if Handled then
    Exit;
  SetScrollPos(FScrollY - (WheelDelta / 120) * WheelStep);
  Handled := True;
end;

{ ---- hit-testing ---- }

function TRhoMarkdownViewer.LinkAt(const AX, AY: Single): string;
var
  I, J, K: Integer;
  ContentY, RelY: Single;
begin
  Result := '';
  // Viewport Y -> content Y. X never scrolls, so link rects hold absolute X.
  ContentY := AY + FScrollY;

  for I := 0 to High(FLayout) do
  begin
    if ContentY < FLayout[I].Top then
      Break;   // layout is ordered top to bottom
    if ContentY > FLayout[I].Top + FLayout[I].Height then
      Continue;

    RelY := ContentY - FLayout[I].Top;
    for J := 0 to High(FLayout[I].Links) do
      for K := 0 to High(FLayout[I].Links[J].Rects) do
        if FLayout[I].Links[J].Rects[K].Contains(PointF(AX, RelY)) then
          Exit(FLayout[I].Links[J].Url);
  end;
end;

procedure TRhoMarkdownViewer.DoLinkClick(const AUrl: string);
begin
  // A host handler still sees every link, anchors included, so it keeps full
  // control (it can call ScrollToAnchor itself). With no handler, a '#...' target
  // is document-internal navigation and must never reach the shell - handing
  // ShellExecute a bare fragment simply does nothing, which is what made anchor
  // links look broken.
  if Assigned(FOnLinkClick) then
    FOnLinkClick(Self, AUrl)
  else if AUrl.StartsWith('#') then
    ScrollToAnchor(AUrl)
  else
    OpenUrl(AUrl);
end;

procedure TRhoMarkdownViewer.EnsureLayoutForCurrentWidth;
begin
  // Never re-lay-out over a valid layout. Headless callers (MeasureDocument /
  // RenderToCanvas) lay out at an explicit width with the control unparented, so
  // FContent has no meaningful width - measuring off it there would rebuild the
  // whole document at ~1px and throw away the real layout.
  if FLayoutValid then
    Exit;
  if Assigned(FContent) and (FContent.Width > 0) then
    EnsureLayout(Max(1, FContent.Width - FContentPadding * 2));
end;

function TRhoMarkdownViewer.FindAnchor(const AName: string): Integer;
var
  I, N: Integer;
  Target, Slug, Candidate, Src: string;
  Counts: TDictionary<string, Integer>;
begin
  Result := -1;
  Target := LowerCase(Trim(AName));
  if Target.StartsWith('#') then
    Target := Copy(Target, 2, MaxInt);
  if Target = '' then
    Exit;

  Counts := TDictionary<string, Integer>.Create;
  try
    for I := 0 to High(FLayout) do
    begin
      if (FLayout[I].Block = nil) or (FLayout[I].Block.Kind <> bkHeading) then
        Continue;
      // Slug the RENDERED text, so inline markup ('## **Bold** heading') and
      // entities do not leak into the anchor - which is what GitHub does too.
      Src := FLayout[I].PlainText;
      if Src = '' then
        Src := FLayout[I].Block.Text;
      Slug := RhoHeadingSlug(Src);
      if Slug = '' then
        Continue;
      // Repeated headings disambiguate as slug, slug-1, slug-2, ... as on GitHub.
      if Counts.TryGetValue(Slug, N) then
      begin
        Inc(N);
        Counts[Slug] := N;
        Candidate := Slug + '-' + IntToStr(N);
      end
      else
      begin
        Counts.Add(Slug, 0);
        Candidate := Slug;
      end;
      if Candidate = Target then
        Exit(I);
    end;
  finally
    Counts.Free;
  end;
end;

function TRhoMarkdownViewer.ScrollToAnchor(const AName: string): Boolean;
var
  Idx: Integer;
begin
  // Anchors can be resolved before the first paint, so make sure there is a
  // layout to search.
  EnsureLayoutForCurrentWidth;
  Idx := FindAnchor(AName);
  Result := Idx >= 0;
  if Result then
    // Land the heading at the top of the view; SetScrollPos clamps at the ends.
    SetScrollPos(FLayout[Idx].Top - FContentPadding);
end;

procedure TRhoMarkdownViewer.OpenUrl(const AUrl: string);
begin
  if AUrl = '' then
    Exit;
  {$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(AUrl), nil, nil, SW_SHOWNORMAL);
  {$ENDIF}
  {$IFDEF MACOS}
  _system(PAnsiChar(AnsiString('open "' + AUrl + '"')));
  {$ENDIF}
end;

function TRhoMarkdownViewer.TaskAt(const AX, AY: Single): Integer;
var
  I: Integer;
  Top: Single;
  R: TRectF;
begin
  Result := -1;
  for I := 0 to High(FLayout) do
    if (FLayout[I].Block.Kind = bkListItem) and FLayout[I].Block.IsTask then
    begin
      // Same box PaintDecorations draws (MarkerLeft, block top + 3), converted
      // to viewport coords, with a couple of pixels of slack for easier hitting.
      Top := FLayout[I].Top - FScrollY;
      R := RectF(FLayout[I].MarkerLeft, Top + 3,
        FLayout[I].MarkerLeft + CheckBoxSize, Top + 3 + CheckBoxSize);
      R.Inflate(2, 2);
      if R.Contains(PointF(AX, AY)) then
        Exit(I);
    end;
end;

procedure TRhoMarkdownViewer.ToggleTask(const AIndex: Integer);
var
  Block: TMarkDownBlock;
  Doc, ItemText: string;
  TextStart, P, StatePos, Limit: Integer;
  NewChecked: Boolean;
begin
  if (AIndex < 0) or (AIndex > High(FLayout)) then
    Exit;
  Block := FLayout[AIndex].Block;
  if not (Block.IsTask and (Block.Kind = bkListItem)) then
    Exit;
  if Length(Block.SourceMap) = 0 then
    Exit;

  Doc := FMarkdown.Text;
  // SourceMap[i] is a 0-based source offset; Doc is 1-based, so +1. This is the
  // item's first rendered character; the checkbox sits just to its left.
  TextStart := Block.SourceMap[0] + 1;
  if (TextStart < 3) or (TextStart > Length(Doc) + 1) then
    Exit;

  // Scan left from the text for the checkbox: `]`, the state char, then `[`.
  // Bounded so a malformed line cannot run away.
  StatePos := -1;
  Limit := Max(1, TextStart - 32);
  P := TextStart - 1;
  while P >= Limit do
  begin
    if Doc[P] = ']' then
    begin
      if (P >= 3) and (Doc[P - 2] = '[') then
        StatePos := P - 1;
      Break;
    end;
    Dec(P);
  end;
  if StatePos < 1 then
    Exit;

  // Capture before the reassign below reparses and frees the block Block points
  // at - reading Block.Text afterwards would be a use-after-free.
  ItemText := Block.Text;

  if CharInSet(Doc[StatePos], ['x', 'X']) then
  begin
    Doc[StatePos] := ' ';
    NewChecked := False;
  end
  else
  begin
    Doc[StatePos] := 'x';
    NewChecked := True;
  end;

  FMarkdown.Text := Doc;   // fires MarkdownChanged -> reparse + re-layout

  if Assigned(FOnTaskToggle) then
    FOnTaskToggle(Self, ItemText, NewChecked);
end;

// Decides whether a drag has reached an edge zone, and how fast to scroll.
// AY is viewport-local, and can be negative or past the bottom because
// FContent has AutoCapture set - which is the whole point.
procedure TRhoMarkdownViewer.UpdateAutoScroll(const AY: Single);
var
  H, Over: Single;
begin
  H := ViewportHeight;
  FAutoScrollStep := 0;

  if AY < AutoScrollMargin then
  begin
    Over := AutoScrollMargin - AY;
    FAutoScrollStep := -Min(Over, AutoScrollMaxStep);
  end
  else if AY > H - AutoScrollMargin then
  begin
    Over := AY - (H - AutoScrollMargin);
    FAutoScrollStep := Min(Over, AutoScrollMaxStep);
  end;

  if Assigned(FAutoScrollTimer) then
    FAutoScrollTimer.Enabled := FSelecting and (FAutoScrollStep <> 0);
end;

procedure TRhoMarkdownViewer.AutoScrollTick(Sender: TObject);
var
  Before: Single;
begin
  if not FSelecting then
  begin
    FAutoScrollTimer.Enabled := False;
    Exit;
  end;

  Before := FScrollY;
  SetScrollPos(FScrollY + FAutoScrollStep);
  if SameValue(Before, FScrollY) then
  begin
    // Already at the top or bottom - stop rather than spinning the timer.
    FAutoScrollTimer.Enabled := False;
    Exit;
  end;

  // The document moved under a stationary pointer, so the selection end has
  // changed even though no mouse event fired.
  FSelCaret := PosAt(FDragX, FDragY);
  RedrawContent;
end;

procedure TRhoMarkdownViewer.ContentMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Single);
var
  Url: string;
  Code: Integer;
  OverBtn, OverTask: Boolean;
begin
  if FSelecting then
  begin
    FDragX := X;
    FDragY := Y;
    UpdateAutoScroll(Y);
    FSelCaret := PosAt(X, Y);
    RedrawContent;
    Exit;
  end;

  // Code-block Copy button hover state
  Code := CodeBlockAt(X, Y, OverBtn);
  if (Code <> FHoveredCode) or (OverBtn <> FCopyButtonHot) then
  begin
    FHoveredCode := Code;
    FCopyButtonHot := OverBtn;
    RedrawContent;
  end;

  Url := LinkAt(X, Y);
  OverTask := FAllowTaskToggle and (TaskAt(X, Y) >= 0);
  if (Url <> FHoveredLink) or OverBtn or OverTask then
  begin
    FHoveredLink := Url;
    if (Url <> '') or OverBtn or OverTask then
      FContent.Cursor := crHandPoint
    else
      FContent.Cursor := crDefault;
  end;
end;

procedure TRhoMarkdownViewer.ContentMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Url: string;
  Code: Integer;
  OverBtn: Boolean;
begin
  if Button <> TMouseButton.mbLeft then
    Exit;

  // Copy button: fire on release, and only if the press started on it too.
  if FCopyButtonPressed then
  begin
    FCopyButtonPressed := False;
    Code := CodeBlockAt(X, Y, OverBtn);
    if OverBtn and (Code >= 0) then
      CopyCodeBlock(Code);
    Exit;
  end;

  // Task checkbox: same press-and-release-on-the-same-target rule as the
  // Copy button. ToggleTask reparses, so capture the index first.
  if FPressedTask >= 0 then
  begin
    Code := FPressedTask;
    FPressedTask := -1;
    if TaskAt(X, Y) = Code then
      ToggleTask(Code);
    Exit;
  end;

  if FSelecting then
  begin
    FSelecting := False;
    if Assigned(FAutoScrollTimer) then
      FAutoScrollTimer.Enabled := False;
    FSelCaret := PosAt(X, Y);
    RedrawContent;
    Exit;
  end;

  // Resolve the link under the pointer at mouse-UP, so a click that presses on
  // a link and releases elsewhere does not fire.
  Url := LinkAt(X, Y);
  if (Url <> '') and (Url = FPressedLink) then
    DoLinkClick(Url);
  FPressedLink := '';
end;

procedure TRhoMarkdownViewer.ContentMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Button <> TMouseButton.mbLeft then
    Exit;

  if CanFocus and not IsFocused then
    SetFocus;   // so the keyboard shortcuts below reach us

  // A press on the Copy button must not also begin a selection drag.
  CodeBlockAt(X, Y, FCopyButtonPressed);
  if FCopyButtonPressed then
    Exit;

  // A press on a task checkbox is armed here and fired on release (below), so a
  // press-and-drag-off cancels rather than toggling. It must not start a drag.
  FPressedTask := -1;
  if FAllowTaskToggle then
  begin
    FPressedTask := TaskAt(X, Y);
    if FPressedTask >= 0 then
      Exit;
  end;

  FPressedLink := LinkAt(X, Y);
  // Starting a drag on a link would fight the click, so only begin a selection
  // when the press is not on one.
  if FPressedLink = '' then
  begin
    FSelecting := True;
    FSelAnchor := PosAt(X, Y);
    FSelCaret := FSelAnchor;
    RedrawContent;
  end;
end;

procedure TRhoMarkdownViewer.ContentMouseLeave(Sender: TObject);
begin
  FHoveredLink := '';
  FHoveredCode := -1;
  FCopyButtonHot := False;
  if Assigned(FContent) then
    FContent.Cursor := crDefault;
  RedrawContent;
end;

{ ---- selection ---- }

procedure TRhoMarkdownViewer.SetSelectionColor(const AValue: TAlphaColor);
begin
  if FSelectionColor = AValue then
    Exit;
  FSelectionColor := AValue;
  RedrawContent;   // decoration only, no re-layout
end;

function TRhoMarkdownViewer.PosAt(const AX, AY: Single): TRhoDocPos;
var
  I: Integer;
  ContentY: Single;
begin
  Result.Block := -1;
  Result.Offset := 0;
  ContentY := AY + FScrollY;

  // Default to the very start of the document. With AutoCapture set, a drag
  // above the control gives a negative AY, and that should select back to the
  // beginning rather than returning an invalid position.
  for I := 0 to High(FLayout) do
    if FLayout[I].PlainText <> '' then
    begin
      Result.Block := I;
      Break;
    end;

  for I := 0 to High(FLayout) do
  begin
    if FLayout[I].PlainText = '' then
      Continue;
    // Past the end of this block: remember it and keep looking, so a drag into
    // the gap between blocks still lands somewhere sensible.
    if ContentY > FLayout[I].Top + FLayout[I].Height then
    begin
      Result.Block := I;
      Result.Offset := Length(FLayout[I].PlainText);
      Continue;
    end;
    if ContentY < FLayout[I].Top then
      Exit;   // in the gap above this block; keep the previous block's end

    Result.Block := I;

    if Length(FLayout[I].Rows) > 0 then
      Result.Offset := TableOffsetAt(FLayout[I], AX, ContentY)
    else if FLayout[I].Paragraph <> nil then
      Result.Offset := FLayout[I].Paragraph.GetGlyphPositionAtCoordinate(
        AX - FLayout[I].TextLeft, ContentY - FLayout[I].TextTop).Position;

    Result.Offset := EnsureRange(Result.Offset, 0,
      Length(FLayout[I].PlainText));
    Exit;
  end;
end;

// Point -> offset inside a table block's flattened text. Picks the cell whose
// row band the point falls in, then the cell within that row, so a drag across
// a table tracks cell by cell rather than jumping.
function TRhoMarkdownViewer.TableOffsetAt(const ALayout: TRhoBlockLayout;
  const AX, AContentY: Single): Integer;
var
  R, C, BestR, BestC: Integer;
  RelX, RelY: Single;
  Cell: TRectF;
begin
  Result := 0;
  RelX := AX - ALayout.BoxLeft;
  RelY := AContentY - ALayout.Top;

  BestR := -1;
  BestC := 0;
  for R := 0 to High(ALayout.Rows) do
  begin
    if Length(ALayout.Rows[R]) = 0 then
      Continue;
    Cell := ALayout.Rows[R][0].Rect;
    if RelY >= Cell.Top then
      BestR := R;      // remember the last row at or above the point
  end;
  if BestR < 0 then
    Exit;

  for C := 0 to High(ALayout.Rows[BestR]) do
    if RelX >= ALayout.Rows[BestR][C].Rect.Left then
      BestC := C;

  with ALayout.Rows[BestR][BestC] do
  begin
    if Paragraph = nil then
      Exit(TextStart);
    Result := TextStart + Paragraph.GetGlyphPositionAtCoordinate(
      RelX - (Rect.Left + TableCellPadH),
      RelY - (Rect.Top + TableCellPadV)).Position;
    Result := EnsureRange(Result, TextStart, TextStart + TextLen);
  end;
end;

function TRhoMarkdownViewer.HasSelection: Boolean;
var
  A, B: TRhoDocPos;
begin
  Result := SelectionRange(A, B);
end;

function TRhoMarkdownViewer.SelectionRange(out AFrom, ATo: TRhoDocPos): Boolean;
begin
  AFrom := FSelAnchor;
  ATo := FSelCaret;
  Result := (AFrom.Block >= 0) and (ATo.Block >= 0);
  if not Result then
    Exit;
  // Normalise so AFrom is always the earlier position.
  if (ATo.Block < AFrom.Block) or
     ((ATo.Block = AFrom.Block) and (ATo.Offset < AFrom.Offset)) then
  begin
    AFrom := FSelCaret;
    ATo := FSelAnchor;
  end;
  Result := (AFrom.Block <> ATo.Block) or (AFrom.Offset <> ATo.Offset);
end;

procedure TRhoMarkdownViewer.ClearSelection;
begin
  if not HasSelection then
    Exit;
  FShowCodeCopyButton := True;
  FHoveredCode := -1;
  FCopiedCode := -1;
  FSelAnchor.Block := -1;
  FSelCaret.Block := -1;
  RedrawContent;
end;

procedure TRhoMarkdownViewer.SelectAll;
var
  I: Integer;
begin
  FShowCodeCopyButton := True;
  FHoveredCode := -1;
  FCopiedCode := -1;
  FSelAnchor.Block := -1;
  for I := 0 to High(FLayout) do
    if FLayout[I].PlainText <> '' then
    begin
      if FSelAnchor.Block < 0 then
      begin
        FSelAnchor.Block := I;
        FSelAnchor.Offset := 0;
      end;
      FSelCaret.Block := I;
      FSelCaret.Offset := Length(FLayout[I].PlainText);
    end;
  RedrawContent;
end;

// Maps a document position to an offset in the markdown source. Characters can
// lack a source (a decoded entity's replacement, a synthetic break), so scan
// outwards in the requested direction for the nearest one that has it.
function TRhoMarkdownViewer.SourceOffsetAt(const APos: TRhoDocPos;
  const AForward: Boolean): Integer;
var
  Map: TArray<Integer>;
  I: Integer;
begin
  Result := -1;
  if (APos.Block < 0) or (APos.Block > High(FLayout)) then
    Exit;
  Map := FLayout[APos.Block].CharSource;
  if Length(Map) = 0 then
    Exit;

  if AForward then
  begin
    for I := EnsureRange(APos.Offset, 0, High(Map)) to High(Map) do
      if Map[I] >= 0 then
        Exit(Map[I]);
  end
  else
    for I := EnsureRange(APos.Offset - 1, 0, High(Map)) downto 0 do
      if Map[I] >= 0 then
        Exit(Map[I] + 1);   // exclusive end
end;

function TRhoMarkdownViewer.SelectedText(APlainText: Boolean): string;
var
  A, B: TRhoDocPos;
  I, S, E, SrcA, SrcB: Integer;
  Doc: string;
  Builder: TStringBuilder;
begin
  Result := '';
  if not SelectionRange(A, B) then
    Exit;

  if not APlainText then
  begin
    // Exact markdown: map the ends back into the source and slice it. This
    // beats reconstructing markdown from styling - it reproduces the original
    // verbatim, including any syntax the renderer consumed.
    SrcA := SourceOffsetAt(A, True);
    SrcB := SourceOffsetAt(B, False);
    Doc := FMarkdown.Text;
    if (SrcA >= 0) and (SrcB > SrcA) and (SrcB <= Length(Doc)) then
      Exit(Copy(Doc, SrcA + 1, SrcB - SrcA));
    // No usable source mapping; fall through to plain text rather than
    // returning nothing.
  end;

  Builder := TStringBuilder.Create;
  try
    for I := A.Block to Min(B.Block, High(FLayout)) do
    begin
      if FLayout[I].PlainText = '' then
        Continue;
      if I = A.Block then S := A.Offset else S := 0;
      if I = B.Block then E := B.Offset else E := Length(FLayout[I].PlainText);
      S := EnsureRange(S, 0, Length(FLayout[I].PlainText));
      E := EnsureRange(E, S, Length(FLayout[I].PlainText));
      if Builder.Length > 0 then
        Builder.Append(sLineBreak);
      // The marker belongs to the item only when the item is taken from its
      // start; a selection beginning mid-text should not sprout a bullet.
      if S = 0 then
        Builder.Append(FLayout[I].CopyPrefix);
      Builder.Append(Copy(FLayout[I].PlainText, S + 1, E - S));
    end;
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

procedure TRhoMarkdownViewer.CopySelection(APlainText: Boolean);
var
  Svc: IFMXClipboardService;
  S: string;
begin
  S := SelectedText(APlainText);
  if S = '' then
    Exit;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService,
    IInterface(Svc)) then
    Svc.SetClipboard(S);
end;

procedure TRhoMarkdownViewer.PaintSelection(const ACanvas: ISkCanvas;
  const AIndex: Integer; const AScrollY: Single);
var
  A, B: TRhoDocPos;
  S, E, J: Integer;
  Rects: TArray<TRectF>;
  Paint: ISkPaint;
  R: TRectF;
begin
  if not SelectionRange(A, B) then
    Exit;
  if (AIndex < A.Block) or (AIndex > B.Block) then
    Exit;

  // Blocks between the two ends are selected whole.
  if AIndex = A.Block then S := A.Offset else S := 0;
  if AIndex = B.Block then E := B.Offset
    else E := Length(FLayout[AIndex].PlainText);
  if E <= S then
    Exit;

  CollectRangeRects(AIndex, S, E, Rects);
  if Length(Rects) = 0 then
    Exit;

  Paint := TSkPaint.Create;
  Paint.Color := FSelectionColor;
  for J := 0 to High(Rects) do
  begin
    R := Rects[J];
    R.Offset(0, -AScrollY);   // content -> screen
    ACanvas.DrawRect(R, Paint);
  end;
end;

{ ---- find ----

  Matching runs over the RENDERED text (FLayout[].PlainText), never the
  markdown source: searching the source would find '**bold**' for "bold" at an
  offset that corresponds to nothing on screen, and would match link URLs and
  entity names the reader cannot see.

  Deliberately within-block. Cross-block phrases would need a flattened
  document string plus a block-offset index; the simpler model covers what a
  reader actually types. }

// Case folding that PRESERVES LENGTH. SysUtils.LowerCase with a locale can
// change a string's length for some scripts, which would put every match
// offset out of step with the paragraph it indexes into. Char.ToLower is
// per-character, so it cannot.
function FoldCase(const S: string): string;
var
  I: Integer;
begin
  SetLength(Result, Length(S));
  for I := 1 to Length(S) do
    Result[I] := S[I].ToLower;
end;

function IsSearchWordChar(const Ch: Char): Boolean;
begin
  // IsLetterOrDigit is Unicode-aware, so a whole-word search behaves the same
  // for accented text as for ASCII.
  Result := Ch.IsLetterOrDigit or (Ch = '_');
end;

// APos is 1-based, matching Pos.
function WholeWordAt(const AText: string; const APos, ALen: Integer): Boolean;
begin
  Result := ((APos = 1) or not IsSearchWordChar(AText[APos - 1])) and
            ((APos + ALen > Length(AText)) or
             not IsSearchWordChar(AText[APos + ALen]));
end;

procedure TRhoMarkdownViewer.DoSearchChange;
begin
  if Assigned(FOnSearchChange) then
    FOnSearchChange(Self);
end;

procedure TRhoMarkdownViewer.InvalidateSearchMatches;
begin
  FSearchValid := False;
  FSearchMatches := nil;
end;

procedure TRhoMarkdownViewer.RebuildSearchMatches;
var
  I, P, N, NeedleLen: Integer;
  Needle, Hay: string;
begin
  FSearchMatches := nil;
  if FSearchText = '' then
    Exit;

  if FSearchCaseSensitive then
    Needle := FSearchText
  else
    Needle := FoldCase(FSearchText);
  NeedleLen := Length(Needle);

  N := 0;
  SetLength(FSearchMatches, 16);
  for I := 0 to High(FLayout) do
  begin
    // Blocks that render no text (rules, block images) have no PlainText and
    // so can never match - which is also why they are skipped rather than
    // searched and found empty.
    if FLayout[I].PlainText = '' then
      Continue;
    if FSearchCaseSensitive then
      Hay := FLayout[I].PlainText
    else
      Hay := FoldCase(FLayout[I].PlainText);

    P := Pos(Needle, Hay);
    while P > 0 do
    begin
      if (not FSearchWholeWords) or WholeWordAt(Hay, P, NeedleLen) then
      begin
        if N = Length(FSearchMatches) then
          SetLength(FSearchMatches, N * 2);
        FSearchMatches[N].Block := I;
        FSearchMatches[N].Start := P - 1;   // Pos is 1-based; offsets are not
        FSearchMatches[N].Len := NeedleLen;
        Inc(N);
      end;
      // Overlapping hits are not reported ('aa' in 'aaa' is one match), which
      // is what every find bar does.
      P := Pos(Needle, Hay, P + NeedleLen);
    end;
  end;
  SetLength(FSearchMatches, N);
end;

procedure TRhoMarkdownViewer.EnsureSearchMatches;
begin
  if FSearchValid then
    Exit;

  if FSearchText = '' then
  begin
    FSearchMatches := nil;
    FSearchValid := True;
    Exit;
  end;

  FSearchMatches := nil;   // never leave hits pointing into a dead layout
  EnsureLayoutForCurrentWidth;
  if not FLayoutValid then
    // No content width yet (a search set before the control is shown). Leave
    // FSearchValid False so the next paint, which does lay out, rebuilds.
    Exit;

  RebuildSearchMatches;
  FSearchValid := True;
  if FSearchIndex > High(FSearchMatches) then
    FSearchIndex := -1;
end;

procedure TRhoMarkdownViewer.CollectRangeRects(const ABlock, AStart,
  AEnd: Integer; var ARects: TArray<TRectF>);
var
  L: TRhoBlockLayout;
  Row, Col, N: Integer;

  procedure Add(const AR: TRectF);
  begin
    if N = Length(ARects) then
      SetLength(ARects, Max(4, N * 2));
    ARects[N] := AR;
    Inc(N);
  end;

  // Intersects the requested range with one paragraph's slice of the block's
  // flattened PlainText, and emits that paragraph's rects at its own origin.
  // A block made of several paragraphs (table cells, front-matter rows) is
  // just repeated calls to this.
  procedure AddSlice(const APara: ISkParagraph;
    const ATextStart, ATextLen: Integer; const AOriginX, AOriginY: Single);
  var
    CS, CE, J: Integer;
    Boxes: TArray<TSkTextBox>;
    R: TRectF;
  begin
    if (APara = nil) or (ATextLen <= 0) then
      Exit;
    CS := Max(AStart, ATextStart);
    CE := Min(AEnd, ATextStart + ATextLen);
    if CE <= CS then
      Exit;
    Boxes := APara.GetRectsForRange(CS - ATextStart, CE - ATextStart,
      TSkRectHeightStyle.Tight, TSkRectWidthStyle.Tight);
    for J := 0 to High(Boxes) do
    begin
      R := Boxes[J].Rect;
      R.Offset(AOriginX, AOriginY);
      Add(R);
    end;
  end;

begin
  ARects := nil;
  N := 0;
  if (ABlock < 0) or (ABlock > High(FLayout)) or (AEnd <= AStart) then
    Exit;
  L := FLayout[ABlock];

  if Length(L.Rows) > 0 then
  begin
    for Row := 0 to High(L.Rows) do
      for Col := 0 to High(L.Rows[Row]) do
        AddSlice(L.Rows[Row][Col].Paragraph, L.Rows[Row][Col].TextStart,
          L.Rows[Row][Col].TextLen,
          L.BoxLeft + L.Rows[Row][Col].Rect.Left + TableCellPadH,
          L.Top + L.Rows[Row][Col].Rect.Top + TableCellPadV);
  end
  else if Length(L.MetaRows) > 0 then
  begin
    for Row := 0 to High(L.MetaRows) do
    begin
      AddSlice(L.MetaRows[Row].KeyPara, L.MetaRows[Row].KeyStart,
        L.MetaRows[Row].KeyLen,
        L.BoxLeft + L.MetaKeyLeft, L.Top + L.MetaRows[Row].Top);
      AddSlice(L.MetaRows[Row].ValuePara, L.MetaRows[Row].ValueStart,
        L.MetaRows[Row].ValueLen,
        L.BoxLeft + L.MetaValueLeft, L.Top + L.MetaRows[Row].Top);
    end;
  end
  else
    // An ordinary block's single paragraph IS the whole of PlainText, so its
    // slice starts at 0.
    AddSlice(L.Paragraph, 0, Length(L.PlainText), L.TextLeft, L.TextTop);

  SetLength(ARects, N);
end;

procedure TRhoMarkdownViewer.ScrollMatchIntoView(const AMatch: TRhoSearchMatch);
var
  Rects: TArray<TRectF>;
  I: Integer;
  U: TRectF;
  VH: Single;
begin
  VH := ViewportHeight;
  if VH <= 0 then
    Exit;

  CollectRangeRects(AMatch.Block, AMatch.Start, AMatch.Start + AMatch.Len,
    Rects);
  if Length(Rects) = 0 then
  begin
    // No geometry for the range. The block top is always known, so fall back
    // to that rather than not moving at all.
    if (AMatch.Block >= 0) and (AMatch.Block <= High(FLayout)) then
      SetScrollPos(FLayout[AMatch.Block].Top - FContentPadding);
    Exit;
  end;

  U := Rects[0];
  for I := 1 to High(Rects) do
    // The class form, not the instance method: TRectF.Union as a method is the
    // in-place procedure, which is not what an assignment wants.
    U := TRectF.Union(U, Rects[I]);

  // Only scroll when the match is not already visible, so stepping through
  // several hits on one screen does not make the page jump about. When it does
  // scroll, leave a quarter-viewport of context on the leading side.
  if U.Top < FScrollY + FContentPadding then
    SetScrollPos(U.Top - VH / 4)
  else if U.Bottom > FScrollY + VH - FContentPadding then
    SetScrollPos(U.Bottom - VH + VH / 4);
end;

procedure TRhoMarkdownViewer.PaintSearchMatches(const ACanvas: ISkCanvas;
  const AIndex: Integer; const AScrollY: Single);
var
  M, J: Integer;
  Rects: TArray<TRectF>;
  Paint: ISkPaint;
  Color: TAlphaColor;
  R: TRectF;
begin
  if Length(FSearchMatches) = 0 then
    Exit;

  Paint := TSkPaint.Create;
  for M := 0 to High(FSearchMatches) do
  begin
    // Matches come out of RebuildSearchMatches in block order.
    if FSearchMatches[M].Block < AIndex then
      Continue;
    if FSearchMatches[M].Block > AIndex then
      Break;

    if M = FSearchIndex then
      Color := FSearchCurrentColor
    else
      Color := FSearchHighlightColor;
    if Color = TAlphaColors.Null then
      Continue;
    Paint.Color := Color;

    CollectRangeRects(FSearchMatches[M].Block, FSearchMatches[M].Start,
      FSearchMatches[M].Start + FSearchMatches[M].Len, Rects);
    for J := 0 to High(Rects) do
    begin
      R := Rects[J];
      R.Offset(0, -AScrollY);   // content -> screen
      ACanvas.DrawRect(R, Paint);
    end;
  end;
end;

function TRhoMarkdownViewer.StepSearch(const AForward: Boolean): Boolean;
var
  I: Integer;
begin
  EnsureSearchMatches;
  Result := Length(FSearchMatches) > 0;

  if not Result then
    FSearchIndex := -1
  else if FSearchIndex < 0 then
  begin
    // Nothing current yet: start from what the reader is looking at rather
    // than from the top of the document.
    if AForward then
    begin
      FSearchIndex := 0;
      for I := 0 to High(FSearchMatches) do
        if FLayout[FSearchMatches[I].Block].Top >= FScrollY then
        begin
          FSearchIndex := I;
          Break;
        end;
    end
    else
    begin
      FSearchIndex := High(FSearchMatches);
      for I := High(FSearchMatches) downto 0 do
        if FLayout[FSearchMatches[I].Block].Top < FScrollY then
        begin
          FSearchIndex := I;
          Break;
        end;
    end;
  end
  else if AForward then
    FSearchIndex := (FSearchIndex + 1) mod Length(FSearchMatches)
  else
    FSearchIndex := (FSearchIndex + Length(FSearchMatches) - 1)
      mod Length(FSearchMatches);

  if Result then
    ScrollMatchIntoView(FSearchMatches[FSearchIndex]);
  RedrawContent;   // the current-match highlight moved
  DoSearchChange;
end;

function TRhoMarkdownViewer.FindNext: Boolean;
begin
  Result := StepSearch(True);
end;

function TRhoMarkdownViewer.FindPrevious: Boolean;
begin
  Result := StepSearch(False);
end;

procedure TRhoMarkdownViewer.ClearSearch;
begin
  if (FSearchText = '') and (FSearchIndex < 0) then
    Exit;
  FSearchText := '';
  FSearchMatches := nil;
  FSearchIndex := -1;
  FSearchValid := True;   // empty text has no matches; nothing to rebuild
  RedrawContent;
  DoSearchChange;
end;

function TRhoMarkdownViewer.GetSearchMatchCount: Integer;
begin
  EnsureSearchMatches;
  Result := Length(FSearchMatches);
end;

procedure TRhoMarkdownViewer.SetSearchText(const AValue: string);
begin
  if FSearchText = AValue then
    Exit;
  FSearchText := AValue;
  // The old current match means nothing against new text. Note this does NOT
  // scroll: an incremental find bar assigns on every keystroke, and yanking
  // the view on each one is unusable. The host calls FindNext to move.
  FSearchIndex := -1;
  FSearchValid := False;
  // Resolve now rather than at the next paint, so SearchMatchCount is correct
  // by the time this returns and the OnSearchChange handler can read it.
  EnsureSearchMatches;
  RedrawContent;
  DoSearchChange;
end;

procedure TRhoMarkdownViewer.SetSearchCaseSensitive(const AValue: Boolean);
begin
  if FSearchCaseSensitive = AValue then
    Exit;
  FSearchCaseSensitive := AValue;
  FSearchIndex := -1;
  FSearchValid := False;
  EnsureSearchMatches;
  RedrawContent;
  DoSearchChange;
end;

procedure TRhoMarkdownViewer.SetSearchWholeWords(const AValue: Boolean);
begin
  if FSearchWholeWords = AValue then
    Exit;
  FSearchWholeWords := AValue;
  FSearchIndex := -1;
  FSearchValid := False;
  EnsureSearchMatches;
  RedrawContent;
  DoSearchChange;
end;

procedure TRhoMarkdownViewer.SetSearchHighlightColor(const AValue: TAlphaColor);
begin
  if FSearchHighlightColor = AValue then
    Exit;
  FSearchHighlightColor := AValue;
  RedrawContent;   // decoration only - not baked into the paragraphs
end;

procedure TRhoMarkdownViewer.SetSearchCurrentColor(const AValue: TAlphaColor);
begin
  if FSearchCurrentColor = AValue then
    Exit;
  FSearchCurrentColor := AValue;
  RedrawContent;   // decoration only
end;

{ ---- code-block copy button ---- }

procedure TRhoMarkdownViewer.SetShowCodeCopyButton(const AValue: Boolean);
begin
  if FShowCodeCopyButton = AValue then
    Exit;
  FShowCodeCopyButton := AValue;
  FHoveredCode := -1;
  RedrawContent;   // decoration only, no re-layout
end;

// The two labels are identical for every code block, so they are built once
// per layout rather than per block or (worse) per paint.
procedure TRhoMarkdownViewer.EnsureCopyLabels;
var
  Style: ISkTextStyle;
begin
  if FCopyLabel <> nil then
    Exit;
  Style := BaseTextStyle(FFontSize * CodeButtonScale, False, False);
  FCopyLabel := BuildRun('Copy', Style);
  FCopiedLabel := BuildRun('Copied!', Style);
end;

function TRhoMarkdownViewer.CodeButtonRect(const ALayout: TRhoBlockLayout;
  const AScreenTop: Single): TRectF;
var
  W, H: Single;
begin
  EnsureCopyLabels;
  W := FCopiedLabel.LongestLine + CodeButtonPadH * 2;   // widest of the two
  H := FCopyLabel.Height + CodeButtonPadV * 2;
  // Top-right of the code block, inset so it clears the rounded corner.
  Result := RectF(ALayout.BoxRight - CodeButtonInset - W,
                  AScreenTop + CodeButtonInset,
                  ALayout.BoxRight - CodeButtonInset,
                  AScreenTop + CodeButtonInset + H);
end;

function TRhoMarkdownViewer.CodeBlockAt(const AX, AY: Single;
  out AOverButton: Boolean): Integer;
var
  I: Integer;
  ContentY, ScreenTop: Single;
begin
  Result := -1;
  AOverButton := False;
  if not FShowCodeCopyButton then
    Exit;

  ContentY := AY + FScrollY;
  for I := 0 to High(FLayout) do
  begin
    if FLayout[I].Block = nil then
      Continue;
    if FLayout[I].Block.Kind <> bkCodeBlock then
      Continue;
    if (ContentY < FLayout[I].Top) or
       (ContentY > FLayout[I].Top + FLayout[I].Height) then
      Continue;
    if (AX < FLayout[I].BoxLeft) or (AX > FLayout[I].BoxRight) then
      Continue;

    ScreenTop := FLayout[I].Top - FScrollY;
    AOverButton := CodeButtonRect(FLayout[I], ScreenTop).Contains(PointF(AX, AY));
    Exit(I);
  end;
end;

procedure TRhoMarkdownViewer.CopyCodeBlock(AIndex: Integer);
var
  Svc: IFMXClipboardService;
begin
  if (AIndex < 0) or (AIndex > High(FLayout)) or
     (FLayout[AIndex].Block = nil) then
    Exit;
  // The block's own text - the fenced content, without the ``` fences.
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService,
    IInterface(Svc)) then
    Svc.SetClipboard(FLayout[AIndex].Block.Text);

  FCopiedCode := AIndex;
  FCopiedTimer.Enabled := False;
  FCopiedTimer.Enabled := True;   // restart the feedback window
  RedrawContent;
end;

procedure TRhoMarkdownViewer.CopiedTick(Sender: TObject);
begin
  FCopiedTimer.Enabled := False;
  FCopiedCode := -1;
  RedrawContent;
end;

{ ---- paint ---- }

procedure TRhoMarkdownViewer.RedrawContent;
begin
  if Assigned(FContent) then
    // Redraw, NOT Repaint: plain Repaint re-blits the stale cached frame, so
    // changes that do not resize the surface never appear.
    FContent.Redraw;
end;

procedure TRhoMarkdownViewer.ContentResize(Sender: TObject);
begin
  InvalidateLayout;
  UpdateScrollBar;
end;

procedure TRhoMarkdownViewer.PaintDecorations(const ACanvas: ISkCanvas;
  const ALayout: TRhoBlockLayout; const AScreenTop: Single);
var
  Paint: ISkPaint;
  R: TRectF;
  Y, Cx, Cy: Single;
begin
  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;

  case ALayout.Block.Kind of
    bkRule:
      begin
        Paint.Color := FRuleColor;
        Y := AScreenTop + ALayout.Height / 2;
        ACanvas.DrawRect(RectF(ALayout.BoxLeft, Y,
          ALayout.BoxRight, Y + RuleThickness), Paint);
      end;

    bkCodeBlock:
      begin
        Paint.Color := FCodeBackgroundColor;
        R := RectF(ALayout.BoxLeft, AScreenTop,
          ALayout.BoxRight, AScreenTop + ALayout.Height);
        ACanvas.DrawRoundRect(R, 4, 4, Paint);
      end;

    bkQuote:
      begin
        Paint.Color := FQuoteBarColor;
        ACanvas.DrawRect(RectF(ALayout.BoxLeft, AScreenTop,
          ALayout.BoxLeft + QuoteBarWidth, AScreenTop + ALayout.Height), Paint);
      end;

    bkHeading:
      // TAlphaColors.Null turns the H1/H2 rule off (VCL clNone parity).
      if (ALayout.Block.Level <= 2) and
         (FHeadingRuleColor <> TAlphaColors.Null) then
      begin
        Paint.Color := FHeadingRuleColor;
        Y := AScreenTop + ALayout.Height - RuleThickness;
        ACanvas.DrawRect(RectF(ALayout.BoxLeft, Y,
          ALayout.BoxRight, Y + RuleThickness), Paint);
      end;

    bkListItem:
      if ALayout.Block.IsTask then
      begin
        // Own-drawn checkbox. The VCL version used DrawFrameControl, which is
        // Win32-only and would break the cross-platform promise.
        R := RectF(ALayout.MarkerLeft, AScreenTop + 3,
          ALayout.MarkerLeft + CheckBoxSize, AScreenTop + 3 + CheckBoxSize);
        Paint.Color := FRuleColor;
        Paint.Style := TSkPaintStyle.Stroke;
        Paint.StrokeWidth := 1;
        ACanvas.DrawRoundRect(R, 2, 2, Paint);
        if ALayout.Block.TaskChecked then
        begin
          Paint.Color := FTextColor;
          Paint.StrokeWidth := 2;
          Cx := R.Left + CheckBoxSize * 0.25;
          Cy := R.Top + CheckBoxSize * 0.55;
          ACanvas.DrawLine(PointF(Cx, Cy),
            PointF(R.Left + CheckBoxSize * 0.45, R.Top + CheckBoxSize * 0.75),
            Paint);
          ACanvas.DrawLine(
            PointF(R.Left + CheckBoxSize * 0.45, R.Top + CheckBoxSize * 0.75),
            PointF(R.Left + CheckBoxSize * 0.78, R.Top + CheckBoxSize * 0.28),
            Paint);
        end;
      end;
  end;
end;

procedure TRhoMarkdownViewer.PaintDocument(const ACanvas: ISkCanvas;
  const AWidth, AHeight, AScrollY: Single);
var
  I, J: Integer;
  TextWidth, ScreenTop, ScreenBottom: Single;
  ImgRect: TRectF;
  BarPaint: ISkPaint;
begin
  ACanvas.Clear(FBackgroundColor);

  TextWidth := Max(1, AWidth - FContentPadding * 2);
  EnsureLayout(TextWidth);
  // Matches index into the layout that was just (re)built. This is also what
  // picks up a search set before the control had a width. It fires no event -
  // OnSearchChange must never reach a host from inside the paint pass.
  EnsureSearchMatches;

  // Quote bars first, behind the text. Nested quotes are separate spans at
  // increasing Left, so `>>` draws two bars.
  if Length(FQuoteBars) > 0 then
  begin
    BarPaint := TSkPaint.Create;
    BarPaint.AntiAlias := True;
    BarPaint.Color := FQuoteBarColor;
    for I := 0 to High(FQuoteBars) do
    begin
      ScreenTop := FQuoteBars[I].Top - AScrollY;
      ScreenBottom := FQuoteBars[I].Bottom - AScrollY;
      if (ScreenBottom < 0) or (ScreenTop > AHeight) then
        Continue;
      ACanvas.DrawRect(RectF(FQuoteBars[I].Left, ScreenTop,
        FQuoteBars[I].Left + QuoteBarWidth, ScreenBottom), BarPaint);
    end;
  end;

  for I := 0 to High(FLayout) do
  begin
    // Screen = content - scroll. Only paint what is actually visible; never
    // iterate the whole document's geometry in paint.
    ScreenTop := FLayout[I].Top - AScrollY;
    if ScreenTop > AHeight then
      Break;
    if ScreenTop + FLayout[I].Height < 0 then
      Continue;

    // Painting order per block, and it matters: all chrome, then the highlight
    // layer, then all text. A table or a front-matter card draws in two passes
    // precisely so its text lands on the correct side of that line - drawing
    // either in one pass puts its text UNDER the highlight, which an opaque
    // current-match colour then hides.
    PaintDecorations(ACanvas, FLayout[I], ScreenTop);

    if Length(FLayout[I].Rows) > 0 then
      PaintTableChrome(ACanvas, FLayout[I], ScreenTop);

    if FLayout[I].Block.Kind = bkFrontMatter then
      PaintFrontMatterPanel(ACanvas, FLayout[I], ScreenTop);

    if FLayout[I].Image <> nil then
    begin
      ImgRect := FLayout[I].ImageRect;
      ImgRect.Offset(FLayout[I].BoxLeft, ScreenTop);
      ACanvas.DrawImageRect(FLayout[I].Image, ImgRect,
        TSkSamplingOptions.High);
    end;

    // Search highlights sit under the selection; both are behind every glyph
    // and above the block chrome.
    PaintSearchMatches(ACanvas, I, AScrollY);
    PaintSelection(ACanvas, I, AScrollY);

    if Length(FLayout[I].Rows) > 0 then
      PaintTableText(ACanvas, FLayout[I], ScreenTop);

    if FLayout[I].Block.Kind = bkFrontMatter then
      PaintFrontMatterText(ACanvas, FLayout[I], ScreenTop);

    if FLayout[I].Marker <> nil then
      FLayout[I].Marker.Paint(ACanvas, FLayout[I].MarkerLeft, ScreenTop);

    if FLayout[I].Paragraph <> nil then
      FLayout[I].Paragraph.Paint(ACanvas, FLayout[I].TextLeft,
        FLayout[I].TextTop - AScrollY);

    // Inline images and shifted super/subscript runs sit in placeholder gaps
    // the paragraph left for them, so they paint after the text, in
    // paragraph-relative coordinates.
    for J := 0 to High(FLayout[I].Placeholders) do
    begin
      ImgRect := FLayout[I].Placeholders[J].Rect;
      if ImgRect.IsEmpty then
        Continue;
      ImgRect.Offset(FLayout[I].TextLeft, FLayout[I].TextTop - AScrollY);
      if FLayout[I].Placeholders[J].Image <> nil then
        ACanvas.DrawImageRect(FLayout[I].Placeholders[J].Image, ImgRect,
          TSkSamplingOptions.High)
      else if FLayout[I].Placeholders[J].Para <> nil then
        FLayout[I].Placeholders[J].Para.Paint(ACanvas,
          ImgRect.Left, ImgRect.Top);
    end;

    // The Copy button floats over the code it belongs to, so it paints last.
    if FShowCodeCopyButton and ((I = FHoveredCode) or (I = FCopiedCode)) then
      PaintCodeButton(ACanvas, FLayout[I], ScreenTop, I);
  end;
end;

procedure TRhoMarkdownViewer.PaintCodeButton(const ACanvas: ISkCanvas;
  const ALayout: TRhoBlockLayout; const AScreenTop: Single;
  const AIndex: Integer);
var
  R: TRectF;
  Paint: ISkPaint;
  Para: ISkParagraph;
  Copied: Boolean;
begin
  Copied := AIndex = FCopiedCode;
  R := CodeButtonRect(ALayout, AScreenTop);

  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;

  // Fill with the page background rather than a bespoke colour, so the button
  // reads as sitting above the code block and needs no extra theming.
  Paint.Style := TSkPaintStyle.Fill;
  Paint.Color := FBackgroundColor;
  ACanvas.DrawRoundRect(R, 4, 4, Paint);

  Paint.Style := TSkPaintStyle.Stroke;
  Paint.StrokeWidth := 1;
  if FCopyButtonHot and not Copied then
    Paint.Color := FLinkColor      // hover cue
  else
    Paint.Color := FRuleColor;
  ACanvas.DrawRoundRect(R, 4, 4, Paint);

  if Copied then
    Para := FCopiedLabel
  else
    Para := FCopyLabel;
  Para.Paint(ACanvas,
    R.Left + (R.Width - Para.LongestLine) / 2, R.Top + CodeButtonPadV);
end;

procedure TRhoMarkdownViewer.ContentPaint(ASender: TObject;
  const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
begin
  PaintDocument(ACanvas, ADest.Width, ADest.Height, FScrollY);
end;

function TRhoMarkdownViewer.AsHtml: string;
begin
  // FReferences is passed so reference-style links resolve in the export the
  // same way they do on screen.
  Result := MarkdownToHtml(FMarkdown.Text, FReferences);
end;

function TRhoMarkdownViewer.AsHtmlDocument(const ATitle: string): string;
begin
  Result := MarkdownToHtmlDocument(FMarkdown.Text, ATitle);
end;

function TRhoMarkdownViewer.MeasureDocument(const AWidth: Single): Single;
begin
  EnsureLayout(Max(1, AWidth - FContentPadding * 2));
  Result := FContentHeight;
end;

procedure TRhoMarkdownViewer.RenderToCanvas(const ACanvas: ISkCanvas;
  const AWidth, AHeight: Single; const AScrollY: Single);
begin
  PaintDocument(ACanvas, AWidth, AHeight, AScrollY);
end;

initialization
  // Registers the class for streaming and states its FireMonkey group
  // membership explicitly. Strictly this is redundant - a TControl descendant
  // is already in the TFmxObject group by ancestry - but it is the documented
  // idiom and costs nothing.
  //
  // NOTE it is NOT what fixes a greyed-out palette entry; that is the runtime
  // package's {$R *.res}. See the Packages section of CLAUDE.md.
  RegisterFmxClasses([TRhoMarkdownViewer]);

end.

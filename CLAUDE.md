# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# TRhoMarkdownViewer

A Skia-backed markdown viewer component for **FMX / Delphi 13 (RAD Studio 37.0)**.
Renders markdown directly to an `ISkCanvas` — no WebView, no HTML, no embedded
browser — and installs into the IDE as a designable component on the
**`Rhody Controls`** palette page.

## Status

**Non-visual layer ported and green. Control skeleton runs. Layout pass is the
next piece of work.**

Done and verified:

- `Source/` — `uRhoMarkdownTypes.pas`, `uRhoMarkdownParser.pas`,
  `uRhoMarkdownHighlight.pas`, `uRhoMarkdownHtml.pas`: no FMX or VCL dependency
  (5,757 lines).
- `Tests/RhoMarkdownTests.dpr` — **148 tests, 148 passing.**
- `Source/uRhoMarkdownViewer.pas` — `TRhoMarkdownViewer`, the control:
  `TSkPaintBox` + owned `TScrollBar`, parse-on-change, cached display list,
  published property surface, and the full inline layout pass.
- `Packages/` — both packages build Win32 and produce `.bpl` + `.dcp`.
- `Demo/` — `ufMain` loads `Demo/sample.md`, which deliberately exercises every
  implemented feature. Use it when checking rendering changes.

**Verified rendering** (screenshotted in the running demo): bold, italic,
bold-italic, strikethrough, inline code, `==highlight==`, links (colour +
underline), nested emphasis, formatted link text, hard line breaks, HTML
entities, escaped punctuation, heading scale, H1/H2 underline rules, horizontal
rules, bullet and ordered lists with nesting, task checkboxes (own-drawn),
quote bars, code blocks with per-language syntax colouring, autolinks,
angle/email autolinks, reference-style links, emoji shortcodes, word wrap,
scrollbar range and thumb, wheel scrolling.

Tables and images both render (see their own sections below).

Link hit-testing works: links are clickable, show a hand cursor on hover, and
fire `OnLinkClick` (with no handler, the Url opens in the system browser).

Selection works: drag-select across blocks (paragraphs, headings, lists,
quotes, code blocks, and table cells), `Ctrl/Cmd+A`, `Esc` to clear,
`Ctrl/Cmd+C` to copy markdown, `Ctrl/Cmd+Shift+C` to copy plain text.

⚠️ **Any block that renders text must set `PlainText` (and `CharSource` where
it has one), or it silently has zero selectable length and drags skip over it.**
`Paragraph` alone is not enough. This bit code blocks and table cells in turn —
if you add a block kind, set these.

Images render as blocks and inline; super/subscript are raised and lowered;
`ApplyTheme` gives light and dark; syntax colours are designable. Each has its
own section below.

### CommonMark gaps — candidate next work

Markdown support is complete **relative to the VCL predecessor** — same parser,
verbatim — but that is a lower bar than CommonMark, and the original's README
said as much. Tested empirically; the failing cases live in
`Demo/commonmark-gaps.md`, with expected-vs-actual noted per case.

| Construct | Result |
|---|---|
| **Indented code block** (4 spaces) | ✅ **fixed** — emits `bkCodeBlock`, line breaks preserved |
| **Nested quote** `>>` | ✅ **fixed (Phase A)** — quotes are containers, nested bars |
| **List inside a quote** | ✅ **fixed (Phase A)** — quote holds any block |
| **Multi-paragraph list item** | ✅ **fixed (Phase B)** — item holds child blocks |
| **Code block inside a list item** | ✅ **fixed (Phase B)** — code nests under the item |
| Inline HTML `<b>x</b>` | ✅ **whitelist** — formatting tags + `<img>`; rest literal |
| **Fence length / `~~~` fences** | ✅ **fixed 2026-08-09** — see below |
| Ordered list starting at N | ✅ works |
| Link with title | ✅ works |
| `***` / `___` breaks | ✅ work |

**Indented code blocks — done.** `ParseBlocks` detects a run of 4-space (or tab)
indented lines and emits `bkCodeBlock` (plain, no language), dedenting by four
columns and preserving interior blank lines. Guards: it will not interrupt a
paragraph, and declines right after a list item. Indented blocks carry **no
source map** (the `bkCodeBlock` mapper assumes a fence), so the dispatch routes
only fenced blocks to it and indented ones fall back to nearest-neighbour copy.

**Code fences: length matters, and `~~~` works.** A fence closes a block only
if it uses the **same character**, is **at least as long** as the opener, and
has **nothing but whitespace** after it. Before this, `StartsWithFence` was
`Copy(TrimLeftOnly(S), 1, 3) = '```'` and served as both the opening *and* the
closing test, so every fence was three backticks: a ````-fenced block ended at
its first inner ```, and there was no way at all to show code in a language that
uses ``` itself — Antimony and Python triple-quoted strings, or any document
about markdown. Reported from real Antimony source.

`FenceRun` decomposes a fence line into character, run length and info string;
`StartsWithFence` is the opening test (a backtick fence's info string may not
contain a backtick); `IsClosingFence(S, AChar, ALen)` is the closing test and
**needs the opening fence's character and length** — that is why `ParseBlocks`
records them when it opens the block. ⚠️ **`MapJoinedLines` has the same
requirement and it is easy to miss**: it took `StopAtFence: Boolean` and broke
on any fence, so an inner ``` truncated the source map — and a map that does not
account for every character is *discarded entirely*, so the symptom was verbatim
copy silently degrading to plain text, not a visibly wrong map. It now derives
the fence from the block's own opening line.

Cases live in `Demo/sample.md`; `ParseBlocksLongFenceContainsBackticks` and
friends cover the parse and the source map.

🔴 **The strictness is a decision, not an oversight — do not soften it.** A
```-fenced block whose content contains a bare ``` is *ambiguous by the spec*:
the inner fence closes the block, the next one opens a new one, and that new
block swallows the following prose. Every conformant renderer does the same —
the user confirmed MarkText renders the reported document identically, and
adding the fourth backtick fixes it there too. The author's fix is a ```` or
`~~~` outer fence.

Two lenient alternatives were considered and **rejected by the user
(2026-08-09)**: letting an info-string-bearing fence close a block (limits the
damage but still mis-renders), and treating a fence line immediately followed by
another fence line as content (recovers the intent, but breaks back-to-back code
blocks and diverges from every other renderer). The reason for rejecting both:
a `.md` file must render the same here as it does on GitHub. Reaching for a
heuristic here trades that away to paper over malformed input.

**Container blocks — Phases A (quotes) and B (list items) done.**
`TMarkDownBlock` has an owned `Children: TMarkDownBlockList`. A `bkQuote` is a
pure container (content in `Children`, not `Text`); a `bkListItem` renders its
own marker+text **and** may carry `Children` for extra content. `ParseBlocks` is
recursive: the quote branch strips one `>` (`StripQuoteMarker`) and re-parses;
the list branch calls `GatherItemChildren`, which pulls a blank-line-separated
run of lines indented to the item's content column (a second paragraph, a code
block) and re-parses it as the item's children. Recursive calls pass
`MapSource=False`, so container children get **no source map** — verbatim copy
*wholly inside* a container falls back to plain text; a selection spanning it and
mapped neighbours still slices verbatim.

Deliberate Phase B scope limits: sub-lists still use the flat `IndentLevel`
mechanism (a nested `-` marker is **not** folded into `Children` — only non-list
content is), and continuation must be blank-line-separated (tight lazy
continuation is not folded in).

The viewer keeps `FLayout` **flat**: `EnsureLayout` → `LayoutBlocks` recurses the
tree, flattening every leaf into `FLayout` (so `TRhoDocPos`, hit-testing and
selection are unchanged). A quote records bar spans in `FQuoteBars` (nested =
stacked bars) and adds no leaf; a list item lays out its leaf then recurses its
children indented to the item's text column. `CountLeaves` pre-sizes `FLayout`
and **must not count a quote as a leaf** (a nil-Block slot would crash paint).
Paragraphs inside a quote render italic via `LayoutBlock`'s `AInQuote`. HTML
export (`uRhoMarkdownHtml`) recurses via `EmitBlockList`; list-item children go
through `EmitChildBlocks`, which must **not** touch the shared list stack (its
`CloseAllLists` would close the enclosing `<li>`). See
`Docs/container-blocks-plan.md`.

**Phase C (optional) is the only container work left** — precise source maps for
nested content, upgrading verbatim copy inside a container from the plain-text
fallback. Worth doing only if that copy fidelity turns out to matter.

### Not yet ported from the VCL original

Rendering is complete, but part of the predecessor's API and interaction surface
is not. Audited against its README feature list.

**Already done** (this list was stale; verified against the code 2026-07-22):

- **`AsHtml` / `AsHtmlDocument`** — both control methods exist
  (`uRhoMarkdownViewer.pas`), alongside the free-function `MarkdownToHtml`.
- **Keyboard scrolling** — `KeyDown` handles arrows, PageUp/Down, Home/End.
- **Code-block Copy button** on hover — implemented (`FCopyButton*`).
- **`OnScroll`** — published `TNotifyEvent`, fired from the single `SetScrollPos`
  choke point. `MDViewerEditor/ufMain.pas` uses it for two-way editor↔preview
  scroll sync.
- **`HeadingRuleColor`** — published `TAlphaColor`. `ApplyTheme` sets it to match
  `RuleColor`, so H1/H2 rules look unchanged by default; `TAlphaColors.Null`
  disables them (VCL `clNone` parity). Independent of `RuleColor`, which still
  drives the horizontal rule, table borders, checkbox and copy button.

- **Find/search** — ✅ **done 2026-08-09.** `SearchText`, `FindNext`,
  `FindPrevious`, `SearchMatchCount` and more; see the Find section below. The
  component owns the mechanism, the host owns the find bar.

**Nothing from the VCL API is outstanding.**

Dropped by decision: **`AppendMarkdownText`** incremental streaming — the user
does not want it; reparsing the whole document on every change is fine.

Recently added: **`AllowTaskToggle`** — clickable task checkboxes. Published
`Boolean` (default False, keeping the viewer read-only) plus an `OnTaskToggle`
event. A click flips the item's `[ ]`/`[x]` in the markdown source and reparses;
`TaskAt`/`ToggleTask` in the viewer, source located via the block's
`SourceMap[0]`. This is the first source-writeback path in the control - the
groundwork the eventual in-place editing would build on.

Deliberately out of scope from the v1 decision: in-place editing, undo/redo,
caret navigation.

**Ahead of the original:** dark theme, designable `SyntaxColors`, inline images,
true super/subscript baselines, emoji/symbol font fallback, Antimony, the
headless render tool, and cross-platform rendering.

**Nothing on the original backlog is outstanding.** Known limitations, all
deliberate and explained in their sections:

- A table's characters have no source mapping, so a table-*only* selection
  copies as tab-separated plain text rather than markdown.
- Super/subscript runs containing a surrogate pair render unshifted.
- Remote image URLs are never fetched.

## Origin: what was ported, what was rewritten

This is a port of a VCL/GDI markdown viewer (~17.6k lines). **That source tree
has been deleted now the port is complete** — the notes below are the record of
what came from where, since it is no longer inspectable.

Its layering was cleaner than its size suggested: `TFontStyles`, `TColor`, and
`TAlignment` all live in `System.UITypes` / `System.Classes`, **not**
`Vcl.Graphics`, so a third of the codebase ported by editing `uses` clauses.

**Ported near-verbatim** (5,757 lines — do not rewrite these):

| Original VCL unit | New unit | VCL coupling stripped |
|---|---|---|
| `MarkdownViewer.Model.pas` | `uRhoMarkdownTypes.pas` | `TFontStyles` only |
| `MarkdownViewer.Parser.pas` | `uRhoMarkdownParser.pas` | one reference |
| `MarkdownViewer.Highlight.pas` | `uRhoMarkdownHighlight.pas` | **none** |
| `MarkdownViewer.Html.pas` | `uRhoMarkdownHtml.pas` | `TFontStyles` only |

`uRhoMarkdownHighlight.pas` is 3,884 lines of hand-written lexers for 25+
languages plus the `IMarkdownSyntaxHighlighter` registry. It is framework-free
and takes no changes at all.

**Rewritten:** `MarkdownViewerVCL.pas` (4,879 lines) and
`MarkdownViewer.Renderer.pas` (121 lines of `TCanvas` helpers). See below for
why.

**Also left behind:** `TMarkDownLinkHit`, `TMarkDownTaskHit`, `TMarkDownTextRun`,
`TMarkDownCopyChunk`, and the block's `LayoutTop` / `LayoutHeight` /
`LayoutWidth` fields. These are display-list types in `TRect` (integer) that only
the old control referenced. They get redesigned in `TRectF` as part of the
viewer's display list — layout does not belong on the model.

### Two port gotchas

- **`fsBold` and friends do not exist unqualified under FMX.** `System.UITypes`
  declares `TFontStyle` with `SCOPEDENUMS ON`; the bare spellings the parser and
  HTML exporter use throughout came from `Vcl.Graphics`, which re-exports them as
  constants. `uRhoMarkdownTypes.pas` re-exports them the same way — that is why
  5,700 ported lines needed no edits. Don't remove those four constants.
- **`Assert.AreEqual(1, SomeInteger)` is ambiguous on Win64** (`E2532`) though it
  compiled in the Win32 VCL project. The ported tests use
  `Assert.AreEqual<Integer>(...)` at ~120 sites. Write new integer assertions
  with the explicit type argument.
- **Brace comments do not nest.** A `{ ... }` comment containing a compiler
  directive such as a resource-include ends at that directive's closing brace,
  and the rest of the comment is parsed as code. Bit the `.dpk` headers; they
  use `//` now.

### Deliberate divergence from the VCL original

`:check:` mapped to `#$D805#$DF05` — a surrogate pair decoding to **U+11705, a
letter in the Ahom script**, which rendered as tofu. Changed to `#$2705`
(WHITE HEAVY CHECK MARK), which is in the BMP and needs no surrogate pair. Every
other emoji mapping in the table decodes correctly and was left alone.

## Architecture

### Why the control is a rewrite and not a port

The VCL control fuses layout into paint. `Paint` clears `FLinkHits`,
`FTaskHits`, `FTextRuns`, `FCopyChunks`, and `FSelectableText`, then calls
`DrawBlocks` to rebuild all of them **on every repaint** — so scrolling and
caret blink re-lay-out the whole document. `DrawInline` takes an
`ADraw: Boolean` and walks the same atom loop twice: measure on false, paint on
true. Text is handled atom-by-atom with `Canvas.TextWidth` / `Canvas.TextOut`
against a mutable `Canvas.Font` (52 assignments to it). That is the GDI idiom
Skia is not.

**Split layout from paint.** A layout pass produces a display list — positioned
runs, rects, link/task hits, and the selectable-text map — cached and
invalidated on text / width / font change. Paint walks that list. Hit-testing,
selection, and (later) editing's source-position mapping all read one tested
structure instead of a paint side effect.

### `ISkParagraph` does the text work

The Skia binding in 37.0 (`System.Skia.pas`) exposes the full paragraph API, not
just the raw font layer. This replaces the bulk of `DrawInline`:

| Need | API |
|---|---|
| Styled inline runs, nested emphasis | `ISkParagraphBuilder.PushStyle` / `AddText` |
| Line breaking, word wrap, alignment | `ISkParagraph.Layout` |
| Click → text position | `GetGlyphPositionAtCoordinate` |
| Selection rectangles | `GetRectsForRange` |
| Inline images | `AddPlaceholder` |
| Emoji / non-Latin fallback | `ISkTypefaceFontProvider` + family list |

One paragraph per block; one `PushStyle`/`AddText` pair per inline token. The
model's combinable `TFontStyles` (bold containing italic, formatted link text)
maps straight onto the style stack.

**This is not a violation of RhoEditor's "never `TTextLayout`" rule.** That rule
exists to keep the *OS* text engine out of the loop, because FMX routes through
different presenters per platform. `ISkParagraph` is Skia — identical on Windows
and macOS. Same goal, better tool. Do not "fix" this back to a bare `ISkFont`.

### Scrolling — follow RhoEditor

`../RhoEditor` solved this; copy its shape (see its `CLAUDE.md`). A `TControl`
hosting a client-aligned `TSkPaintBox` (`FContent`, always exactly the viewport)
plus real `TScrollBar` children. **We own scrolling** — no `TScrollBox`, whose
auto-hiding overlay bars and touch/inertia behaviour differ Windows↔macOS.
Content is offset by the scroll position at paint time: screen = content −
scroll; hit-testing adds it back.

Load-bearing details carried over from RhoEditor — regressing any of these
produces bugs that look like something else entirely:

- **`Stored := False` on every internally-created child** (`FContent`,
  `FVScroll`, `FHScroll`). FMX streams a control's children into the `.fmx`;
  without this, dropping the component on a form writes them to the form file
  and the constructor creates them again on load — duplicate scrollbars.
- **`ClipChildren := True`** in the constructor. FMX does not clip children to
  the parent, so anything positioned past the edge paints over neighbouring
  controls.
- **Width-dependent re-layout hangs off `FContent.OnResize`, not `Resize`.**
  `FContent` is realigned *after* the control's own `Resize` runs, so inside
  `Resize` the paint box still reports its **previous** width. Re-wrapping there
  silently lags one resize behind and looks like "wrap just doesn't work".
- **`FindTarget` is overridden so drag-and-drop reaches the component.** FMX
  picks a drop target with `TControl.FindTarget`, which recurses into children
  **first** and returns the first one that claims the point, only falling back to
  `Self`. `FContent` is client-aligned and hit-testable, so it always won — and
  because it has no drag handlers the drop was silently refused and the
  component's published `OnDragOver` / `OnDragDrop` **never fired**. The override
  claims any hit inside our bounds for the control itself; the form then calls
  our `DragEnter`/`DragOver`/`DragDrop` with points already in our local
  coordinates. ⚠️ Setting `FContent.HitTest := False` also "fixes" it and must
  **not** be used — it breaks clicking, link hit-testing and drag-selection.
  This is generic to composite FMX controls, not specific to this one.
- Only lay out what is visible. Never iterate all blocks in paint.

### Decisions already made

- **v1 is read-only.** In-place editing, undo/redo, caret motion, and the
  selectable-text-to-source mapping are a large fraction of the old control.
  They are layered on after the viewer is solid — but the display list is
  designed so that mapping is data, not a paint artifact.
- **Images: block *and* inline.** Block images as the VCL version had them, plus
  true inline images via `AddPlaceholder` — which the VCL version could not do.
  Needs a `TSkImage` cache keyed on resolved path, replacing the `TPicture`
  cache. Paths resolve against `BasePath` (set automatically by `LoadFromFile`).
- **Font fallback is on.** The paragraph style gets a font-family list (Segoe UI
  Emoji on Windows, Apple Color Emoji on macOS) so the parser's emoji shortcodes
  (`:smile:`, `:warning:`) render as emoji rather than tofu. Markdown is prose —
  unlike RhoEditor, which deliberately declined fallback for a Latin code editor.
- **HTML export stays.** `uRhoMarkdownHtml.pas` is 285 lines and ports free.

## Repo layout

Mirror RhoEditor:

- `Source/` — `uRhoMarkdownViewer.pas` (the control), `uRhoMarkdownTypes.pas`,
  `uRhoMarkdownParser.pas`, `uRhoMarkdownHighlight.pas`, `uRhoMarkdownHtml.pas`,
  and `uRhoMarkdownViewerReg.pas` (`Register` only).
- `Packages/` — `RhoMarkdownViewer.dpk` (runtime, `{$RUNONLY}`) and
  `dclRhoMarkdownViewer.dpk` (design-time, `{$DESIGNONLY}`, requires the runtime
  package + `designide`). Keep `Register` out of the runtime package so an
  application can link the component without dragging in `designide`.

  🔴 **Both `.dpk` files MUST keep `{$R *.res}`.** Removing it from the *runtime*
  package makes the installed component appear on the palette but **greyed out**,
  with the hover reporting *"Supported platforms: Windows 32-bit"* on a Win64
  project. Nothing else breaks — it compiles, installs, and streams — so it looks
  like a platform or library-path problem and sends you hunting in the wrong
  place. Restoring the directive fixes it immediately.

  **Why:** the IDE compiles the `.dproj`'s `<Platforms>` list into a resource
  named **`PLATFORMTARGETS`** inside `<Package>.res` (visible alongside
  `VS_VERSION_INFO` if you dump the file). `{$R *.res}` is what links that
  resource into the `.bpl`, and the IDE reads it from there to decide which
  platforms a palette component supports. No directive → no `PLATFORMTARGETS`
  in the binary → the IDE defaults to Win32 only.

  That is why editing platform lists appears to do nothing: they are written to
  the `.res` faithfully and then never reach the `.bpl`. It also explains the
  "it randomly started working" folklore — anything that makes the IDE
  regenerate the `.dpk` silently restores the directive.

  This cost hours to find. Everything else was eliminated first: library paths
  (per platform), target-platform lists on both packages, `Win64` vs `Win64x`,
  package type flags, per-platform `.dcp`/`.bpl` presence, build/install
  ordering, class groups and `RegisterFmxClasses`. All were red herrings. If a
  Rhody component ever greys out, **check `{$R *.res}` on its runtime package
  first** — the same symptom has recurred across components on this machine.
- `Demo/` — `MarkDownViewerProject.dproj`. It finds the component through
  `DCC_UnitSearchPath = ..\Source;$(DCC_UnitSearchPath)` rather than listing the
  units, so it compiles the way a consumer's project would and F9 recompiles
  edited component source straight in. No command-line override is needed.
  `Demo/sample.md` is the rendering test corpus, and the closest thing to a
  regression suite for anything visual (the DUnitX tests deliberately cover
  only the non-visual layer). **When you fix a rendering bug, add a case for it
  here** — a fix verified only against a scratch file can silently regress. It
  already covers multi-character super/subscripts and inline images for exactly
  that reason.

  `Demo/commonmark-gaps.md` is its counterpart: constructs that are **known not
  to render correctly**, with expected-vs-actual for each. Move a case into
  `sample.md` once it works. See "CommonMark gaps" below.
- `MDViewerEditor/` — `MarkDownViewerEditorProject.dproj`, a live side-by-side
  editor: a left `TMemo` and a right `TRhoMarkdownViewer` split by a
  `TSplitter`. The **View** button (and the sample combo) push the memo text into
  `MarkdownText`; **Open** loads a `.md` file. `ufMain.pas` wires two things worth
  knowing about:
  - **Two-way scroll sync** — `Memo1.OnViewportPositionChange` ↔ the viewer's
    `OnScroll`, mapped proportionally by fraction-of-scrollable-range, guarded by
    an `FSyncing` re-entrancy flag. ⚠️ `MemoViewportChange` **ignores events with
    `ContentSizeChanged = True`**: setting `Memo1.Text` posts a *deferred*
    viewport-change that a synchronous guard cannot cover, and syncing on it
    yanked the viewer half a line. Do not remove that check.
  - **Task toggle mirror** — `AllowTaskToggle` is on, and `OnTaskToggle` copies
    the viewer's rewritten source back into the memo (the viewer owns the source
    of truth once a checkbox is clicked).
  - **Find bar** — `FindBar`, a Top-aligned `TLayout`, hidden until **Edit ▸
    Find…** (Ctrl+F). It is the reference example of the host's half of the find
    split: term, two option checkboxes, Prev/Next, and a `n of m` counter driven
    solely by `OnSearchChange`. Typing searches incrementally — the host calls
    `FindNext` after each assignment, because the component deliberately does
    not scroll on `SearchText :=`.
    ⚠️ **`TMenuItem.ShortCut` is a `TShortCut` (an integer), not a string.**
    Writing `ShortCut = 'Ctrl+F'` in the `.fmx` streams as *Invalid property
    value* and takes the **whole form** down — the app then exits at startup
    with no window and no message, which reads like a build problem rather than
    a form problem. `FormCreate` sets it via `TextToShortCut` instead.

  `uExamples.pas` holds the sample documents shown in the combo (`GetExample1..5`).
  **`GetExample5` ("Containers & HTML") is the showcase for the container-block
  and inline-HTML work** — nested quotes, list-in-quote, quote-with-code,
  multi-paragraph items, code-in-item, indented code blocks, and the HTML
  whitelist. ⚠️ These are Delphi multi-line string literals (`'''`): the closing
  delimiter's column sets a margin stripped from every line, so **markdown-
  significant indentation (indented code, list continuation) must be added on top
  of that margin** in the source. The combo loads them as raw text with no
  `BasePath`, so `<img>` there falls back to alt text — use **Open** on a real
  file (e.g. `Demo/sample.md`) to see image loading and sizing.
- `Tests/` — `RhoMarkdownTests.dpr`, a console DUnitX runner. See below.

## Design-time requirements

The component must be installable and fully designable.

- **All designer-facing properties `published`.** `TControl` keeps
  `Align` / `Anchors` / `Size` / `Position` / `Visible` / `Enabled` / `TabOrder`
  **public**, so a directly-derived control must re-publish them or it cannot be
  laid out in the designer.
- 🔴 **A greyed-out palette entry is almost certainly the runtime package's
  missing `{$R *.res}`** — see the Packages section. It is not the library path,
  the target-platform lists, or the class group.
- ⚠️ **The form designer renders through the INSTALLED `.bpl`, not `Source\`.**
  Two copies of the component code are live at once and go stale
  independently: an application links the units from `Source\` and picks up a
  change as soon as you rebuild the app, but the designer keeps rendering the
  package until you rebuild **and reinstall** it. So after changing anything
  visual — a palette colour, a layout constant — the running app updates and the
  design-time preview does not, which looks like the change "didn't take". If
  they disagree, compare timestamps: `Source\*.dcu` against
  `%PUBLIC%\Documents\Embarcadero\Studio\37.0\Bpl\*.bpl`.
- ⚠️ **`Size` is the property that streams — not `Width`/`Height`.** `TControl`
  declares those two `stored False`; they are convenience accessors. Publishing
  them but omitting `Size` makes every form holding the component fail to load
  with `Error reading Viewer.Size.Width: Property Size.Width does not exist`.
  This was a real defect, caught only by the streaming test below.
- `TAlphaColor` properties take no `default` (the constant exceeds `MaxInt`);
  neither can `Single` properties such as font size.
- Every colour / font / display property is a **live setter** — repaint, or
  rebuild metrics and re-lay-out. A plain field write silently does nothing;
  this was a real bug in RhoEditor.
- Register with `RegisterComponents('Rhody Controls', [TRhoMarkdownViewer])`.

## Tests

`Tests/RhoMarkdownTests.dpr` — **148 tests, all passing.** Console app, no FMX or
Skia dependency, so the parse layer stays testable without a UI.

```
msbuild Tests\RhoMarkdownTests.dproj /t:Build /p:Config=Debug /p:Platform=Win64
Tests\RhoMarkdownTests.exe --exitbehavior:Continue
```

Note the `.dproj` puts the exe beside the `.dpr`, not under `Win64\Debug\` —
unlike the demo. Stale `Win64\` copies from earlier `dcc64` builds may still be
lying around; run the one next to the `.dpr`.

Ported: `Test.RhoMarkdown.Parser.pas`, `Test.RhoMarkdown.Highlight.pas`,
`Test.RhoMarkdown.Html.pas`, `Test.RhoMarkdown.Model.pas`.

### Design-time streaming test

`Tests/DesignStream/DesignStreamTest.dpr` loads a form whose `.fmx` declares a
`TRhoMarkdownViewer`, then prints PASS/FAIL. It is the **only** coverage of the
design-time path — everything else in the project creates the viewer in code,
which never goes near form streaming.

It checks that the class resolves by name (no `RegisterFmxClasses` is needed —
verified), that published properties and `Markdown` arrive, that `Loaded`
parses them, and that the control ends up with **exactly one** paint box and
one scrollbar. That last check is the `Stored := False` guarantee: without it
the constructor creates the children and streaming creates them again.

```
msbuild Tests\DesignStream\DesignStreamTest.dproj /t:Build /p:Platform=Win64
Tests\DesignStream\DesignStreamTest.exe
```

Run it after changing the published property surface, the constructor, or
`Loaded`. Note it constructs the form directly rather than via
`Application.CreateForm`, which routes streaming errors through
`Application.HandleException` and hides them behind a nil variable.

Dropped in the port: the VCL project's `Test.MarkdownViewer.Renderer.pas` and
`Test.MarkdownViewerVCL.pas` — they assert GDI integer-pixel metrics and
paint-path behaviour that the rewrite deletes; Skia's float metrics will not
reproduce them. Also `NewBlockHasInvalidLayout`, which tested the `Layout*`
fields that no longer live on the block.

### Antimony

`TAntimonySyntaxHighlighter` covers Antimony, the human-readable SBML model
definition language, under the fence tags `antimony`, `ant` and `sb`.
Case-sensitive; `//` and `#` line comments plus `/* */` blocks, matching the
rules RhoEditor's `UseAntimony` sets.

Beyond keywords it marks the two things an Antimony reader looks for first, both
as `stType`: **reaction/rule labels** (the identifier before `:` in
`J0: S1 -> S2; k1*S1`, distinguished from the `:=` of an assignment rule) and
**boundary species** (`$Xo`).

Its keyword list is a copy of `AntimonyKeywords` in RhoEditor's
`uLanguageKeywords.pas` — **keep the two in step** if either gains a word.

**Do not drop the highlighter tests.** `TestTokenStreamInvariants*` enforces
that every lexer tiles its input exactly: contiguous, gap-free, non-zero-length
tokens whose concatenation reproduces the source. A lexer that emits a
zero-length token without advancing **hangs the render loop** — that is a
property of the lexer, not the paint backend, so the hazard survives the port
intact. Add new languages to those tests.

## Build

Delphi 13 = RAD Studio **37.0**. Several Studio versions are installed
side-by-side; 37.0 is the correct one. Do not infer the version from
`ProjectVersion` in a `.dproj` — that metadata is stale.

Source `rsvars.bat` before `msbuild`; a non-interactive shell does not run the
user profile.

**Demo** (Win64):

```
cmd /c '"C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild Demo\MarkDownViewerProject.dproj /t:Build /p:Config=Debug /p:Platform=Win64'
```

Output: `Demo\Win64\Debug\MarkDownViewerProject.exe`. A successful build ends
with `NNNNN lines, N.NN seconds, ... bytes code`.

**Packages** — Win32, runtime first.

Delphi 13 ships **both** a 32-bit IDE (`bin\bds.exe`) and a 64-bit one
(`bin64\bds.exe`). This setup uses the **32-bit** IDE, so the design package is
Win32. A design package must match the bitness of the IDE that loads it, and the
runtime package must match the design package — `dclRhoMarkdownViewer` has
`requires RhoMarkdownViewer`, so it cannot link or load without it.

**A Win32 runtime package build is therefore required even though applications
here are Win64.** The two are unrelated: applications link the units statically
through `DCC_UnitSearchPath` (see `Demo/`) and need no package build at all. The
runtime package exists purely to satisfy the design package. Both do build clean
for Win64 if the 64-bit IDE is ever used instead.

```
msbuild Packages\RhoMarkdownViewer.dproj    /t:Build /p:Config=Debug /p:Platform=Win32
msbuild Packages\dclRhoMarkdownViewer.dproj /t:Build /p:Config=Debug /p:Platform=Win32
```

⚠️ `F2039: Could not create output file ...` is always a **file lock, not a
project error**. Two ways to hit it: a package `.bpl` held open by an IDE with
the design package installed, and the demo `.exe` held open by a running (or
IDE-debugged) instance. Close the holder, or redirect the outputs:

```
msbuild Packages\RhoMarkdownViewer.dproj /t:Build /p:Config=Debug /p:Platform=Win32 /p:DCC_BplOutput=.\Win32\Verify /p:DCC_DcpOutput=.\Win32\Verify /p:DCC_DcuOutput=.\Win32\Verify
```

## Conventions

- Object Pascal, FMX. Target Windows + macOS; every feature must behave
  identically on both. If it can't, the approach is suspect.
- Keep parser / highlighter / HTML logic in their own units, never in the
  control — the VCL version's discipline, worth preserving.
- Prefer lazy work: lay out and tokenize only what is visible.
- Tokenization is cached per block and computed once (`HighlightTokens` in the
  model). The paint path must use that accessor, never re-tokenize per repaint.
- **Verify rendering with `Tools/MarkdownRender`, not the demo GUI.** It renders
  a markdown file to a PNG through the real layout and paint path, with no
  window involved — write a small `.md` exercising the feature under test,
  render it, and look at the PNG. Far less fragile than driving the GUI (see the
  screenshot traps below).

  ```
  msbuild Tools\MarkdownRender\MarkdownRender.dproj /t:Build /p:Config=Debug /p:Platform=Win64
  Tools\MarkdownRender\MarkdownRender.exe input.md output.png [width] [fontSize] [links|select|dark|html|anchors|search <term>]
  ```

  The optional fifth argument switches on a verification mode: `links` tints
  every point where `LinkAt` reports a link, `select` selects all and dumps both
  copy forms, `dark` renders with the dark theme.

  It works because `MeasureDocument` and `RenderToCanvas` take their width
  explicitly and never touch `FContent`, so the viewer runs unparented. Keep
  those two free of paint-box dependencies.

### Theming and colours

`ApplyTheme(rtLight | rtDark)` sets every colour surface from one curated
palette, syntax colours included, in a single call.

**It is a method, not a published property** — deliberately, and for the same
reason RhoEditor made the same choice. A published `Theme` would re-apply on
`.fmx` load and clobber colours the host had set by hand. Every colour stays
individually overridable after the call.

`SyntaxColors` is a published `TRhoSyntaxColors` (a `TPersistent`), so the eight
token-kind colours are settable in the Object Inspector and stream into the
`.fmx`. `TRhoSyntaxColors.ApplyTheme` is the **one place** syntax colours are
defined — put a per-language variant there, not at a call site.

**`TAlphaColors.Null` means "unset, follow `TextColor`".** `TAlphaColor`
properties cannot declare a `default`, so a streamed value is otherwise
indistinguishable from an untouched one; the sentinel is what lets a colour the
host never set follow the theme while an explicit one always wins. `PlainColor`
uses this.

A colour change is a **re-layout, not a repaint** — colours are baked into
paragraphs when they are built. `SyntaxColorsChanged` calls `InvalidateLayout`
for that reason. (The background is the one exception: it is painted directly.)

Check dark mode with the render tool, or the demo's Theme button:

```
Win64\MarkdownRender.exe sample.md dark.png 760 14 dark
```

### Hit-testing

**`ISkParagraph` range indices are UTF-16 code units** — verified empirically,
not assumed. `AddText` marshals the Delphi string to UTF-8 and the binding
passes range indices through with no translation, so it is reasonable to expect
UTF-8 byte offsets. It is not: a probe over `'AB' + U+1F600 + 'CD'` (6 UTF-16
units, 8 UTF-8 bytes) showed `GetRectsForRange(0, N)` first covering the whole
string at **N = 6**, and `range(0,3)` clamping to `range(0,2)` mid-surrogate.
So Delphi's native 0-based string offsets work directly. Getting this wrong
would misplace hit zones only in documents containing non-ASCII — a nasty
latent bug, so re-verify before changing anything here.

Link geometry is resolved **once at layout time** (`CollectLinkRects`), not per
mouse event: `BuildTokens` records each link token's character span, and those
spans become rects via `GetRectsForRange`. A link wrapped across lines yields
several rects, which is why `TRhoLinkHit.Rects` is an array. Rects are stored as
absolute X (horizontal never scrolls) and Y relative to the block's `Top`, so
`LinkAt` just adds `Top - ScrollY`.

Verify hit zones with the render tool's `links` mode, which probes `LinkAt` on a
grid and tints every cell that reports a link — testing the real API rather than
an internal copy of it:

```
Win64\MarkdownRender.exe links.md out.png 700 14 links
```

### Selection and copy

A position is a `TRhoDocPos` — block index plus offset into that block's
rendered text — which orders naturally, so selection comparisons are trivial.
`PosAt` maps a point via `GetGlyphPositionAtCoordinate`.

**Markdown copy slices the original source; it does not reconstruct markdown
from styling.** `BuildTokens` records, per rendered character, the offset it
came from in the markdown source (`CharSource`, from the model's per-token
`SourceMap`). `SelectedText(False)` maps the selection ends back through that
and copies the source range verbatim, so `**bold**`, `[a](b)`, `&copy;` and
`:smile:` all come back exactly as written. Characters with no source (a
decoded entity's replacement, a synthetic break) hold -1, which is why
`SourceOffsetAt` scans outwards for the nearest mapped neighbour. Plain-text
copy slices `PlainText` instead. If the source mapping is unusable, markdown
copy falls through to plain text rather than returning nothing.

**Drag-select needs two things that are easy to miss, and each fails silently:**

- **`FContent.AutoCapture := True`** (RhoEditor does this too). Without it the
  paint box stops sending `MouseMove` the moment the pointer leaves it, so a
  drag dies at the edge. With it, `PosAt` starts receiving negative and
  past-bottom Y values — which is why it clamps to the document start/end
  rather than returning an invalid position.
- **A timer drives the edge auto-scroll**, not `MouseMove`. Holding the pointer
  still just outside the edge produces no mouse events at all, so without
  `FAutoScrollTimer` the view scrolls one step and stops. Each tick also
  re-evaluates `FSelCaret`, because the document moved under a stationary
  pointer. The timer disables itself when the scroll clamps at either end,
  rather than spinning.

**A list item's marker reaches plain-text copy via `CopyPrefix`, not
`PlainText`.** Markers are drawn as a separate `Marker` paragraph, so putting
them in `PlainText` would make it longer than Skia's paragraph text and skew
every selection and link offset in the block — the same trap as the
placeholder bookkeeping. `CopyPrefix` holds the nesting indent plus `• `,
`N. `, or `[x] `/`[ ] `, and `SelectedText` prepends it only when the item is
taken from offset 0, so a selection starting mid-text does not sprout a bullet.
Markdown copy is unaffected: it slices the source, which already has the marker.

Verify copy deterministically with the render tool's `select` mode — it selects
all, re-renders so the highlight shows, and dumps both copy forms:

```
Win64\MarkdownRender.exe sel.md out.png 600 14 select
```

Non-ASCII in that dump may look mangled in the console; that is the console
codepage, not the data.

### Find

The component owns the **mechanism** — matching, highlighting, scrolling a hit
into view — and the host owns the **find bar**. That split is forced, not
stylistic: matching needs `FLayout[].PlainText`, highlighting needs
`GetRectsForRange` plus a hook in the paint pass, and none of it is reachable
from outside. The UI, by contrast, needs no privileged access, and baking one in
would fight every host's styling. Same reasoning as `ApplyTheme` being a method.

API: `SearchText`, `SearchCaseSensitive`, `SearchWholeWords`,
`SearchHighlightColor`, `SearchCurrentMatchColor` (all published),
`SearchMatchCount` / `SearchMatchIndex` (public, read-only), `FindNext`,
`FindPrevious`, `ClearSearch`, and `OnSearchChange`. `F3` / `Shift+F3` are
handled in `KeyDown` when a search is active.

**Matching runs over the rendered text, never the source** — searching the
markdown would find `**bold**` for "bold" at an offset corresponding to nothing
on screen, and would match link URLs and entity names the reader cannot see.

**Within-block by design.** A phrase spanning a paragraph break is not found.
Cross-block would need a flattened document string plus a block-offset index;
the simple model covers what a reader types. `TRhoSearchMatch` is
`(Block, Start, Len)` rather than a `TRhoDocPos` pair *because* of that.

Load-bearing details:

- **`FSearchIndex` deliberately survives a re-layout, `FSearchMatches` does
  not.** Matches index into `FLayout`, so `InvalidateLayout` drops them; but
  `PlainText` does not depend on the width, so the rebuilt list is identical
  after a resize and keeping the index keeps the reader's place.
- **`OnSearchChange` must never fire from the paint pass.** `PaintDocument`
  calls `EnsureSearchMatches` (which is silent); every other entry point calls
  it and then `DoSearchChange`. A host updating a label from inside a Skia draw
  is asking for re-entrancy.
- **Setting `SearchText` highlights but does not scroll.** An incremental find
  bar assigns on every keystroke; yanking the view each time is unusable. The
  host calls `FindNext` to move.
- **`FoldCase` is per-character (`Char.ToLower`), not `SysUtils.LowerCase`.**
  A locale-aware lower-case can change a string's *length* for some scripts,
  which would put every match offset out of step with the paragraph it indexes.
- **`CollectRangeRects` is the one place a character range becomes geometry.**
  Selection and search both go through it, so a block kind that highlights for
  one highlights for the other. Add a multi-paragraph block kind there — a
  `(paragraph, TextStart, TextLen, originX, originY)` slice per paragraph — and
  both work at once. (It replaced two near-identical copies that had already
  drifted: front-matter cards highlighted in neither.)
- 🔴 **Paint order per block is chrome → highlights → text.** Tables and
  front-matter cards therefore draw in **two** passes each
  (`PaintTableChrome`/`PaintTableText`,
  `PaintFrontMatterPanel`/`PaintFrontMatterText`), so their text lands above the
  highlight layer. Merge either back into one pass and its text goes *under* the
  highlight — invisible under an opaque current-match colour, and merely tinted
  under a translucent selection, which is why it can hide for a long time.

Verify with the render tool's `search` mode, which reports the match count
under each option combination and renders the highlights (`dark` composes with
it):

```
MarkdownRender.exe doc.md out.png 760 14 search alpha [dark]
```

### Tables

Three passes in `LayoutTable`: natural column widths from each cell's
`MaxIntrinsicWidth`; proportional scale-down if they overflow the content
width; then lay every cell out at its final column width and stack the rows.
Row height is the tallest cell plus padding, applied back to every cell so a
row shares one bottom edge.

⚠️ **Column widths need a pixel of slack.** Laying a cell out at exactly its
`MaxIntrinsicWidth` makes Skia's line breaker wrap the last word on float
rounding — `$100.00` renders as `$100.0` over `0`. `LayoutTable` uses
`Ceil(MaxIntrinsicWidth) + 1`. Don't "simplify" that back.

Cell tokens are **not** cached on a block (a cell is not a block), so
`BuildCellText` owns the `TMarkDownInlineList` it parses and must free it.

**Selection flattens a table rather than complicating `TRhoDocPos`.** The block's
`PlainText` is every cell joined with a TAB between cells and a newline between
rows, and each `TRhoTableCell` records its `TextStart`/`TextLen` slice of it. So
a table behaves like any other block for selection, and `PaintSelection`
intersects the selected range with each cell to highlight them individually.
Tab-separated is deliberate: it pastes straight into a spreadsheet, and it is
what the VCL predecessor did.

A table's `CharSource` is -1 throughout, because cell tokens are parsed without
a source map. That is intentional, not a gap: `SourceOffsetAt` scans outwards,
so a selection covering a table *and* its neighbours still yields correct
verbatim markdown, while a table-only selection falls back to the tab-separated
plain text — which is the more useful result for a table anyway.

### YAML front matter — the metadata card

A `---` block on the very first line, closed by `---` or `...`, is parsed as
`bkFrontMatter` (raw inner YAML in `Block.Text`) and rendered as a two-column
**metadata card** — a tinted panel (`CodeBackgroundColor`, so it themes) with
bold keys beside wrapping values. Common in `skill.md` / Jekyll docs, which
otherwise turned the closing `---` into a stray setext heading.

Detection lives at the top of `ParseBlocks`, gated on **`MapSource`** (top-level
document parse only, never a recursive container call) **and** the first line —
and it requires a closing fence, so a leading `---` with none falls through and
stays a thematic rule (`ParseBlocksLoneDashesAreRule` guards this). `ParseBlocks`
reuses its `ContentCol` / `Number` locals as the scan cursor.

Layout (`LayoutFrontMatter`) parses the YAML shallowly (`ParseFrontMatterPairs`:
top-level `key: value`, indented/colon-less lines folded into the previous value,
surrounding quotes stripped — not a YAML engine) and lays it out like a
borderless two-column table stored in `TRhoBlockLayout.MetaRows`. Paint is
`PaintFrontMatter` (tinted round-rect + each row's two paragraphs), hooked into
`PaintDocument` beside `PaintTable`. ⚠️ **The key column needs a pixel of slack**
(`Ceil(MaxKeyW) + 1`) — laying a key out at its exact intrinsic width makes Skia
wrap the last glyph, the same float-rounding trap documented for table columns.

`PlainText` is set to reconstructed `key: value` lines, so the card is
selectable and copies cleanly; no source map (fallback). HTML export emits it as
`<pre><code>` alongside `bkCodeBlock`. Each `TRhoMetaRow` records
`KeyStart`/`KeyLen` and `ValueStart`/`ValueLen` — its slice of that flattened
text, exactly as `TRhoTableCell` does — which is what lets selection and search
*highlight* the card rather than silently drawing nothing. The `': '` separator
belongs to neither paragraph and so never highlights, the same way a table's
TAB separators do not.

### Anchor links

In-page links (`[text](#some-heading)`) scroll to the matching heading.
`RhoHeadingSlug` (a plain function in `uRhoMarkdownViewer`, exported so a host can
build a table of contents) implements GitHub's slug rule: lower-case, drop
everything that is not a letter/digit/space/hyphen/underscore, spaces become
hyphens. `Char.IsLetterOrDigit` is Unicode-aware, so accented headings slug
sensibly instead of losing characters.

`FindAnchor` slugs the **rendered** text (`FLayout[].PlainText`), not
`Block.Text`, so inline markup in a heading (`## **Bold** heading`) does not leak
into the anchor — matching GitHub. Repeated headings disambiguate as `slug`,
`slug-1`, `slug-2`. `ScrollToAnchor` is public and returns whether it resolved.

**Routing:** `DoLinkClick` sends every link to `OnLinkClick` when a handler is
assigned, so a host keeps full control (and can call `ScrollToAnchor` itself).
With no handler, a `#…` target navigates internally and **never reaches
`OpenUrl`** — handing `ShellExecute` a bare fragment silently does nothing, which
is exactly what made anchor links look broken before.

⚠️ **`EnsureLayoutForCurrentWidth` must not re-lay-out over a valid layout.**
Headless callers (`MeasureDocument` / `RenderToCanvas`) lay out at an explicit
width with the control unparented, where `FContent.Width` is meaningless —
measuring off it there would rebuild the document at ~1px and throw the real
layout away. It returns early when `FLayoutValid`.

Verify with the render tool's `anchors` mode, which lists every heading with its
slug and checks each resolves through the real `ScrollToAnchor`:

```
MarkdownRender.exe README.md out.png 800 14 anchors
```

### Image titles — two separate code paths

🔴 **An image destination must have its optional title stripped, in BOTH the
block and inline branches.** `![alt](url "title")` is parsed in two unrelated
places: `TryParseImage` (block, used by `ParseBlocks`) and the `!` branch of
`ParseRuns` (inline). Fixing one leaves the other broken — that is exactly how
this bug survived: the inline branch was fixed first and block images still
failed.

Links strip the title via `LinkDestination`; images must do the same.
`TryParseImage` is declared *above* `LinkDestination` in the unit, so it carries
an inline copy of the same "cut at the first space" rule — keep the two in step.

Leaving the title on put `url "title"` into the path, which not only failed to
resolve but **raised `EInOutArgumentException` out of `TPath.GetFullPath`** and
crashed the host. `ResolveImagePath` now wraps the `Combine`/`GetFullPath` pair
in a `try/except` returning `''`, because a markdown document is untrusted input
and a malformed destination must degrade to alt text, never propagate. Both paths
are covered by `ParseBlocksStripsImageTitle` / `ParseInlineStripsImageTitle`.

### Text encoding

🔴 **`LoadFromFile` must pass `TEncoding.UTF8` explicitly.**
`TStrings.LoadFromFile` without an encoding falls back to `DefaultEncoding` —
`TEncoding.Default`, i.e. **ANSI/CP1252 on Windows** — whenever the file has no
BOM. Most markdown is BOM-less UTF-8, so every multi-byte character was being
split into its raw bytes: `Levenberg–Marquardt` (en dash U+2013 = `E2 80 93`)
rendered as `Levenbergâ€"Marquardt`, and em dashes, curly quotes, `±`, `µ`, `é`,
arrows and emoji were all mangled the same way.

Passing `TEncoding.UTF8` is *not* "force UTF-8": `TEncoding.GetBufferEncoding`
still detects and honours a BOM when present, overriding the argument. So the
one call reads BOM-less UTF-8, UTF-8-with-BOM and UTF-16 correctly. UTF-8 is the
right default for markdown; a genuinely ANSI file degrades to replacement
characters, which is the acceptable trade.

The symptom is easy to misread as a font-fallback problem — it is not. If
non-ASCII renders as two or three Latin-1 letters, suspect the read encoding
first. Host code that reads a file itself (the demo's `TFile.ReadAllText(...,
TEncoding.UTF8)`) already specifies it correctly.

### Images

`ImageFor` decodes through a `TSkImage` cache keyed on the resolved absolute
path. **A key present with a nil value is a remembered failure** — that is what
stops a broken path being retried on every re-layout, so don't "fix" the nil
check. Remote URLs are deliberately never fetched: layout must not do network
I/O. Missing, unreadable, and remote images all fall back to italic alt text.

Images scale down to the content width and are never upscaled **unless an HTML
`<img>` gives an explicit `width`** (see the inline-HTML section) — that path
honours the requested size and may upscale, but still clamps to the content
width so it can't overflow. `LoadFromFile` sets `BasePath` to the markdown
file's folder before assigning the text, since image paths resolve during the
layout that assignment triggers. `ResolveImagePath` strips a leading `/` (or
`\`) and resolves against `BasePath`, so a root-relative `src="/Images/x.png"`
(the way GitHub renders a README) finds the file relative to the document
folder rather than the drive root.

**Inline images** (`![alt](url)` inside a paragraph) required parser and model
work, not just viewer work: `ParseInline` had no image handling at all, so `!`
came out as literal text and `[alt](url)` parsed as an ordinary link. The parser
now emits an `IsImage` token (checked **before** the link branch, or the `[`
wins), and the viewer turns it into `AddPlaceholder`, reading the rects back
with `GetRectsForPlaceholders` after layout — Skia decides where they sit in
the flow.

⚠️ **`AddPlaceholder` already inserts its own position into the paragraph
text.** Emitting an object-replacement character alongside it draws a stray
`OBJ` glyph *and* double-counts the offset. But the bookkeeping still has to
advance by one, or every link span and selection offset after the image is
skewed — hence `Emit`'s `AToBuilder` parameter, which updates `PlainText` /
`CharSource` / `Pos` without calling `AddText`. Verified with the render tool's
`links` mode: a link placed after an inline image still hit-tests exactly.

An unloadable inline image falls back to italic alt text.

### Inline HTML whitelist

A deliberately small set of inline HTML is interpreted; everything else stays
literal (the safe default the VCL predecessor also used). All of it lives in
`ParseRuns` (`uRhoMarkdownParser.pas`), mapping onto inline primitives that
already existed — **no new styling model, no CSS**:

- **Formatting tags → the style stack / flags:** `<b> <strong>` → `fsBold`;
  `<i> <em>` → `fsItalic`; `<u> <ins>` → `fsUnderline`;
  `<s> <del> <strike>` → `fsStrikeOut`; `<mark>` → highlight; `<sub>`/`<sup>` →
  the sub/superscript baseline shift; `<code>`/`<kbd>` → an `IsCode` run (inner
  text **not** re-parsed, like backticks). `<br>`/`<br/>`/`<br />` → a line break.
- Each formatting tag recurses `ParseRuns` on its inner text with the augmented
  style and a `SubMap` slice, exactly like `**`/`~~`/`==`, so **nesting and
  source mapping just work** (`<b>x <i>y</i></b>` → bold, then bold+italic).
- **`<img>`** is the one member that parses attributes (`src`, `alt`, `width`,
  `height`) via `GetHtmlAttr`, and carries an explicit size on the token
  (`ImgWidth`/`ImgWidthPct`/…). `width="80%"` is a fraction of content width;
  `width="80"`/`"80px"` is pixels. It reuses the inline-image placeholder path;
  a stray `</img>` after it is consumed. See the Images section for sizing.

**Excluded on purpose — do not add without a reason:** any attributed
formatting tag (`<span style>`, `<a href>`, `<font>`), and `<script>`,
`<iframe>`, etc. `TryParseOpenTag` skips over quoted attribute values so a `>`
inside an attribute doesn't end the tag early, but an **unknown tag or an opener
with no matching close is left literal** — never interpreted, never stripped.
Block-level `<details>`/`<summary>` is a possible future addition (needs block
parsing + an interactive collapse state) and is out of scope for now.

⚠️ **HTML *export* (`AsHtml`) still escapes these tags** — the whitelist is a
*viewer/parser* feature (`ParseInline`); `EmitInline` in `uRhoMarkdownHtml.pas`
was not changed, so a `<b>` in the source round-trips to `&lt;b&gt;` in exported
HTML. Wire pass-through there if export fidelity ever matters.

### Super and subscript

`ISkTextStyle` has no baseline shift, so `^sup^` / `~sub~` runs are laid out
separately and spliced in as placeholders, whose `BaselineOffset` does the
raising and lowering (`TRhoPlaceholder` carries either an image or one of these
sub-paragraphs).

**One placeholder per character, not one per run.** A placeholder occupies
exactly one position in the paragraph, so a per-character split keeps
`PlainText` the same length as Skia's text — link and selection offsets stay
aligned — while the real characters, not `U+FFFC`, land in the copy buffer. A
single placeholder for a whole run desynchronises the two for anything longer
than one character, which is precisely the case chemistry needs
(`C~6~H~12~O~6~`). The cost is no kerning within a run, negligible for the
digits these nearly always are.

Runs containing a surrogate pair are excluded and render unshifted: such a
character spans two positions and would break that alignment.

### Screenshotting the running demo

Two traps here, both of which silently produce a *wrong but plausible* result
rather than an error:

- **`Process.MainWindowHandle` returns the wrong window.** FMX creates a hidden
  0x0 top-level window carrying the *same caption* as the real form, and that is
  usually what `MainWindowHandle` (and `FindWindow` by title) returns.
  `GetWindowRect` then succeeds and reports 0x0. Enumerate the process's
  top-level windows and take the first **visible** one with a real size.
- **Synthetic `WM_MOUSEWHEEL` does nothing.** FMX routes wheel input to its
  `Hovered` control, and `Hovered` is only set by genuine pointer movement, so a
  `SendMessage` wheel has no target and is dropped silently. Warp the real cursor
  over the window with `SetCursorPos`, then use `mouse_event(MOUSEEVENTF_WHEEL)`.

Also: before concluding "scrolling is broken", check the document is actually
taller than the viewport. A short sample fits entirely, and *correctly* does not
scroll.

Two more, learned the hard way:

- **A GUI app launched from a tool shell dies when that shell exits.** Launch,
  drive and screenshot must all happen inside **one** shell invocation, or the
  process is gone before the next call runs.
- 🔴 **`SendKeys` types into whatever window has focus, which may not be the
  app.** It went into the user's terminal instead, mid-session. Prefer the
  headless render tool for anything it can verify; if the GUI genuinely must be
  driven, post messages to a specific `HWND` rather than synthesising global
  keystrokes, and never leave focus-stealing automation running unattended.

## Non-goals

- Not a full CommonMark implementation. This is for help text, notes, preview
  panes, and embedded documentation.
- No WebView, no HTML rendering path, no embedded browser.
- No RTF or rich embedded objects beyond images.

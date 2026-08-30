// ============================================================================
//   uRhoMarkdownMath -- LaTeX math rendering for TRhoMarkdownViewer.
//
//   Wraps the RaTeX engine (pure Rust, KaTeX-compatible). RaTeX parses and lays
//   a formula out, returning a "display list": positioned glyphs, rules and
//   paths, all in em units. This unit decodes that list and replays it onto an
//   ISkCanvas using the KaTeX TrueType faces.
//
//   OPTIONAL BY DESIGN. The library is loaded dynamically, never linked, so an
//   application that does not need math ships neither the shared library nor
//   the fonts and pays nothing. When either is absent RhoMathAvailable returns
//   False and the viewer renders the LaTeX as literal text - the feature
//   degrades, it never fails.
//
//   To use math, deploy beside the executable:
//     Windows   ratex_ffi.dll
//     macOS     libratex_ffi.dylib
//     fonts\KaTeX_*.ttf          (all 20 faces)
//
//   Both locations are overridable - see RhoSetMathLibraryPath / RhoSetMathFontDir.
//
//   Ported from the RenderLaTeX project's uRaTeX.pas, which in turn follows
//   RaTeX's own tiny-skia rasterizer (crates/ratex-render/src/renderer.rs).
//   Two things there are load-bearing and non-obvious; see MathAlphaNumeric and
//   DrawPathItem below.
// ============================================================================

unit uRhoMarkdownMath;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.IOUtils, System.Generics.Collections, System.JSON, System.Skia;

type
  /// <summary>A parsed and laid out formula. Geometry is in em units, so it is
  /// independent of both font size and control width - which is why a cached
  /// layout survives every re-layout and resize. Multiply by the font size for
  /// pixels; the baseline sits at HeightEm below the top of the box.</summary>
  TRhoMathLayout = class
  private
    FRoot: TJSONObject;
    FItems: TJSONArray;
    FWidthEm: Double;
    FHeightEm: Double;
    FDepthEm: Double;
  public
    constructor Create(const AJson: string);
    destructor Destroy; override;
    /// <summary>Pixel size of the formula at the given font size.</summary>
    function SizeAt(const AFontSize: Single): TSizeF;
    property WidthEm: Double read FWidthEm;
    property HeightEm: Double read FHeightEm;   // top of box to baseline
    property DepthEm: Double read FDepthEm;     // baseline to bottom of box
    property Items: TJSONArray read FItems;
  end;

/// <summary>True when the RaTeX library AND the KaTeX fonts were both found.
/// Everything else in this unit is a no-op when this is False, so callers can
/// simply fall back to rendering the LaTeX as text.</summary>
function RhoMathAvailable: Boolean;

/// <summary>Full path to the RaTeX shared library. Set it before the first
/// math is rendered; the default is the platform's library name beside the
/// executable, then the system search path.</summary>
procedure RhoSetMathLibraryPath(const APath: string);

/// <summary>Folder holding the KaTeX_*.ttf faces. Defaults to "fonts" beside
/// the executable.</summary>
procedure RhoSetMathFontDir(const ADir: string);

/// <summary>Lay a formula out, or nil if math is unavailable or the LaTeX does
/// not parse. The result is CACHED and owned by this unit - do not free it.
/// Layout is the expensive call and its result is WIDTH-independent, so the
/// cache survives every resize and re-layout, which is what keeps them cheap.
///
/// AColor is baked into the display list, because RaTeX colours every item as
/// it lays out and gives no way to say "unset" - so it has to be part of the
/// cache key. That matches the viewer's own rule that a colour change is a
/// re-layout rather than a repaint.</summary>
function RhoMathLayout(const ALatex: string; const ADisplay: Boolean;
  const AColor: TAlphaColor): TRhoMathLayout;

/// <summary>Replay a layout onto the canvas. (AX, AY) is the top-left of the
/// formula's bounding box. AColor covers any item that carries no colour of its
/// own; in practice RaTeX colours them all, from the colour passed to
/// RhoMathLayout.</summary>
procedure RhoMathDraw(const ACanvas: ISkCanvas; const ALayout: TRhoMathLayout;
  const AX, AY, AFontSize: Single; const AColor: TAlphaColor);

/// <summary>Drop every cached layout. The viewer calls this when the document
/// is reparsed, so the cache stays bounded by one document's formulas.</summary>
procedure RhoMathClearCache;

/// <summary>The last parse error, for diagnostics.</summary>
function RhoMathLastError: string;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows;
{$ELSE}
  Posix.Dlfcn;
{$ENDIF}

{ ---------------------------------------------------------------------------
  The RaTeX C ABI. See crates/ratex-ffi/include/ratex.h for the contract.

  Loaded dynamically rather than declared external, so a missing library is a
  runtime condition we can report - not a load-time failure that would take the
  whole application down for a feature it may not use.
  --------------------------------------------------------------------------- }

type
  TRatexColor = record
    r, g, b, a: Single;   // normalised 0..1
  end;
  PRatexColor = ^TRatexColor;

  // Field layout must match the C struct exactly: size_t, int (+4 bytes of
  // padding), pointer = 24 bytes. Left UNPACKED deliberately - Delphi's default
  // alignment reproduces that, whereas packing it would give 20 and RaTeX would
  // then ignore the colour field, which it gates on struct_size.
  TRatexOptions = record
    struct_size: NativeUInt;
    display_mode: Integer;  // 0 = inline, 1 = display block
    color: PRatexColor;     // nil = black
  end;
  PRatexOptions = ^TRatexOptions;

  TRatexResult = record
    data: PAnsiChar;        // JSON display list, or nil on failure
    error_code: Integer;
  end;

  TRatexParseAndLayout = function(latex: PAnsiChar;
    opts: PRatexOptions): TRatexResult; cdecl;
  TRatexFreeDisplayList = procedure(json: PAnsiChar); cdecl;
  TRatexGetLastError = function: PAnsiChar; cdecl;

  // NativeUInt on BOTH platforms, and that is not a simplification: Windows'
  // HMODULE is already NativeUInt, and Delphi's POSIX dlopen is declared
  // `function dlopen(...): NativeUInt` - it does NOT return a Pointer the way
  // the C header does, and dlsym/dlclose take the handle back as NativeUInt.
  // Declaring this Pointer compiles on Windows and fails only on macOS, with
  // "E2010 Incompatible types: 'Pointer' and 'UInt64'".
  TLibHandle = NativeUInt;

const
{$IFDEF MSWINDOWS}
  DefaultLibName = 'ratex_ffi.dll';
{$ELSE}
  {$IFDEF MACOS}
  DefaultLibName = 'libratex_ffi.dylib';
  {$ELSE}
  DefaultLibName = 'libratex_ffi.so';
  {$ENDIF}
{$ENDIF}

  // One face we insist on: without the fonts a formula would render as a field
  // of .notdef boxes, which is worse than showing the LaTeX source.
  RequiredFace = 'KaTeX_Main-Regular.ttf';

var
  GLib: TLibHandle;
  GParseAndLayout: TRatexParseAndLayout;
  GFreeDisplayList: TRatexFreeDisplayList;
  GGetLastError: TRatexGetLastError;
  GTried: Boolean;          // load attempted (successfully or not)
  GAvailable: Boolean;
  GLibPath: string;         // host override; '' = search the default places
  GFontDir: string;
  GLastError: string;
  GCache: TDictionary<string, TRhoMathLayout>;
  GTypefaces: TDictionary<string, ISkTypeface>;
  GFallback: ISkTypeface;

// dlopen / dlsym take a C string, so the UTF-8 conversion is held in a local
// for the duration of the call rather than cast inline from a temporary.
function LibLoad(const AName: string): TLibHandle;
{$IFNDEF MSWINDOWS}
var
  U: UTF8String;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  Result := SafeLoadLibrary(AName);
{$ELSE}
  U := UTF8String(AName);
  Result := dlopen(MarshaledAString(PAnsiChar(U)), RTLD_LAZY);
{$ENDIF}
end;

function LibSymbol(const AHandle: TLibHandle; const AName: string): Pointer;
{$IFNDEF MSWINDOWS}
var
  U: UTF8String;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  Result := GetProcAddress(AHandle, PChar(AName));
{$ELSE}
  U := UTF8String(AName);
  Result := dlsym(AHandle, MarshaledAString(PAnsiChar(U)));
{$ENDIF}
end;

procedure LibUnload(const AHandle: TLibHandle);
begin
{$IFDEF MSWINDOWS}
  FreeLibrary(AHandle);
{$ELSE}
  dlclose(AHandle);
{$ENDIF}
end;

function LibIsValid(const AHandle: TLibHandle): Boolean;
begin
{$IFDEF MSWINDOWS}
  // Values below 32 are the legacy WinExec-era error codes LoadLibrary can
  // still return, not usable module handles.
  Result := AHandle >= 32;
{$ELSE}
  Result := AHandle <> 0;
{$ENDIF}
end;

function FontDir: string;
begin
  if GFontDir <> '' then
    Result := GFontDir
  else
    Result := IncludeTrailingPathDelimiter(
      TPath.Combine(ExtractFilePath(ParamStr(0)), 'fonts'));
end;

procedure RhoSetMathLibraryPath(const APath: string);
begin
  if SameText(APath, GLibPath) then
    Exit;
  GLibPath := APath;
  GTried := False;    // re-probe on the next call
  GAvailable := False;
end;

procedure RhoSetMathFontDir(const ADir: string);
begin
  if ADir = '' then
    GFontDir := ''
  else
    GFontDir := IncludeTrailingPathDelimiter(ADir);
  GTried := False;
  GAvailable := False;
  if GTypefaces <> nil then
    GTypefaces.Clear;
  GFallback := nil;
end;

// Loads the library once and caches the verdict. Both the library and the
// fonts must be present: either one missing means "no math", and the caller
// falls back to literal text.
function EnsureLoaded: Boolean;
var
  Candidate: string;
begin
  if GTried then
    Exit(GAvailable);
  GTried := True;
  GAvailable := False;

  if not TFile.Exists(TPath.Combine(FontDir, RequiredFace)) then
  begin
    GLastError := Format('KaTeX fonts not found in "%s".', [FontDir]);
    Exit(False);
  end;

  if GLibPath <> '' then
    GLib := LibLoad(GLibPath)
  else
  begin
    // Beside the executable first - that is where an application deploys it -
    // then the bare name, letting the OS search its usual paths.
    Candidate := TPath.Combine(ExtractFilePath(ParamStr(0)), DefaultLibName);
    if TFile.Exists(Candidate) then
      GLib := LibLoad(Candidate)
    else
      GLib := LibLoad(DefaultLibName);
  end;

  if not LibIsValid(GLib) then
  begin
    GLastError := Format('%s could not be loaded.', [DefaultLibName]);
    Exit(False);
  end;

  GParseAndLayout := LibSymbol(GLib, 'ratex_parse_and_layout');
  GFreeDisplayList := LibSymbol(GLib, 'ratex_free_display_list');
  GGetLastError := LibSymbol(GLib, 'ratex_get_last_error');

  if (@GParseAndLayout = nil) or (@GFreeDisplayList = nil) then
  begin
    GLastError := 'The RaTeX library is missing its expected exports.';
    LibUnload(GLib);
    GLib := Default(TLibHandle);
    Exit(False);
  end;

  GAvailable := True;
  Result := True;
end;

function RhoMathAvailable: Boolean;
begin
  Result := EnsureLoaded;
end;

function RhoMathLastError: string;
begin
  Result := GLastError;
end;

{ ---------------------------------------------------------------------------
  Font id -> KaTeX .ttf
  --------------------------------------------------------------------------- }

function FontFileFor(const AFontId: string): string;
begin
  // RaTeX emits KaTeX's own face names. The three fallback ids are not KaTeX
  // faces at all, so they go straight to the system typeface.
  if (AFontId = 'CJK-Regular') or (AFontId = 'CJK-Fallback') or
     (AFontId = 'Emoji-Fallback') then
    Result := ''
  else
    Result := 'KaTeX_' + AFontId + '.ttf';
end;

function GetFallbackFace: ISkTypeface;
begin
  if GFallback = nil then
    GFallback := TSkTypeface.MakeDefault;
  Result := GFallback;
end;

function GetTypeface(const AFontId: string): ISkTypeface;
var
  FileName: string;
begin
  if GTypefaces = nil then
    GTypefaces := TDictionary<string, ISkTypeface>.Create;
  if GTypefaces.TryGetValue(AFontId, Result) then
    Exit;

  Result := nil;
  FileName := FontFileFor(AFontId);
  if FileName <> '' then
  begin
    FileName := TPath.Combine(FontDir, FileName);
    if TFile.Exists(FileName) then
      Result := TSkTypeface.MakeFromFile(FileName);
  end;
  if Result = nil then
    Result := GetFallbackFace;

  // Cached including the fallback, so a missing face costs one lookup, not one
  // per glyph per repaint.
  GTypefaces.Add(AFontId, Result);
end;

{ ---------------------------------------------------------------------------
  Mathematical Alphanumeric Symbols (U+1D400-U+1D7FF).

  The display list carries the true Unicode scalar so web and SVG backends can
  emit it as text, but the shipped KaTeX .ttf files key those outlines at the
  plain ASCII letter and digit slots instead. Without this remap \mathbb,
  \mathbf, Fraktur and friends all render as .notdef.

  Port of ratex_font::katex_ttf_glyph_char.
  --------------------------------------------------------------------------- }

function MathAlphaNumeric(const ACodePoint: Cardinal;
  out AFontId: string; out AMetric: Cardinal): Boolean;
const
  Letters52 = 52;
  // 52-letter blocks: 26 uppercase then 26 lowercase.
  LetterBases: array[0..8] of record Base: Cardinal; Font: string; end = (
    (Base: $1D400; Font: 'Main-Bold'),
    (Base: $1D434; Font: 'Math-Italic'),
    (Base: $1D468; Font: 'Math-BoldItalic'),
    (Base: $1D504; Font: 'Fraktur-Regular'),
    (Base: $1D56C; Font: 'Fraktur-Bold'),
    (Base: $1D5A0; Font: 'SansSerif-Regular'),
    (Base: $1D5D4; Font: 'SansSerif-Bold'),
    (Base: $1D608; Font: 'SansSerif-Italic'),
    (Base: $1D670; Font: 'Typewriter-Regular'));
  // 10-digit blocks.
  DigitBases: array[0..3] of record Base: Cardinal; Font: string; end = (
    (Base: $1D7CE; Font: 'Main-Bold'),
    (Base: $1D7E2; Font: 'SansSerif-Regular'),
    (Base: $1D7EC; Font: 'SansSerif-Bold'),
    (Base: $1D7F6; Font: 'Typewriter-Regular'));
var
  I, Offset: Cardinal;
begin
  Result := False;
  AFontId := '';
  AMetric := 0;
  if ACodePoint <= $7F then
    Exit;

  for I := 0 to High(LetterBases) do
    if (ACodePoint >= LetterBases[I].Base) and
       (ACodePoint < LetterBases[I].Base + Letters52) then
    begin
      Offset := ACodePoint - LetterBases[I].Base;
      AFontId := LetterBases[I].Font;
      if Offset < 26 then
        AMetric := Ord('A') + Offset
      else
        AMetric := Ord('a') + (Offset - 26);
      Exit(True);
    end;

  if (ACodePoint >= $1D538) and (ACodePoint < $1D538 + 26) then
  begin
    AFontId := 'AMS-Regular';
    AMetric := Ord('A') + (ACodePoint - $1D538);
    Exit(True);
  end;

  if (ACodePoint >= $1D49C) and (ACodePoint < $1D49C + 26) then
  begin
    AFontId := 'Script-Regular';
    AMetric := Ord('A') + (ACodePoint - $1D49C);
    Exit(True);
  end;

  if ACodePoint = $1D55C then
  begin
    AFontId := 'AMS-Regular';
    AMetric := Ord('k');
    Exit(True);
  end;

  for I := 0 to High(DigitBases) do
    if (ACodePoint >= DigitBases[I].Base) and
       (ACodePoint < DigitBases[I].Base + 10) then
    begin
      AFontId := DigitBases[I].Font;
      AMetric := Ord('0') + (ACodePoint - DigitBases[I].Base);
      Exit(True);
    end;
end;

/// Code point to look up in this face's cmap.
function TTFGlyphCodePoint(const AFontId: string; const ACharCode: Cardinal): Cardinal;
var
  MappedFont: string;
  Metric: Cardinal;
begin
  if MathAlphaNumeric(ACharCode, MappedFont, Metric) and (MappedFont = AFontId) then
    Result := Metric
  else
    Result := ACharCode;
end;

function CodePointToString(const ACodePoint: Cardinal): string;
begin
  if ACodePoint > $FFFF then
    Result := Char($D800 + ((ACodePoint - $10000) shr 10)) +
              Char($DC00 + ((ACodePoint - $10000) and $3FF))
  else
    Result := Char(ACodePoint);
end;

{ ---------------------------------------------------------------------------
  JSON helpers - tolerant by design: the display-list protocol asks decoders to
  ignore unknown fields and treat missing optional ones as defaults.
  --------------------------------------------------------------------------- }

function JNum(const AObj: TJSONObject; const AName: string;
  const ADefault: Double = 0): Double;
var
  V: TJSONValue;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;
  V := AObj.Values[AName];
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsDouble;
end;

function JStr(const AObj: TJSONObject; const AName: string;
  const ADefault: string = ''): string;
var
  V: TJSONValue;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;
  V := AObj.Values[AName];
  if V is TJSONString then
    Result := TJSONString(V).Value;
end;

function JBool(const AObj: TJSONObject; const AName: string;
  const ADefault: Boolean = False): Boolean;
var
  V: TJSONValue;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;
  V := AObj.Values[AName];
  if V is TJSONBool then
    Result := TJSONBool(V).AsBoolean;
end;

// An item's own colour if it carries one, otherwise the caller's default. That
// default is what makes a formula follow TextColor (and so the theme) without
// the colour having to be baked in at layout time - which would put it in the
// cache key and cost a reparse per theme change.
function JColor(const AObj: TJSONObject; const ADefault: TAlphaColor): TAlphaColor;
var
  C: TJSONObject;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;
  if not (AObj.Values['color'] is TJSONObject) then
    Exit;
  C := TJSONObject(AObj.Values['color']);
  Result := TAlphaColorF.Create(
    JNum(C, 'r', 0), JNum(C, 'g', 0), JNum(C, 'b', 0), JNum(C, 'a', 1)).ToAlphaColor;
end;

{ TRhoMathLayout }

constructor TRhoMathLayout.Create(const AJson: string);
var
  V: TJSONValue;
begin
  inherited Create;
  V := TJSONObject.ParseJSONValue(AJson);
  if not (V is TJSONObject) then
  begin
    V.Free;
    raise Exception.Create('RaTeX returned a display list that is not a JSON object.');
  end;
  FRoot := TJSONObject(V);
  FWidthEm := JNum(FRoot, 'width');
  FHeightEm := JNum(FRoot, 'height');
  FDepthEm := JNum(FRoot, 'depth');
  if FRoot.Values['items'] is TJSONArray then
    FItems := TJSONArray(FRoot.Values['items']);
end;

destructor TRhoMathLayout.Destroy;
begin
  FRoot.Free;   // owns FItems
  inherited;
end;

function TRhoMathLayout.SizeAt(const AFontSize: Single): TSizeF;
begin
  Result := TSizeF.Create(FWidthEm * AFontSize,
    (FHeightEm + FDepthEm) * AFontSize);
end;

{ ---- layout ---- }

function ParseFormula(const ALatex: string; const ADisplay: Boolean;
  const AColor: TAlphaColor): TRhoMathLayout;
var
  Opts: TRatexOptions;
  Res: TRatexResult;
  Utf8: UTF8String;
  Json: string;
  Err: PAnsiChar;
  Col: TRatexColor;
  ColF: TAlphaColorF;
begin
  Result := nil;
  Utf8 := UTF8Encode(ALatex);
  Opts := Default(TRatexOptions);
  Opts.struct_size := SizeOf(TRatexOptions);
  if ADisplay then
    Opts.display_mode := 1
  else
    Opts.display_mode := 0;
  // RaTeX colours every item in the display list as it lays out, with no way
  // to mark one "unset" - so the colour has to go in here rather than being
  // applied at draw time. Note it gates on struct_size, which is why
  // TRatexOptions must stay unpacked (24 bytes, not 20).
  ColF := TAlphaColorF.Create(AColor);
  Col.r := ColF.R;
  Col.g := ColF.G;
  Col.b := ColF.B;
  Col.a := ColF.A;
  Opts.color := @Col;

  Res := GParseAndLayout(PAnsiChar(Utf8), @Opts);
  if (Res.error_code <> 0) or (Res.data = nil) then
  begin
    GLastError := '';
    if @GGetLastError <> nil then
    begin
      Err := GGetLastError;
      if Err <> nil then
        GLastError := string(UTF8String(Err));
    end;
    if GLastError = '' then
      GLastError := Format('RaTeX failed with error code %d.', [Res.error_code]);
    Exit;
  end;

  try
    Json := string(UTF8String(Res.data));
  finally
    GFreeDisplayList(Res.data);
  end;

  try
    Result := TRhoMathLayout.Create(Json);
  except
    on E: Exception do
    begin
      GLastError := E.Message;
      Result := nil;
    end;
  end;
end;

function RhoMathLayout(const ALatex: string; const ADisplay: Boolean;
  const AColor: TAlphaColor): TRhoMathLayout;
var
  Key: string;
begin
  Result := nil;
  if Trim(ALatex) = '' then
    Exit;
  if not EnsureLoaded then
    Exit;

  if GCache = nil then
    GCache := TDictionary<string, TRhoMathLayout>.Create;
  // Display mode changes the layout (limits above and below rather than
  // beside), and the colour is baked in, so both belong in the key.
  Key := BoolToStr(ADisplay, True) + #1 + IntToHex(AColor, 8) + #1 + ALatex;
  if GCache.TryGetValue(Key, Result) then
    Exit;   // a cached nil is a remembered parse failure - do not retry it

  Result := ParseFormula(ALatex, ADisplay, AColor);
  GCache.Add(Key, Result);
end;

procedure RhoMathClearCache;
var
  L: TRhoMathLayout;
begin
  if GCache = nil then
    Exit;
  for L in GCache.Values do
    L.Free;
  GCache.Clear;
end;

{ ---- paint ---- }

procedure DrawGlyphItem(const ACanvas: ISkCanvas; const AItem: TJSONObject;
  const AOriginX, AOriginY, AEm: Single; const AColor: TAlphaColor;
  const AFonts: TDictionary<string, ISkFont>);
var
  FontId, Key, Text: string;
  Scale, GlyphSize: Single;
  Font: ISkFont;
  Paint: ISkPaint;
  CodePoint: Cardinal;
  Glyphs: TArray<Word>;
begin
  FontId := JStr(AItem, 'font', 'Main-Regular');
  Scale := JNum(AItem, 'scale', 1);
  GlyphSize := AEm * Scale;
  if GlyphSize <= 0 then
    Exit;

  // One ISkFont per (face, size) pair for the duration of the draw.
  Key := FontId + '@' + FloatToStr(GlyphSize);
  if not AFonts.TryGetValue(Key, Font) then
  begin
    Font := TSkFont.Create(GetTypeface(FontId), GlyphSize);
    Font.Edging := TSkFontEdging.AntiAlias;
    Font.Subpixel := True;
    AFonts.Add(Key, Font);
  end;

  CodePoint := TTFGlyphCodePoint(FontId, Round(JNum(AItem, 'char_code')));
  Text := CodePointToString(CodePoint);

  // A KaTeX face lacking the glyph gives .notdef; retry with the system font so
  // CJK, emoji and the like still show up.
  Glyphs := Font.GetGlyphs(Text);
  if (Length(Glyphs) = 0) or (Glyphs[0] = 0) then
  begin
    Key := '*fallback*@' + FloatToStr(GlyphSize);
    if not AFonts.TryGetValue(Key, Font) then
    begin
      Font := TSkFont.Create(GetFallbackFace, GlyphSize);
      Font.Edging := TSkFontEdging.AntiAlias;
      Font.Subpixel := True;
      AFonts.Add(Key, Font);
    end;
  end;

  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Color := JColor(AItem, AColor);
  // The display list positions a glyph on its baseline, which is what
  // DrawSimpleText wants for AY.
  ACanvas.DrawSimpleText(Text,
    AOriginX + JNum(AItem, 'x') * AEm,
    AOriginY + JNum(AItem, 'y') * AEm, Font, Paint);
end;

procedure DrawLineItem(const ACanvas: ISkCanvas; const AItem: TJSONObject;
  const AOriginX, AOriginY, AEm: Single; const AColor: TAlphaColor);
var
  X, Y, W, T, DashLen, GapLen, Period, CurX, SegW: Single;
  Paint: ISkPaint;
begin
  X := AOriginX + JNum(AItem, 'x') * AEm;
  Y := AOriginY + JNum(AItem, 'y') * AEm;
  W := JNum(AItem, 'width') * AEm;
  // A rule thinner than a pixel would vanish; KaTeX's own rasteriser clamps too.
  T := Max(JNum(AItem, 'thickness') * AEm, 1);

  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.Color := JColor(AItem, AColor);

  // y is the CENTRE of the rule, not its top.
  if JBool(AItem, 'dashed') then
  begin
    DashLen := Max(4 * T, 2);
    GapLen := Max(4 * T, 2);
    Period := DashLen + GapLen;
    CurX := X;
    while CurX < X + W do
    begin
      SegW := Max(Min(DashLen, X + W - CurX), 2);
      ACanvas.DrawRect(RectF(CurX, Y - T / 2, CurX + SegW, Y + T / 2), Paint);
      CurX := CurX + Period;
    end;
  end
  else
    ACanvas.DrawRect(RectF(X, Y - T / 2, X + W, Y + T / 2), Paint);
end;

procedure DrawRectItem(const ACanvas: ISkCanvas; const AItem: TJSONObject;
  const AOriginX, AOriginY, AEm: Single; const AColor: TAlphaColor);
var
  X, Y: Single;
  Paint: ISkPaint;
begin
  X := AOriginX + JNum(AItem, 'x') * AEm;
  Y := AOriginY + JNum(AItem, 'y') * AEm;

  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Style := TSkPaintStyle.Fill;
  Paint.Color := JColor(AItem, AColor);
  ACanvas.DrawRect(RectF(X, Y,
    X + JNum(AItem, 'width') * AEm, Y + JNum(AItem, 'height') * AEm), Paint);
end;

procedure DrawPathItem(const ACanvas: ISkCanvas; const AItem: TJSONObject;
  const AOriginX, AOriginY, AEm: Single; const AColor: TAlphaColor);
var
  X, Y: Single;
  Fill: Boolean;
  Commands: TJSONArray;
  Paint: ISkPaint;
  Builder: ISkPathBuilder;
  HasSegment: Boolean;
  I: Integer;
  Cmd: TJSONObject;
  Kind: string;

  procedure FlushSegment;
  begin
    if HasSegment then
      ACanvas.DrawPath(Builder.Detach, Paint);
    Builder := TSkPathBuilder.Create;
    HasSegment := False;
  end;

begin
  X := AOriginX + JNum(AItem, 'x') * AEm;
  Y := AOriginY + JNum(AItem, 'y') * AEm;
  Fill := JBool(AItem, 'fill', True);
  if not (AItem.Values['commands'] is TJSONArray) then
    Exit;
  Commands := TJSONArray(AItem.Values['commands']);

  Paint := TSkPaint.Create;
  Paint.AntiAlias := True;
  Paint.Color := JColor(AItem, AColor);
  if Fill then
    Paint.Style := TSkPaintStyle.Fill
  else
  begin
    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := 1.5;
  end;

  Builder := TSkPathBuilder.Create;
  HasSegment := False;

  for I := 0 to Commands.Count - 1 do
  begin
    if not (Commands.Items[I] is TJSONObject) then
      Continue;
    Cmd := TJSONObject(Commands.Items[I]);
    Kind := JStr(Cmd, 'type');

    if Kind = 'MoveTo' then
    begin
      // A filled path is drawn ONE SUBPATH AT A TIME. KaTeX assembles stretchy
      // arrows from components whose winding directions oppose each other, so a
      // single combined fill cancels the shaft out entirely.
      if Fill and HasSegment then
        FlushSegment;
      Builder.MoveTo(X + JNum(Cmd, 'x') * AEm, Y + JNum(Cmd, 'y') * AEm);
      HasSegment := True;
    end
    else if Kind = 'LineTo' then
      Builder.LineTo(X + JNum(Cmd, 'x') * AEm, Y + JNum(Cmd, 'y') * AEm)
    else if Kind = 'CubicTo' then
      Builder.CubicTo(
        X + JNum(Cmd, 'x1') * AEm, Y + JNum(Cmd, 'y1') * AEm,
        X + JNum(Cmd, 'x2') * AEm, Y + JNum(Cmd, 'y2') * AEm,
        X + JNum(Cmd, 'x') * AEm,  Y + JNum(Cmd, 'y') * AEm)
    else if Kind = 'QuadTo' then
      Builder.QuadTo(
        X + JNum(Cmd, 'x1') * AEm, Y + JNum(Cmd, 'y1') * AEm,
        X + JNum(Cmd, 'x') * AEm,  Y + JNum(Cmd, 'y') * AEm)
    else if Kind = 'Close' then
      Builder.Close;
    // Unknown command types are ignored, per the protocol's forward-compat rule.
  end;

  FlushSegment;
end;

procedure RhoMathDraw(const ACanvas: ISkCanvas; const ALayout: TRhoMathLayout;
  const AX, AY, AFontSize: Single; const AColor: TAlphaColor);
var
  Fonts: TDictionary<string, ISkFont>;
  I: Integer;
  Item: TJSONObject;
  Kind: string;
begin
  if (ALayout = nil) or (ALayout.Items = nil) or (AFontSize <= 0) then
    Exit;

  Fonts := TDictionary<string, ISkFont>.Create;
  try
    for I := 0 to ALayout.Items.Count - 1 do
    begin
      if not (ALayout.Items.Items[I] is TJSONObject) then
        Continue;
      Item := TJSONObject(ALayout.Items.Items[I]);
      Kind := JStr(Item, 'type');

      if Kind = 'GlyphPath' then
        DrawGlyphItem(ACanvas, Item, AX, AY, AFontSize, AColor, Fonts)
      else if Kind = 'Line' then
        DrawLineItem(ACanvas, Item, AX, AY, AFontSize, AColor)
      else if Kind = 'Rect' then
        DrawRectItem(ACanvas, Item, AX, AY, AFontSize, AColor)
      else if Kind = 'Path' then
        DrawPathItem(ACanvas, Item, AX, AY, AFontSize, AColor);
      // Unknown item types are ignored, per the protocol's forward-compat rule.
    end;
  finally
    Fonts.Free;
  end;
end;

initialization

finalization
  RhoMathClearCache;
  GCache.Free;
  GTypefaces.Free;

end.

#import "mAScintillaView.h"
#import "Scintilla.h"
#import "SciLexer.h"
#import "mASyntaxHighlighter.h"

#include "ILexer.h"
#include "LexerModule.h"

extern const Lexilla::LexerModule lmCPP;

// ChucK keyword sets (copied from qt/mAsciLexerChucK.cpp)
static const char* const s_keywords1 =
    "int float time dur polar complex vec3 vec4 void same if else while do "
    "until for break continue return switch repeat "
    "class extends public static pure this "
    "super interface implements protected global auto "
    "private function fun spork const new now "
    "true false maybe null NULL me pi samp ms "
    "second minute hour day week dac adc blackhole chout cherr "
    "@operator @import @construct @destruct @doc";

static const char* const s_keywords2 =
    "Object "
    "string "
    "UAnaBlob "
    "Shred "
    "Thread "
    "Class "
    "Event "
    "IO "
    "FileIO "
    "SerialIO "
    "StdOut "
    "StdErr "
    "Windowing "
    "Machine "
    "Std "
    "KBHit "
    "ConsoleInput "
    "StringTokenizer "
    "RegEx "
    "Math "
    "OscSend "
    "OscEvent "
    "OscRecv "
    "MidiMsg "
    "MidiIn "
    "MidiOut "
    "MidiRW "
    "MidiMsgIn "
    "MidiMsgOut "
    "MidiFileIn "
    "HidMsg "
    "Hid ";

static const char* const s_keywords4 =
    "UGen "
    "UAna "
    "Osc "
    "Phasor "
    "SinOsc "
    "TriOsc "
    "SawOsc "
    "PulseOsc "
    "SqrOsc "
    "GenX "
    "Gen5 "
    "Gen7 "
    "Pan2 "
    "Gen9 "
    "Gen10 "
    "Gen17 "
    "CurveTable "
    "WarpTable "
    "Chubgraph "
    "Chugen "
    "UGen_Stereo "
    "UGen_Multi "
    "DAC "
    "ADC "
    "Mix2 "
    "Gain "
    "Noise "
    "CNoise "
    "Impulse "
    "Step "
    "HalfRect "
    "FullRect "
    "DelayP "
    "SndBuf "
    "SndBuf2 "
    "Dyno "
    "LiSa "
    "FilterBasic "
    "BPF "
    "BRF "
    "LPF "
    "HPF "
    "ResonZ "
    "BiQuad "
    "Teabox "
    "StkInstrument "
    "BandedWG "
    "BlowBotl "
    "BlowHole "
    "Bowed "
    "Brass "
    "Clarinet "
    "Flute "
    "Mandolin "
    "ModalBar "
    "Moog "
    "Saxofony "
    "Shakers "
    "Sitar "
    "StifKarp "
    "VoicForm "
    "FM "
    "BeeThree "
    "FMVoices "
    "HevyMetl "
    "PercFlut "
    "Rhodey "
    "TubeBell "
    "Wurley "
    "Delay "
    "DelayA "
    "DelayL "
    "Echo "
    "Envelope "
    "ADSR "
    "FilterStk "
    "OnePole "
    "TwoPole "
    "OneZero "
    "TwoZero "
    "PoleZero "
    "JCRev "
    "NRev "
    "PRCRev "
    "Chorus "
    "Modulate "
    "PitShift "
    "SubNoise "
    "WvIn "
    "WaveLoop "
    "WvOut "
    "WvOut2 "
    "BLT "
    "BlitSquare "
    "Blit "
    "BlitSaw "
    "JetTabl "
    "Mesh2D "
    "FFT "
    "IFFT "
    "Flip "
    "pilF "
    "DCT "
    "IDCT "
    "FeatureCollector "
    "Centroid "
    "Flux "
    "MFCC "
    "RMS "
    "RollOff "
    "AutoCorr "
    "XCorr "
    "ZeroX ";

// ---------------------------------------------------------------------------
#pragma mark - mAScintillaView
// ---------------------------------------------------------------------------

@implementation mAScintillaView {
    ScintillaView *_sci;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    [self _commonInit];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self) return nil;
    [self _commonInit];
    return self;
}

- (void)_commonInit {
    _sci = [[ScintillaView alloc] initWithFrame:self.bounds];
    _sci.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _sci.delegate = self;
    [self addSubview:_sci];
    [self _configureScintilla];
}

- (void)dealloc {
    _sci.delegate = nil;
    [_sci release];
    [super dealloc];
}

// ---------------------------------------------------------------------------
#pragma mark - Scintilla configuration
// ---------------------------------------------------------------------------

- (void)_configureScintilla {
    Scintilla::ILexer5 *lexer = lmCPP.Create();
    [_sci message:SCI_SETILEXER wParam:0 lParam:(sptr_t)lexer];

    // ChucK keyword sets (mirroring mAsciLexerChucK::keywords())
    [self _setKeywords:s_keywords1 forSet:0];
    [self _setKeywords:s_keywords2 forSet:1];
    [self _setKeywords:s_keywords4 forSet:3];

    // Box folding
    [_sci message:SCI_SETPROPERTY wParam:(uptr_t)"fold"         lParam:(sptr_t)"1"];
    [_sci message:SCI_SETPROPERTY wParam:(uptr_t)"fold.compact" lParam:(sptr_t)"0"];

    [_sci message:SCI_SETMARGINTYPEN      wParam:2 lParam:SC_MARGIN_SYMBOL];
    [_sci message:SCI_SETMARGINMASKN      wParam:2 lParam:SC_MASK_FOLDERS];
    [_sci message:SCI_SETMARGINSENSITIVEN wParam:2 lParam:1];
    [_sci message:SCI_SETMARGINWIDTHN     wParam:2 lParam:16];

    [_sci message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDER       lParam:SC_MARK_BOXPLUS];
    [_sci message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDEROPEN    lParam:SC_MARK_BOXMINUS];
    [_sci message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDEREND     lParam:SC_MARK_BOXPLUSCONNECTED];
    [_sci message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDERMIDTAIL lParam:SC_MARK_TCORNER];
    [_sci message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDERSUB     lParam:SC_MARK_VLINE];
    [_sci message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDERTAIL    lParam:SC_MARK_LCORNER];
    [_sci message:SCI_MARKERDEFINE wParam:SC_MARKNUM_FOLDEROPENMID lParam:SC_MARK_BOXMINUSCONNECTED];
    [_sci message:SCI_SETAUTOMATICFOLD
           wParam:(SC_AUTOMATICFOLD_SHOW | SC_AUTOMATICFOLD_CLICK)
           lParam:0];

    // Line number margin
    [_sci message:SCI_SETMARGINTYPEN  wParam:0 lParam:SC_MARGIN_NUMBER];
    [_sci message:SCI_SETMARGINWIDTHN wParam:0 lParam:15];

    // Indent settings
    [_sci message:SCI_SETTABWIDTH   wParam:4 lParam:0];
    [_sci message:SCI_SETINDENT     wParam:4 lParam:0];
    [_sci message:SCI_SETUSETABS    wParam:0 lParam:0];
    [_sci message:SCI_SETTABINDENTS wParam:1 lParam:0];

    [self _applyColorsFromPreferences];
}

- (void)_setKeywords:(const char *)words forSet:(int)set {
    [_sci message:SCI_SETKEYWORDS wParam:set lParam:(sptr_t)words];
}

// ---------------------------------------------------------------------------
#pragma mark - Public interface
// ---------------------------------------------------------------------------

- (NSString *)content {
    return _sci.string;
}

- (void)setContent:(NSString *)content {
    [_sci message:SCI_SETUNDOCOLLECTION wParam:0 lParam:0];
    _sci.string = content ?: @"";
    [_sci message:SCI_SETUNDOCOLLECTION wParam:1 lParam:0];
    [_sci message:SCI_EMPTYUNDOBUFFER   wParam:0 lParam:0];
    [_sci message:SCI_GOTOPOS           wParam:0 lParam:0];
}

- (void)enableLineNumbers:(BOOL)enable {
    [_sci message:SCI_SETMARGINWIDTHN wParam:0 lParam:enable ? 20 : 0];
}

- (void)reloadUserDefaults {
    [self _applyColorsFromPreferences];
}

- (ScintillaView *)scintillaView {
    return _sci;
}

// ---------------------------------------------------------------------------
#pragma mark - Color/font preferences
// ---------------------------------------------------------------------------

- (void)_applyColorsFromPreferences {
    NSUserDefaults *ud  = [NSUserDefaults standardUserDefaults];
    NSDictionary   *sh  = [ud dictionaryForKey:@"IDEKit_TextColors"];

    NSColor *(^color)(NSString *) = ^NSColor *(NSString *key) {
        NSString *hex = [sh objectForKey:key];
        return hex ? [NSColor colorWithHTML:hex] : nil;
    };
    NSInteger (^sciColor)(NSColor *) = ^NSInteger(NSColor *c) {
        if (!c) return 0x000000;
        c = [c colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
        int r = (int)(c.redComponent   * 255);
        int g = (int)(c.greenComponent * 255);
        int b = (int)(c.blueComponent  * 255);
        return (b << 16) | (g << 8) | r;   // Scintilla BGR
    };

    // Font (NSFont = "DefaultFont")
    NSData   *fontData = [ud objectForKey:@"DefaultFont"];
    NSFont   *font     = nil;
    if (fontData) {
        NSUnarchiver *uar = [[[NSUnarchiver alloc] initForReadingWithData:fontData] autorelease];
        font = [[[NSFont alloc] initWithCoder:uar] autorelease];
    }
    NSString *fontName = font ? [font fontName] : @"Monaco";
    CGFloat   fontSize = font ? [font pointSize] : 13;

    [_sci message:SCI_STYLESETFONT
           wParam:STYLE_DEFAULT
           lParam:(sptr_t)[fontName UTF8String]];
    [_sci message:SCI_STYLESETSIZEFRACTIONAL
           wParam:STYLE_DEFAULT
           lParam:(sptr_t)(fontSize * SC_FONT_SIZE_MULTIPLIER)];

    NSColor *bg = color(@"Background") ?: [NSColor whiteColor];
    [_sci message:SCI_STYLESETBACK wParam:STYLE_DEFAULT lParam:sciColor(bg)];

    NSColor *fg = color(@"NormalText") ?: [NSColor blackColor];
    [_sci message:SCI_STYLESETFORE wParam:STYLE_DEFAULT lParam:sciColor(fg)];

    [_sci message:SCI_STYLECLEARALL wParam:0 lParam:0];

    [_sci message:SCI_STYLESETSIZEFRACTIONAL
           wParam:STYLE_LINENUMBER
           lParam:(sptr_t)(7 * SC_FONT_SIZE_MULTIPLIER)];

    // Brace highlight styles
    [_sci message:SCI_STYLESETBACK wParam:STYLE_BRACELIGHT lParam:sciColor(bg)];
    [_sci message:SCI_STYLESETBACK wParam:STYLE_BRACEBAD   lParam:sciColor(bg)];
    [_sci message:SCI_STYLESETBOLD wParam:STYLE_BRACELIGHT lParam:0];
    [_sci message:SCI_STYLESETBOLD wParam:STYLE_BRACEBAD   lParam:0];

    // Keywords, Classes, UGens coloring
    NSColor *kw = color(@"Keywords") ?: [NSColor colorWithCalibratedRed:0   green:0   blue:1    alpha:1];
    [_sci message:SCI_STYLESETFORE wParam:SCE_C_WORD lParam:sciColor(kw)];

    NSColor *cl = color(@"Classes") ?: [NSColor colorWithCalibratedRed:0.5  green:0   blue:0.14 alpha:1];
    [_sci message:SCI_STYLESETFORE wParam:SCE_C_WORD2 lParam:sciColor(cl)];

    NSColor *ug = color(@"UGens") ?: [NSColor colorWithCalibratedRed:0.64 green:0   blue:0.93 alpha:1];
    [_sci message:SCI_STYLESETFORE wParam:SCE_C_GLOBALCLASS lParam:sciColor(ug)];

    NSColor *cm = color(@"Comments") ?: [NSColor colorWithCalibratedRed:0.38 green:0.56 blue:0.06 alpha:1];
    [_sci message:SCI_STYLESETFORE wParam:SCE_C_COMMENT     lParam:sciColor(cm)];
    [_sci message:SCI_STYLESETFORE wParam:SCE_C_COMMENTLINE lParam:sciColor(cm)];

    NSColor *st = color(@"Strings") ?: [NSColor colorWithCalibratedRed:0.25 green:0.25 blue:0.25 alpha:1];
    [_sci message:SCI_STYLESETFORE wParam:SCE_C_STRING    lParam:sciColor(st)];
    [_sci message:SCI_STYLESETFORE wParam:SCE_C_CHARACTER lParam:sciColor(st)];

    NSColor *nm = color(@"Numbers") ?: [NSColor colorWithCalibratedRed:0.83 green:0.5  blue:0.06 alpha:1];
    [_sci message:SCI_STYLESETFORE wParam:SCE_C_NUMBER lParam:sciColor(nm)];
}

// ---------------------------------------------------------------------------
#pragma mark - ScintillaNotificationProtocol
// ---------------------------------------------------------------------------

- (void)notification:(SCNotification *)scn {
    if (!scn) return;
    if (scn->nmhdr.code != SCN_CHARADDED) return;

    if (scn->ch == '\n') {
        sptr_t pos = [_sci message:SCI_GETCURRENTPOS];
        NSInteger curLine = [_sci message:SCI_LINEFROMPOSITION wParam:(uptr_t)pos lParam:0];
        if (curLine <= 0) return;

        NSInteger indentation = [_sci message:SCI_GETLINEINDENTATION wParam:(uptr_t)(curLine - 1) lParam:0];

        // { auto-indent
        sptr_t lineEnd = [_sci message:SCI_GETLINEENDPOSITION wParam:(uptr_t)(curLine - 1) lParam:0];
        sptr_t check = lineEnd - 1;
        while (check >= 0) {
            int c = (int)[_sci message:SCI_GETCHARAT wParam:(uptr_t)check lParam:0];
            if (c != ' ' && c != '\t') break;
            check--;
        }
        if (check >= 0 && (int)[_sci message:SCI_GETCHARAT wParam:(uptr_t)check lParam:0] == '{')
            indentation += 4;

        if (indentation <= 0) return;
        if (indentation > 256) indentation = 256;

        char spaces[257];
        memset(spaces, ' ', (size_t)indentation);
        spaces[indentation] = '\0';
        [_sci message:SCI_ADDTEXT wParam:(uptr_t)indentation lParam:(sptr_t)spaces];

    } else if (scn->ch == '}') {
        sptr_t pos = [_sci message:SCI_GETCURRENTPOS];
        NSInteger curLine = [_sci message:SCI_LINEFROMPOSITION wParam:(uptr_t)pos lParam:0];
        sptr_t lineStart = [_sci message:SCI_POSITIONFROMLINE wParam:(uptr_t)curLine lParam:0];

        // } de-indent
        NSInteger indent = [_sci message:SCI_GETLINEINDENTATION wParam:(uptr_t)curLine lParam:0];
        if (pos - 1 - lineStart != indent) return;

        NSInteger newIndent = MAX(0, indent - 4);
        [_sci message:SCI_SETLINEINDENTATION wParam:(uptr_t)curLine lParam:newIndent];

        sptr_t endPos = [_sci message:SCI_GETLINEENDPOSITION wParam:(uptr_t)curLine lParam:0];
        [_sci message:SCI_GOTOPOS wParam:(uptr_t)endPos lParam:0];
    }
}

@end

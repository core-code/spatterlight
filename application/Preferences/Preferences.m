#import "CoreDataManager.h"
#import "Game.h"
#import "Metadata.h"
#import "Theme.h"
#import "ThemeArrayController.h"
#import "GlkStyle.h"
#import "LibController.h"
#import "NSString+Categories.h"
#import "NSColor+integer.h"
#import "BufferTextView.h"
#import "main.h"
#import "BuiltInThemes.h"

#ifdef DEBUG
#define NSLog(FORMAT, ...)                                                     \
fprintf(stderr, "%s\n",                                                    \
[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#else
#define NSLog(...)
#endif

@interface Preferences () <NSWindowDelegate, NSControlTextEditingDelegate> {
    IBOutlet NSButton *btnInputFont, *btnBufferFont, *btnGridFont;
    IBOutlet NSColorWell *clrInputFg, *clrBufferFg, *clrGridFg;
    IBOutlet NSColorWell *clrBufferBg, *clrGridBg;
    IBOutlet NSTextField *txtBufferMargin, *txtGridMargin, *txtLeading;
    IBOutlet NSTextField *txtRows, *txtCols;
    IBOutlet NSTextField *txtBorder;
    IBOutlet NSButton *btnSmartQuotes;
    IBOutlet NSButton *btnSpaceFormat;
    IBOutlet NSButton *btnEnableGraphics;
    IBOutlet NSButton *btnEnableSound;
    IBOutlet NSButton *btnEnableStyles;
    IBOutlet NSTableView *themesTableView;
    IBOutlet GlkHelperView *sampleTextView;

    GlkController *glkcntrl;

    NSButton *selectedFontButton;

    BOOL disregardTableSelection;
    BOOL zooming;
    CGFloat previewTextHeight;
    NSString *lastSelectedTheme;

    NSDate *themeDuplicationTimestamp;
    Theme *lastDuplicatedTheme;

    NSDictionary *catalinaSoundsToBigSur;
    NSDictionary *bigSurSoundsToCatalina;
}
@end

@implementation Preferences

/*
 * Preference variables, all unpacked
 */

static kZoomDirectionType zoomDirection = ZOOMRESET;

static Theme *theme = nil;
static Preferences *prefs = nil;

/*
 * Load and save defaults
 */

+ (void)initFactoryDefaults {
    NSString *filename = [[NSBundle mainBundle] pathForResource:@"Defaults"
                                                         ofType:@"plist"];
    NSMutableDictionary *defaults =
    [NSMutableDictionary dictionaryWithContentsOfFile:filename];

    defaults[@"GameDirectory"] = (@"~/Documents").stringByExpandingTildeInPath;
    defaults[@"SaveDirectory"] = (@"~/Documents").stringByExpandingTildeInPath;

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

+ (void)readDefaults {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *name = [defaults objectForKey:@"themeName"];

    if (!name)
        name = @"Old settings";

    CoreDataManager *coreDataManager = ((AppDelegate*)[NSApplication sharedApplication].delegate).coreDataManager;

    NSManagedObjectContext *managedObjectContext = coreDataManager.mainManagedObjectContext;

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSArray *fetchedObjects;
    NSError *error;
    fetchRequest.entity = [NSEntityDescription entityForName:@"Theme" inManagedObjectContext:managedObjectContext];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"name like[c] %@", name];
    fetchedObjects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];

    if (fetchedObjects == nil || fetchedObjects.count == 0) {
        NSLog(@"Preference readDefaults: Error! Saved theme %@ not found. Creating new default theme!", name);
        theme = [BuiltInThemes createThemeFromDefaultsPlistInContext:managedObjectContext forceRebuild:NO];
        if (!theme)
            theme = [BuiltInThemes createDefaultThemeInContext:managedObjectContext forceRebuild:NO];
        if (!theme) {
            NSLog(@"Preference readDefaults: Error! Could not create default theme!");
        }
    } else theme = fetchedObjects[0];

    // We may or may not have created the Default and Old themes already above.
    // Then these won't be recreated below.
    [BuiltInThemes createBuiltInThemesInContext:managedObjectContext forceRebuild:NO];
}



+ (void)changeCurrentGame:(Game *)game {
    if (prefs) {
        prefs.currentGame = game;
        if (!game.theme)
            game.theme = theme;
        [prefs restoreThemeSelection:theme];
    }
}

+ (void)initialize {

    [self initFactoryDefaults];
    [self readDefaults];

    [self rebuildTextAttributes];
}


#pragma mark Global accessors

+ (BOOL)graphicsEnabled {
    return theme.doGraphics;
}

+ (BOOL)soundEnabled {
    return theme.doSound;
}

+ (BOOL)stylesEnabled {
    return theme.doStyles;
}

+ (BOOL)smartQuotes {
    return theme.smartQuotes;
}

+ (kSpacesFormatType)spaceFormat {
    return (kSpacesFormatType)theme.spaceFormat;
}

+ (kZoomDirectionType)zoomDirection {
    return zoomDirection;
}

+ (double)lineHeight {
    return theme.cellHeight;
}

+ (double)charWidth {
    return theme.cellWidth;;
}

+ (CGFloat)gridMargins {
    return theme.gridMarginX;
}

+ (CGFloat)bufferMargins {
    return theme.bufferMarginX;
}

+ (CGFloat)border {
    return theme.border;
}

+ (CGFloat)leading {
    return theme.bufferNormal.lineSpacing;
}

+ (NSColor *)gridBackground {
    return theme.gridBackground;
}

+ (NSColor *)gridForeground {
    return theme.gridNormal.color;
}

+ (NSColor *)bufferBackground {
    return theme.bufferBackground;
}

+ (NSColor *)bufferForeground {
    return theme.bufferNormal.color;
}

+ (NSColor *)inputColor {
    return theme.bufInput.color;
}

+ (Theme *)currentTheme {
    return theme;
}

+ (Preferences *)instance {
    return prefs;
}


#pragma mark GlkStyle and attributed-string magic

+ (void)rebuildTextAttributes {

    [theme populateStyles];
    NSSize cellsize = [theme.gridNormal cellSize];
    theme.cellWidth = cellsize.width;
    theme.cellHeight = cellsize.height;
    cellsize = [theme.bufferNormal cellSize];
    theme.bufferCellWidth = cellsize.width;
    theme.bufferCellHeight = cellsize.height;

}

#pragma mark - Instance -- controller for preference panel

NSString *fontToString(NSFont *font) {
    if ((int)font.pointSize == font.pointSize)
        return [NSString stringWithFormat:@"%@ %.f", font.displayName,
                (float)font.pointSize];
    else
        return [NSString stringWithFormat:@"%@ %.1f", font.displayName,
                (float)font.pointSize];
}

- (void)windowDidLoad {
    //    NSLog(@"pref: windowDidLoad()");

    [super windowDidLoad];

    self.window.delegate = self;

    self.windowFrameAutosaveName = @"PrefsPanel";
    themesTableView.autosaveName = @"ThemesTable";

    disregardTableSelection = YES;

    if (self.window.minSize.height != kDefaultPrefWindowHeight || self.window.minSize.width != kDefaultPrefWindowWidth) {
        NSSize minSize = self.window.minSize;
        minSize.height = kDefaultPrefWindowHeight;
        minSize.width = kDefaultPrefWindowWidth;
        self.window.minSize = minSize;
    }

    _previewShown = [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowThemePreview"];

     NSMutableAttributedString *attstr = _swapBufColBtn.attributedStringValue.mutableCopy;
     NSFont *font = [NSFont fontWithName:@"Exclamation Circle New" size:17];

    [attstr addAttribute:NSFontAttributeName
                   value:font
                   range:NSMakeRange(0, attstr.length)];

    [attstr replaceCharactersInRange:NSMakeRange(0,1) withString:@"\u264B"];

    CGFloat offset = (NSAppKitVersionNumber < NSAppKitVersionNumber10_9); //Need to check this

    [attstr addAttribute:NSBaselineOffsetAttributeName
                   value:@(offset)
                   range:NSMakeRange(0, attstr.length)];

    _swapBufColBtn.attributedTitle = attstr;
    _swapGridColBtn.attributedTitle = attstr;

    _standardZArrowsMenuItem.title = NSLocalizedString(@"↑ and ↓ work as in original", nil);
    _standardZArrowsMenuItem.toolTip = NSLocalizedString(@"↑ and ↓ navigate menus and status windows. \u2318↑ and \u2318↓ step through command history.", nil);
    _compromiseZArrowsMenuItem.title = NSLocalizedString(@"Replaced by \u2318↑ and \u2318↓", nil);
    _compromiseZArrowsMenuItem.toolTip = NSLocalizedString(@"\u2318↑ and \u2318↓ are used where the original uses ↑ and ↓. ↑ and ↓ step through command history as in other games.", nil);
    _strictZArrowsMenuItem.title = NSLocalizedString(@"↑↓ and ←→ work as in original", nil);
    _strictZArrowsMenuItem.toolTip = NSLocalizedString(@"↑ and ↓ navigate menus and status windows. \u2318↑ and \u2318↓ step through command history. ← and → don't do anything.", nil);

    if (@available(macOS 11, *)) {

        catalinaSoundsToBigSur = @{ @"Purr" : @"Pluck",
                                    @"Tink" : @"Boop",
                                    @"Blow" : @"Breeze",
                                    @"Pop" : @"Bubble",
                                    @"Glass" : @"Crystal",
                                    @"Funk" : @"Funky",
                                    @"Hero" : @"Heroine",
                                    @"Frog" : @"Jump",
                                    @"Basso" : @"Mezzo",
                                    @"Bottle" : @"Pebble",
                                    @"Morse" : @"Pong",
                                    @"Ping" : @"Sonar",
                                    @"Sosumi" : @"Sonumi",
                                    @"Submarine" : @"Submerge" };

        bigSurSoundsToCatalina = @{ @"Pluck" : @"Purr",
                                    @"Boop" : @"Tink",
                                    @"Breeze" : @"Blow",
                                    @"Bubble" : @"Pop",
                                    @"Crystal": @"Glass",
                                    @"Funky" : @"Funk",
                                    @"Heroine" : @"Hero",
                                    @"Jump" : @"Frog",
                                    @"Mezzo" : @"Basso",
                                    @"Pebble" : @"Bottle",
                                    @"Pong" : @"Morse",
                                    @"Sonar" : @"Ping",
                                    @"Sonumi" : @"Sosumi",
                                    @"Submerge" : @"Submarine" };

        for (NSString *key in catalinaSoundsToBigSur.allKeys) {
            NSMenuItem *menuItem = [_beepHighMenu itemWithTitle:key];
            menuItem.title = catalinaSoundsToBigSur[key];
            menuItem = [_beepLowMenu itemWithTitle:key];
            menuItem.title = catalinaSoundsToBigSur[key];
        }
    }



    if (!theme)
        theme = self.defaultTheme;

    // Sample text view
    glkcntrl = [[GlkController alloc] init];
    glkcntrl.theme = theme;
    glkcntrl.previewDummy = YES;
    glkcntrl.borderView = _sampleTextBorderView;
    glkcntrl.contentView = sampleTextView;
    glkcntrl.ignoreResizes = YES;
    sampleTextView.glkctrl = glkcntrl;

    _sampleTextBorderView.fillColor = theme.bufferBackground;
    NSRect newSampleFrame = NSMakeRect(20, 312, self.window.frame.size.width - 40, ((NSView *)self.window.contentView).frame.size.height - 312);
    sampleTextView.frame = newSampleFrame;
    _sampleTextBorderView.frame = newSampleFrame;

    _divider.frame = NSMakeRect(0, 311, self.window.frame.size.width, 1);
    _divider.autoresizingMask = NSViewMaxYMargin;

    NSMutableArray *nullarray = [NSMutableArray arrayWithCapacity:stylehint_NUMHINTS];

    NSInteger i;
    for (i = 0 ; i < stylehint_NUMHINTS ; i ++)
        [nullarray addObject:[NSNull null]];
    NSMutableArray *stylehHints = [NSMutableArray arrayWithCapacity:style_NUMSTYLES];
    for (i = 0 ; i < style_NUMSTYLES ; i ++) {
        [stylehHints addObject:[nullarray mutableCopy]];
    }

    glkcntrl.bufferStyleHints = stylehHints;

    _glktxtbuf = [[GlkTextBufferWindow alloc] initWithGlkController:glkcntrl name:1];

    _glktxtbuf.textview.editable = NO;
    [sampleTextView addSubview:_glktxtbuf];

    [_glktxtbuf putString:@"Palace Gate" style:style_Subheader];
    [_glktxtbuf putString:@" A tide of perambulators surges north along the crowded Broad Walk. "
                   style:style_Normal];

    [_glktxtbuf putString:@"(Trinity, Brian Moriarty, Infocom 1986)" style:style_Emphasized];

    previewTextHeight = [self textHeight];
    [self adjustPreview:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notePreferencesChanged:)
                                                 name:@"PreferencesChanged"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(noteManagedObjectContextDidChange:)
                                                 name:NSManagedObjectContextObjectsDidChangeNotification
                                               object:_managedObjectContext];

    _oneThemeForAll = [[NSUserDefaults standardUserDefaults] boolForKey:@"OneThemeForAll"];
    _themesHeader.stringValue = [self themeScopeTitle];

    _adjustSize = [[NSUserDefaults standardUserDefaults] boolForKey:@"AdjustSize"];

    prefs = self;
    [self updatePrefsPanel];

    _scrollView.scrollerStyle = NSScrollerStyleOverlay;
    _scrollView.drawsBackground = YES;
    _scrollView.hasHorizontalScroller = NO;
    _scrollView.hasVerticalScroller = YES;
    _scrollView.verticalScroller.alphaValue = 100;
    _scrollView.autohidesScrollers = YES;
    _scrollView.borderType = NSNoBorder;

    themeDuplicationTimestamp = [NSDate date];

    [self changeThemeName:theme.name];
    [self performSelector:@selector(restoreThemeSelection:) withObject:theme afterDelay:0.1];

    // If the application state was saved on an old version of Spatterlight, the preferences window
    // will be restored too narrow, so we fix it here. We need a delay in order to wait for system
    // windows restoration to finish.
    [self performSelector:@selector(restoreWindowSize:) withObject:theme afterDelay:0.1];
}

- (void)restoreWindowSize:(id)sender  {
    if (NSWidth(self.window.frame) != kDefaultPrefWindowWidth || !_previewShown) {
        _previewShown = NO;
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ShowThemePreview"];
        [self resizeWindowToHeight:kDefaultPrefWindowHeight];
        sampleTextView.autoresizingMask = NSViewHeightSizable;
    }
}

- (void)updatePrefsPanel {
    if (!theme)
        theme = self.defaultTheme;
    if (!theme.gridNormal.attributeDict)
        [theme populateStyles];
    clrGridFg.color = theme.gridNormal.color;
    clrGridBg.color = theme.gridBackground;
    clrBufferFg.color = theme.bufferNormal.color;
    clrBufferBg.color = theme.bufferBackground;
    clrInputFg.color = theme.bufInput.color;

    txtGridMargin.floatValue = theme.gridMarginX;
    txtBufferMargin.floatValue = theme.bufferMarginX;
    txtLeading.doubleValue = theme.bufferNormal.lineSpacing;

    txtCols.intValue = theme.defaultCols;
    txtRows.intValue = theme.defaultRows;

    txtBorder.intValue = theme.border;

    btnGridFont.title = fontToString(theme.gridNormal.font);
    btnBufferFont.title = fontToString(theme.bufferNormal.font);
    btnInputFont.title = fontToString(theme.bufInput.font);

    btnSmartQuotes.state = theme.smartQuotes;
    btnSpaceFormat.state = (theme.spaceFormat == TAG_SPACES_ONE);

    btnEnableGraphics.state = theme.doGraphics;
    btnEnableSound.state = theme.doSound;
    btnEnableStyles.state = theme.doStyles;

    _btnOverwriteStyles.enabled = theme.hasCustomStyles;
    _btnOverwriteStyles.state = ([_btnOverwriteStyles isEnabled] == NO);

    _btnOneThemeForAll.state = _oneThemeForAll;
    _btnAdjustSize.state = _adjustSize;

    _btnVOSpeakCommands.state = theme.vOSpeakCommand;
    [_vOMenuButton selectItemAtIndex:theme.vOSpeakMenu];
    [_vOImagesButton selectItemAtIndex:theme.vOSpeakImages];

    NSString *beepHigh = theme.beepHigh;
    NSString *beepLow = theme.beepLow;

    if (@available(macOS 11, *)) {
        NSString *newHigh = catalinaSoundsToBigSur[beepHigh];
        if (newHigh)
            beepHigh = newHigh;
        NSString *newLow = catalinaSoundsToBigSur[beepLow];
        if (newLow)
            beepLow = newLow;
    }

    [_beepHighMenu selectItemWithTitle:beepHigh];
    [_beepLowMenu selectItemWithTitle:beepLow];
    [_zterpMenu selectItemAtIndex:theme.zMachineTerp];
    [_bZArrowsMenu selectItemAtIndex:theme.bZTerminator];

    _zVersionTextField.stringValue = theme.zMachineLetter;

    _bZVerticalTextField.integerValue = theme.bZAdjustment;
    _bZVerticalStepper.integerValue = theme.bZAdjustment;

    _btnSmoothScroll.state = theme.smoothScroll;
    _btnAutosave.state = theme.autosave;
    _btnAutosaveOnTimer.state = theme.autosaveOnTimer;
    _btnAutosaveOnTimer.enabled = _btnAutosave.state ? YES : NO;

    if (theme.minTimer != 0) {
        if (_timerSlider.integerValue != 1000.0 / theme.minTimer) {
            _timerSlider.integerValue = (long)(1000.0 / theme.minTimer);
        }
        if (_timerTextField.integerValue != (1000.0 / theme.minTimer)) {
            _timerTextField.integerValue = (long)(1000.0 / theme.minTimer);
        }
    }

    if ([[NSFontPanel sharedFontPanel] isVisible] && selectedFontButton)
        [self showFontPanel:selectedFontButton];
}

@synthesize currentGame = _currentGame;

- (void)setCurrentGame:(Game *)currentGame {
    _currentGame = currentGame;
    _themesHeader.stringValue = [self themeScopeTitle];
    if (currentGame == nil) {
        NSLog(@"Preferences currentGame was set to nil");
        return;
    }
    if (_currentGame.theme != theme) {
        [self restoreThemeSelection:_currentGame.theme];
    }
}

- (Game *)currentGame {
    return _currentGame;
}

@synthesize defaultTheme = _defaultTheme;

- (Theme *)defaultTheme {
    if (_defaultTheme == nil) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        fetchRequest.entity = [NSEntityDescription entityForName:@"Theme" inManagedObjectContext:[self managedObjectContext]];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"name like[c] %@", @"Default"];
        NSError *error = nil;
        NSArray *fetchedObjects = [_managedObjectContext executeFetchRequest:fetchRequest error:&error];

        if (fetchedObjects && fetchedObjects.count) {
            _defaultTheme = fetchedObjects[0];
        } else {
            if (error != nil)
                NSLog(@"Preferences defaultTheme: %@", error);
            _defaultTheme = [BuiltInThemes createDefaultThemeInContext:_managedObjectContext forceRebuild:NO];
        }
    }
    return _defaultTheme;
}

@synthesize coreDataManager = _coreDataManager;

- (CoreDataManager *)coreDataManager {
    if (_coreDataManager == nil) {
        _coreDataManager = ((AppDelegate*)[NSApplication sharedApplication].delegate).coreDataManager;
    }
    return _coreDataManager;
}

@synthesize managedObjectContext = _managedObjectContext;

- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext == nil) {
        _managedObjectContext = [self coreDataManager].mainManagedObjectContext;
    }
    return _managedObjectContext;
}

- (IBAction)rebuildDefaultThemes:(id)sender {
    [BuiltInThemes createBuiltInThemesInContext:_managedObjectContext forceRebuild:YES];
}

#pragma mark Preview

- (void)notePreferencesChanged:(NSNotification *)notify {
    // Change the theme of the sample text field
    _glktxtbuf.theme = theme;
    glkcntrl.theme = theme;

    previewTextHeight = [self textHeight];

    _sampleTextBorderView.fillColor = theme.bufferBackground;

    [_glktxtbuf prefsDidChange];

    Preferences * __unsafe_unretained weakSelf = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.coreDataManager saveChanges];
    });

    if (!_previewShown)
        return;

    if (sampleTextView.frame.size.height < _sampleTextBorderView.frame.size.height) {
        [self adjustPreview:nil];
    }
    [self performSelector:@selector(adjustPreview:) withObject:nil afterDelay:0.1];
}
- (void)adjustPreview:(id)sender {
    NSRect previewFrame = [self.window.contentView frame];
    previewFrame.origin.y = kDefaultPrefsLowerViewHeight + 1; // Plus one to allow for divider line
    previewFrame.size.height = previewFrame.size.height - kDefaultPrefsLowerViewHeight - 1;
    _sampleTextBorderView.frame = previewFrame;

    previewTextHeight = [self textHeight];
    NSRect newSampleFrame = _sampleTextBorderView.bounds;

    newSampleFrame.origin = NSMakePoint(
                                        round((NSWidth([_sampleTextBorderView bounds]) - NSWidth([sampleTextView frame])) / 2),
                                        round((NSHeight([_sampleTextBorderView bounds]) - previewTextHeight) / 2)
                                        );
    if (newSampleFrame.origin.x < 0)
        newSampleFrame.origin.x = 0;
    if (newSampleFrame.origin.y < 0)
        newSampleFrame.origin.y = 0;

    newSampleFrame.size.width = _sampleTextBorderView.frame.size.width - 40;
    newSampleFrame.size.height = previewTextHeight;

    sampleTextView.autoresizingMask = NSViewMinYMargin | NSViewMaxYMargin | NSViewWidthSizable;

    if (newSampleFrame.size.height > _sampleTextBorderView.bounds.size.height) {
        newSampleFrame.size.height = _sampleTextBorderView.bounds.size.height;
    }

    NSTextView *textview = _glktxtbuf.textview;
    textview.textContainerInset = NSZeroSize;

    if (sampleTextView.frame.size.height < _glktxtbuf.textview.frame.size.height && _glktxtbuf.frame.size.height < _glktxtbuf.textview.frame.size.height && _glktxtbuf.textview.frame.size.height < _sampleTextBorderView.frame.size.height) {
        newSampleFrame.size.height = textview.frame.size.height;
    }

    sampleTextView.frame = newSampleFrame;
    _glktxtbuf.textview.enclosingScrollView.frame = sampleTextView.bounds;
    _glktxtbuf.frame = sampleTextView.bounds;

    _glktxtbuf.autoresizingMask = NSViewHeightSizable;
    _glktxtbuf.textview.enclosingScrollView.autoresizingMask = NSViewHeightSizable;
    [self scrollToTop:nil];
}

- (NSSize)windowWillResize:(NSWindow *)window
                    toSize:(NSSize)frameSize {

    if (window != self.window)
        return frameSize;

    if (frameSize.height > self.window.frame.size.height) { // We are enlarging
        NSRect previewFrame = _sampleTextBorderView.frame;
        previewFrame.origin.y = kDefaultPrefsLowerViewHeight + 1;
        _sampleTextBorderView.frame = previewFrame;
        if (sampleTextView.frame.size.height >= _sampleTextBorderView.frame.size.height) { // Preview fills superview
            if (sampleTextView.frame.size.height >= previewTextHeight) {
                sampleTextView.autoresizingMask = NSViewMinYMargin | NSViewMaxYMargin;
            } else sampleTextView.autoresizingMask = NSViewHeightSizable;
        } else {
            NSRect newFrame = sampleTextView.frame;

            [sampleTextView removeFromSuperview];

            if (sampleTextView.frame.size.height < _glktxtbuf.textview.frame.size.height && _glktxtbuf.frame.size.height < _glktxtbuf.textview.frame.size.height) {
                newFrame.size.height = _glktxtbuf.textview.frame.size.height;
                sampleTextView.frame = newFrame;
                _glktxtbuf.frame = sampleTextView.bounds;
                _glktxtbuf.textview.enclosingScrollView.frame = sampleTextView.bounds;
            }
            newFrame.origin.y = round((_sampleTextBorderView.bounds.size.height - newFrame.size.height) / 2);
            sampleTextView.frame = newFrame;

            [_sampleTextBorderView addSubview:sampleTextView];
        }
    }

    if (zooming) {
        zooming = NO;
        return frameSize;
    }

    if (frameSize.height <= kDefaultPrefWindowHeight) {
        _previewShown = NO;
    } else _previewShown = YES;

    [[NSUserDefaults standardUserDefaults] setBool:_previewShown forKey:@"ShowThemePreview"];

    return frameSize;
}

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window
                        defaultFrame:(NSRect)newFrame {

    if (window != self.window)
        return newFrame;

    CGFloat newHeight;

    if (!_previewShown) {
        newHeight = kDefaultPrefWindowHeight;
        zooming = YES;
    } else {
        newHeight = [self previewHeight];
    }

    NSRect currentFrame = window.frame;

    CGFloat diff = currentFrame.size.height - newHeight;
    currentFrame.origin.y += diff;
    currentFrame.size.height = newHeight;

    return currentFrame;
};

- (BOOL)windowShouldZoom:(NSWindow *)window toFrame:(NSRect)newFrame {
    if (window != self.window)
        return YES;
    if (!_previewShown && newFrame.size.height > kDefaultPrefWindowHeight)
        return NO;
    if (_previewShown)
        [self performSelector:@selector(adjustPreview:) withObject:nil afterDelay:0.1];
    return YES;
}

- (void)resizeWindowToHeight:(CGFloat)height {
    NSWindow *prefsPanel = self.window;

    CGFloat oldheight = prefsPanel.frame.size.height;

    if (ceil(height) == ceil(oldheight)) {
        if (_previewShown) {
            [self performSelector:@selector(scrollToTop:) withObject:nil afterDelay:0.1];
        }
        return;
    }

    CGRect screenframe = prefsPanel.screen.visibleFrame;

    CGRect winrect = prefsPanel.frame;
    winrect.origin = prefsPanel.frame.origin;

    winrect.size.height = height;
    winrect.size.width = kDefaultPrefWindowWidth;

    // If the entire text does not fit on screen, don't change height at all
    if (winrect.size.height > screenframe.size.height)
        winrect.size.height = oldheight;

    // When we reuse the window it will remember our last scroll position,
    // so we reset it here

    NSScrollView *scrollView = _glktxtbuf.textview.enclosingScrollView;

    // Scroll the vertical scroller to top
    scrollView.verticalScroller.floatValue = 0;

    // Scroll the contentView to top
    [scrollView.contentView scrollToPoint:NSZeroPoint];

    CGFloat offset = winrect.size.height - oldheight;
    winrect.origin.y -= offset;

    // If window is partly off the screen, move it (just) inside
    if (NSMaxX(winrect) > NSMaxX(screenframe))
        winrect.origin.x = NSMaxX(screenframe) - winrect.size.width;

    if (NSMinY(winrect) < 0)
        winrect.origin.y = NSMinY(screenframe);

    Preferences * __unsafe_unretained weakSelf = self;
    [self adjustPreview:nil];

    [NSAnimationContext
     runAnimationGroup:^(NSAnimationContext *context) {
         [[prefsPanel animator]
          setFrame:winrect
          display:YES];
     } completionHandler:^{
         //We need to reset the _sampleTextBorderView here, otherwise some of it will still show when hiding the preview.
         NSRect newFrame = weakSelf.window.frame;
         weakSelf.sampleTextBorderView.frame = NSMakeRect(0, kDefaultPrefWindowHeight, newFrame.size.width, newFrame.size.height - kDefaultPrefWindowHeight);

         if (weakSelf.previewShown) {
             [weakSelf adjustPreview:nil];
             [weakSelf.glktxtbuf restoreScrollBarStyle];
         }
     }];
}

- (void)scrollToTop:(id)sender {
    if (_previewShown) {
        NSScrollView *scrollView = _glktxtbuf.textview.enclosingScrollView;
        scrollView.frame = _glktxtbuf.frame;
        [scrollView.contentView scrollToPoint:NSZeroPoint];
    }
}

- (CGFloat)previewHeight {

    CGFloat proposedHeight = [self textHeight];

    CGFloat totalHeight = kDefaultPrefWindowHeight + proposedHeight + 40; //2 * (theme.border + theme.bufferMarginY);
    CGRect screenframe = [NSScreen mainScreen].visibleFrame;

    if (totalHeight > screenframe.size.height) {
        totalHeight = screenframe.size.height;
    }
    return totalHeight;
}

- (CGFloat)textHeight {
    [_glktxtbuf flushDisplay];
    NSTextView *textview = [[NSTextView alloc] initWithFrame:_glktxtbuf.textview.frame];
    if (textview == nil) {
        NSLog(@"Couldn't create textview!");
        return 0;
    }

    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:[_glktxtbuf.textview.textStorage copy]];
    CGFloat textWidth = textview.frame.size.width;
    NSTextContainer *textContainer = [[NSTextContainer alloc]
                                      initWithContainerSize:NSMakeSize(textWidth, FLT_MAX)];

    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];

    [layoutManager ensureLayoutForGlyphRange:NSMakeRange(0, textStorage.length)];

    CGRect proposedRect = [layoutManager usedRectForTextContainer:textContainer];
    return ceil(proposedRect.size.height);
}

- (void)noteManagedObjectContextDidChange:(NSNotification *)notify {
//    NSLog(@"noteManagedObjectContextDidChange: %@", theme.name);
    NSArray *updatedObjects = (notify.userInfo)[NSUpdatedObjectsKey];

    if ([updatedObjects containsObject:theme]) {
        Preferences * __unsafe_unretained weakSelf = self;

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf updatePrefsPanel];
            [[NSNotificationCenter defaultCenter]
             postNotification:[NSNotification notificationWithName:@"PreferencesChanged" object:theme]];
        });
    }
}

#pragma mark Themes Table View Magic

- (void)restoreThemeSelection:(id)sender {
    if (_arrayController.selectedTheme == sender) {
//        NSLog(@"restoreThemeSelection: selected theme already was %@. Returning", ((Theme *)sender).name);
        return;
    }
    NSArray *themes = _arrayController.arrangedObjects;
    theme = sender;
    if (![themes containsObject:sender]) {
        theme = themes.lastObject;
        return;
    }
    NSUInteger row = [themes indexOfObject:theme];

    disregardTableSelection = NO;

    [_arrayController setSelectionIndex:row];
    themesTableView.allowsEmptySelection = NO;
    [themesTableView scrollRowToVisible:(NSInteger)row];
}

- (void)tableViewSelectionDidChange:(id)notification {
    NSTableView *tableView = [notification object];
    if (tableView == themesTableView) {
//        NSLog(@"Preferences tableViewSelectionDidChange:%@", _arrayController.selectedTheme.name);
        if (disregardTableSelection == YES) {
//            NSLog(@"Disregarding tableViewSelectionDidChange");
            disregardTableSelection = NO;
            return;
        }

        theme = _arrayController.selectedTheme;
        [self updatePrefsPanel];
        [self changeThemeName:theme.name];
        _btnRemove.enabled = theme.editable;

        if (_oneThemeForAll) {
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
            NSArray *fetchedObjects;
            NSError *error;
            fetchRequest.entity = [NSEntityDescription entityForName:@"Game" inManagedObjectContext:self.managedObjectContext];
            fetchRequest.includesPropertyValues = NO;
            fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
            [theme addGames:[NSSet setWithArray:fetchedObjects]];
        } else if (_currentGame) {
            _currentGame.theme = theme;
        }

        // Send notification that theme has changed -- trigger configure events
        [[NSNotificationCenter defaultCenter]
         postNotification:[NSNotification notificationWithName:@"PreferencesChanged" object:theme]];
    }
    return;
}

- (void)changeThemeName:(NSString *)name {
    [[NSUserDefaults standardUserDefaults] setObject:name forKey:@"themeName"];
    _detailsHeader.stringValue = [NSString stringWithFormat:@"Settings for theme %@", name];
    _miscHeader.stringValue = _detailsHeader.stringValue;
    _zcodeHeader.stringValue = _detailsHeader.stringValue;
    _vOHeader.stringValue = _detailsHeader.stringValue;
}

- (BOOL)notDuplicate:(NSString *)string {
    NSArray *themes = [_arrayController arrangedObjects];
    for (Theme *aTheme in themes) {
        if ([aTheme.name isEqualToString:string] && [themes indexOfObject:aTheme] != [themes indexOfObject:_arrayController.selectedTheme])
            return NO;
    }
    return YES;
}

- (BOOL)control:(NSControl *)control
textShouldEndEditing:(NSText *)fieldEditor {
    if ([self notDuplicate:fieldEditor.string] == NO) {
        [self showDuplicateThemeNameAlert:fieldEditor];
        return NO;
    }
    return YES;
}

- (void)showDuplicateThemeNameAlert:(NSText *)fieldEditor {
    NSAlert *anAlert = [[NSAlert alloc] init];
    anAlert.messageText =
    [NSString stringWithFormat:NSLocalizedString(@"The theme name \"%@\" is already in use.", nil), fieldEditor.string];
    anAlert.informativeText = NSLocalizedString(@"Please enter another name.", nil);
    [anAlert addButtonWithTitle:NSLocalizedString(@"Okay", nil)];
    [anAlert addButtonWithTitle:NSLocalizedString(@"Discard Change", nil)];

    [anAlert beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSAlertSecondButtonReturn) {
            fieldEditor.string = theme.name;
        }
    }];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    if ([notification.object isKindOfClass:[NSTextField class]]) {
        NSTextField *textfield = notification.object;
        [self changeThemeName:textfield.stringValue];
    }
}

- (NSArray *)sortDescriptors {
    return @[[NSSortDescriptor sortDescriptorWithKey:@"editable" ascending:YES],
             [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES
                                            selector:@selector(localizedStandardCompare:)]];
}

#pragma mark -
#pragma mark Windows restoration

- (void)window:(NSWindow *)window willEncodeRestorableState:(NSCoder *)state {
    NSString *selectedfontString = nil;
    if (selectedFontButton)
        selectedfontString = selectedFontButton.identifier;
    [state encodeObject:selectedfontString forKey:@"selectedFont"];
    [state encodeBool:_previewShown forKey:@"_previewShown"];
    [state encodeDouble:self.window.frame.size.height forKey:@"windowHeight"];
}

- (void)window:(NSWindow *)window didDecodeRestorableState:(NSCoder *)state {
    NSString *selectedfontString = [state decodeObjectOfClass:[NSString class] forKey:@"selectedFont"];
    if (selectedfontString != nil) {
        NSArray *fontsButtons = @[btnBufferFont, btnGridFont, btnInputFont];
        for (NSButton *button in fontsButtons) {
            if ([button.identifier isEqualToString:selectedfontString]) {
                selectedFontButton = button;
            }
        }
    }
    _previewShown = [state decodeBoolForKey:@"_previewShown"];
    if (!_previewShown) {
        [self resizeWindowToHeight:kDefaultPrefWindowHeight];
    } else {
        CGFloat storedHeight = [state decodeDoubleForKey:@"windowHeight"];
        if (storedHeight > kDefaultPrefWindowHeight)
            [self resizeWindowToHeight:storedHeight];
        else
            [self resizeWindowToHeight:[self previewHeight]];
    }
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return _managedObjectContext.undoManager;
}

#pragma mark Action menu

@synthesize oneThemeForAll = _oneThemeForAll;

- (void)setOneThemeForAll:(BOOL)oneThemeForAll {
    _oneThemeForAll = oneThemeForAll;
    [[NSUserDefaults standardUserDefaults] setBool:_oneThemeForAll forKey:@"OneThemeForAll"];
    _themesHeader.stringValue = [self themeScopeTitle];
    if (oneThemeForAll) {
        _btnOneThemeForAll.state = NSOnState;
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSError *error = nil;
        fetchRequest.entity = [NSEntityDescription entityForName:@"Game" inManagedObjectContext:self.managedObjectContext];
        fetchRequest.includesPropertyValues = NO;
        NSArray *fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        theme.games = [NSSet setWithArray:fetchedObjects];
    } else {
        _btnOneThemeForAll.state = NSOffState;
    }
}

- (BOOL)oneThemeForAll {
    return _oneThemeForAll;
}

- (IBAction)clickedOneThemeForAll:(id)sender {
    if ([sender state] == 1) {
        if (![[NSUserDefaults standardUserDefaults] valueForKey:@"UseForAllAlertSuppression"]) {
            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
            NSError *error = nil;
            fetchRequest.entity = [NSEntityDescription entityForName:@"Game" inManagedObjectContext:self.managedObjectContext];
            fetchRequest.includesPropertyValues = NO;
            NSArray *fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
            NSUInteger numberOfGames = fetchedObjects.count;
            Theme *mostPopularTheme = nil;
            NSUInteger highestCount = 0;
            NSUInteger currentCount = 0;
            for (Theme *t in _arrayController.arrangedObjects) {
                currentCount = t.games.count;
                if (currentCount > highestCount) {
                    highestCount = t.games.count;
                    mostPopularTheme = t;
                }
            }
            if (highestCount < numberOfGames) {
                fetchRequest.predicate = [NSPredicate predicateWithFormat:@"theme != %@", mostPopularTheme];
                fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
                [self showUseForAllAlert:fetchedObjects];
                return;
            }
        }
    }
    self.oneThemeForAll = (BOOL)[sender state];
}

- (void)showUseForAllAlert:(NSArray *)games {
    NSAlert *anAlert = [[NSAlert alloc] init];
    anAlert.messageText =
    [NSString stringWithFormat:@"%@ %@ individual theme settings.", [NSString stringWithSummaryOf:games], (games.count == 1) ? @"has" : @"have"];
    anAlert.informativeText = [NSString stringWithFormat:@"Would you like to use theme %@ for all games?", theme.name];
    anAlert.showsSuppressionButton = YES;
    anAlert.suppressionButton.title = NSLocalizedString(@"Do not show again.", nil);
    [anAlert addButtonWithTitle:NSLocalizedString(@"Okay", nil)];
    [anAlert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];

    Preferences * __unsafe_unretained weakSelf = self;
    [anAlert beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result){

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *alertSuppressionKey = @"UseForAllAlertSuppression";

        if (anAlert.suppressionButton.state == NSOnState) {
            // Suppress this alert from now on
            [defaults setBool:YES forKey:alertSuppressionKey];
        }
        if (result == NSAlertFirstButtonReturn) {
            weakSelf.oneThemeForAll = YES;
        } else {
            weakSelf.btnOneThemeForAll.state = NSOffState;
        }
    }];
}

- (NSString *)themeScopeTitle {
    if (_oneThemeForAll) return NSLocalizedString(@"Theme setting for all games", nil);
    if ( _currentGame == nil)
        return NSLocalizedString(@"No game is currently running", nil);
    else
        return [NSLocalizedString(@"Theme setting for game ", nil) stringByAppendingString:_currentGame.metadata.title];
}

- (IBAction)changeAdjustSize:(id)sender {
    _adjustSize = (BOOL)[sender state];
    [[NSUserDefaults standardUserDefaults] setBool:_adjustSize forKey:@"AdjustSize"];
}

- (IBAction)addTheme:(id)sender {
    NSInteger row = (NSInteger)[_arrayController selectionIndex];
    NSTableCellView *cellView = (NSTableCellView*)[themesTableView viewAtColumn:0 row:row makeIfNecessary:YES];
    if ([self notDuplicate:cellView.textField.stringValue]) {
        // For some reason, tableViewSelectionDidChange will be called twice here,
        // so we disregard the first call
        disregardTableSelection = YES;
        [_arrayController add:sender];
        [self performSelector:@selector(editNewEntry:) withObject:nil afterDelay:0.1];
    } else NSBeep();
}

- (IBAction)removeTheme:(id)sender {
    if (!_arrayController.selectedTheme.editable) {
        NSBeep();
        return;
    }
    NSSet *orphanedGames = _arrayController.selectedTheme.games;
    NSInteger row = (NSInteger)[_arrayController selectionIndex] - 1;
    [_arrayController remove:sender];
    _arrayController.selectionIndex = (NSUInteger)row;
    [_arrayController.selectedTheme addGames:orphanedGames];
}

- (IBAction)applyToSelected:(id)sender {
    [theme addGames:[NSSet setWithArray:_libcontroller.selectedGames]];
}

- (IBAction)selectUsingTheme:(id)sender {
    [_libcontroller selectGames:theme.games];
    NSLog(@"selected %ld games using theme %@", theme.games.count, theme.name);
}

- (IBAction)deleteUserThemes:(id)sender {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSArray *fetchedObjects;
    NSError *error;
    fetchRequest.entity = [NSEntityDescription entityForName:@"Theme" inManagedObjectContext:self.managedObjectContext];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"editable == YES"];
    fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];

    if (fetchedObjects == nil || fetchedObjects.count == 0) {
        return;
    }

    NSMutableSet *orphanedGames = [[NSMutableSet alloc] init];

    for (Theme *t in fetchedObjects) {
        [orphanedGames unionSet:t.games];
    }

    [_arrayController removeObjects:fetchedObjects];

    NSArray *remainingThemes = [_arrayController arrangedObjects];
    Theme *lastTheme = remainingThemes[remainingThemes.count - 1];
    NSLog(@"lastRemainingTheme: %@", lastTheme.name);
    [lastTheme addGames:orphanedGames];
    _arrayController.selectedObjects = @[lastTheme];
}

- (IBAction)togglePreview:(id)sender {
    if (_previewShown) {
        [self resizeWindowToHeight:kDefaultPrefWindowHeight];
        _previewShown = NO;
    } else {
        _previewShown = YES;
        [self resizeWindowToHeight:[self previewHeight]];
    }
    [self performSelector:@selector(adjustPreview:) withObject:nil afterDelay:0.5];
    [[NSUserDefaults standardUserDefaults] setBool:_previewShown forKey:@"ShowThemePreview"];
}

- (IBAction)editNewEntry:(id)sender {
    NSInteger row = (NSInteger)[_arrayController selectionIndex];
    NSTableCellView* cellView = (NSTableCellView*)[themesTableView viewAtColumn:0 row:row makeIfNecessary:YES];
    if ([cellView.textField acceptsFirstResponder]) {
        [cellView.window makeFirstResponder:cellView.textField];
        [themesTableView scrollRowToVisible:(NSInteger)row];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = menuItem.action;

    if (action == @selector(applyToSelected:)) {
        if (_oneThemeForAll || _libcontroller.selectedGames.count == 0) {
            return NO;
        } else {
            return YES;
        }
    }

    if (action == @selector(selectUsingTheme:))
        return (theme.games.count > 0);

    if (action == @selector(deleteUserThemes:)) {
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSArray *fetchedObjects;
        NSError *error;
        fetchRequest.entity = [NSEntityDescription entityForName:@"Theme" inManagedObjectContext:self.managedObjectContext];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"editable == YES"];
        fetchRequest.includesPropertyValues = NO;
        fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];

        if (fetchedObjects == nil || fetchedObjects.count == 0) {
            return NO;
        }
    }

    if (action == @selector(editNewEntry:))
        return theme.editable;

    if (action == @selector(togglePreview:))
    {
        NSString* title = _previewShown ? NSLocalizedString(@"Hide Preview", nil) : NSLocalizedString(@"Show Preview", nil);
        ((NSMenuItem*)menuItem).title = title;
    }

    return YES;
}

#pragma mark User actions

- (IBAction)changeDefaultSize:(id)sender {
    if (sender == txtCols) {
        if (theme.defaultCols == [sender intValue])
            return;
        theme = [self cloneThemeIfNotEditable];
        theme.defaultCols  = [sender intValue];
        if (theme.defaultCols  < 5)
            theme.defaultCols  = 5;
        if (theme.defaultCols  > 200)
            theme.defaultCols  = 200;
        txtCols.intValue = theme.defaultCols ;
    }
    if (sender == txtRows) {
        if (theme.defaultRows == [sender intValue])
            return;
        theme = [self cloneThemeIfNotEditable];
        theme.defaultRows  = [sender intValue];
        if (theme.defaultRows  < 5)
            theme.defaultRows  = 5;
        if (theme.defaultRows  > 200)
            theme.defaultRows  = 200;
        txtRows.intValue = theme.defaultRows ;
    }

    /* send notification that default size has changed -- resize all windows */
    NSNotification *notification = [NSNotification notificationWithName:@"DefaultSizeChanged" object:theme];
    [[NSNotificationCenter defaultCenter]
     postNotification:notification];
}

- (IBAction)changeColor:(id)sender {
    NSString *key = nil;
    Theme *themeToChange;
    NSColor *color = [sender color];
    if (!color) {
        NSLog(@"Preferences changeColor called with invalid color!");
        return;
    }

    if (sender == clrGridFg) {
        key = @"gridNormal";
    } else if (sender == clrGridBg) {
        if ([theme.gridBackground isEqualToColor:color])
            return;
        themeToChange = [self cloneThemeIfNotEditable];
        themeToChange.gridBackground = color;
    } else if (sender == clrBufferFg) {
        key = @"bufferNormal";
    } else if (sender == clrBufferBg) {
        if ([theme.bufferBackground isEqualToColor:color])
            return;
        themeToChange = [self cloneThemeIfNotEditable];
        themeToChange.bufferBackground = color;
    } else if (sender == clrInputFg) {
        key = @"bufInput";
    } else return;

    if (key) {
        //NSLog(@"key: %@", key);
        GlkStyle *style = [theme valueForKey:key];
        if ([style.color isEqualToColor:color])
            return;

        themeToChange = [self cloneThemeIfNotEditable];
        style = [themeToChange valueForKey:key];

        if (!style.attributeDict) {
            NSLog(@"Preferences changeColor called with invalid theme object!");
            return;
        }

        style.color = color;
    }

    [Preferences rebuildTextAttributes];
}

- (IBAction)swapColors:(id)sender {
    NSColor *tempCol;
    if (sender == _swapBufColBtn) {
        tempCol = clrBufferFg.color;
        clrBufferFg.color = clrBufferBg.color;
        clrBufferBg.color = tempCol;
        [self changeColor:clrBufferFg];
        [self changeColor:clrBufferBg];
    } else if (sender == _swapGridColBtn) {
        tempCol = clrGridFg.color;
        clrGridFg.color = clrGridBg.color;
        clrGridBg.color = tempCol;
        [self changeColor:clrGridFg];
        [self changeColor:clrGridBg];
    }
}

- (IBAction)changeMargin:(id)sender  {
    NSString *key = nil;
    NSInteger val = 0;
    Theme *themeToChange;
    val = [sender intValue];

    if (sender == txtGridMargin) {
        if (theme.gridMarginX == val)
            return;
        themeToChange = [self cloneThemeIfNotEditable];
        key = @"GridMargin";
        themeToChange.gridMarginX = val;
        themeToChange.gridMarginY = val;
    }
    if (sender == txtBufferMargin) {
        if (theme.bufferMarginX == val)
            return;
        themeToChange = [self cloneThemeIfNotEditable];
        key = @"BufferMargin";
        themeToChange.bufferMarginX = val;
        themeToChange.bufferMarginY = val;
    }

    if (key) {
        [Preferences rebuildTextAttributes];
    }
}

- (IBAction)changeLeading:(id)sender {
    if (theme.bufferNormal.lineSpacing == [sender floatValue])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.bufferNormal.lineSpacing = [sender floatValue];
    [Preferences rebuildTextAttributes];
}

- (IBAction)changeSmartQuotes:(id)sender {
    if (theme.smartQuotes  == [sender state])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.smartQuotes = [sender state] ? YES : NO;
//    NSLog(@"pref: smart quotes changed to %d", theme.smartQuotes);
}

- (IBAction)changeSpaceFormatting:(id)sender {
    if (theme.spaceFormat == [sender state])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.spaceFormat = ([sender state] == 1);
//    NSLog(@"pref: space format changed to %d", theme.spaceFormat);
}

- (IBAction)changeEnableGraphics:(id)sender {
    if (theme.doGraphics  == [sender state])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.doGraphics = [sender state] ? YES : NO;
//    NSLog(@"pref: dographics changed to %d", theme.doGraphics);
}

- (IBAction)changeEnableSound:(id)sender {
    if (theme.doSound  == [sender state])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.doSound = [sender state] ? YES : NO;
//    NSLog(@"pref: dosound changed to %d", theme.doSound);
}

- (IBAction)changeEnableStyles:(id)sender {
    if (theme.doStyles == [sender state])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.doStyles = [sender state] ? YES : NO;
    [Preferences rebuildTextAttributes];
}

#pragma mark VoiceOver menu

- (IBAction)changeVOSpeakCommands:(id)sender {
    if (theme.vOSpeakCommand == [sender state])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.vOSpeakCommand = [sender state];
}

- (IBAction)changeVOMenuMenu:(id)sender {
    if (theme.vOSpeakMenu == (int)[sender selectedTag])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.vOSpeakMenu = (int)[sender selectedTag];
}

- (IBAction)changeVOImageMenu:(id)sender {
    if (theme.vOSpeakImages == (int)[sender selectedTag])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.vOSpeakImages = (int)[sender selectedTag];
}

#pragma mark ZCode menu

- (IBAction)changeBeepHighMenu:(id)sender {
    NSString *title = [sender titleOfSelectedItem];
    NSSound *sound = [NSSound soundNamed:title];
    if (@available(macOS 11, *)) {
        if (!sound) {
            title = bigSurSoundsToCatalina[title];
            sound = [NSSound soundNamed:title];
        }
    }
    if (sound) {
        [sound stop];
        [sound play];
    }
    if ([theme.beepHigh isEqualToString:title])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.beepHigh = title;
}

- (IBAction)changeBeepLowMenu:(id)sender {
    NSString *title = [sender titleOfSelectedItem];
    NSSound *sound = [NSSound soundNamed:title];
    if (@available(macOS 11, *)) {
        if (!sound) {
            title = bigSurSoundsToCatalina[title];
            sound = [NSSound soundNamed:title];
        }
    }
    if (sound) {
        [sound stop];
        [sound play];
    }

    if ([theme.beepLow isEqualToString:title])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.beepLow = title;
}

- (IBAction)changeZterpMenu:(id)sender {
    if (theme.zMachineTerp == (int)[sender selectedTag])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.zMachineTerp = (int)[sender selectedTag];
}

- (IBAction)changeBZArrowsMenu:(id)sender {
    if (theme.bZTerminator == (int)[sender selectedTag]) {
        return;
    }
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.bZTerminator = (int)[sender selectedTag];
}

- (IBAction)changeZVersion:(id)sender {
    if ([theme.zMachineLetter isEqualToString:[sender stringValue]]) {
        return;
    }
    if ([sender stringValue].length == 0) {
        _zVersionTextField.stringValue = theme.zMachineLetter;
        return;
    }
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.zMachineLetter = [sender stringValue];
}

- (IBAction)changeBZVerticalStepper:(id)sender {
    if (theme.bZAdjustment == [sender integerValue]) {
        return;
    }
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.bZAdjustment = [sender integerValue];
    _bZVerticalTextField.integerValue = themeToChange.bZAdjustment;
}

- (IBAction)changeBZVerticalTextField:(id)sender {
    if (theme.bZAdjustment == [sender integerValue]) {
        return;
    }
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.bZAdjustment = [sender integerValue];
    _bZVerticalStepper.integerValue = themeToChange.bZAdjustment;
}

#pragma mark Misc menu

- (IBAction)resetDialogs:(NSButton *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:NO forKey:@"terminationAlertSuppression"];
    [defaults setBool:NO forKey:@"UseForAllAlertSuppression"];
    [defaults setBool:NO forKey:@"OverwriteStylesAlertSuppression"];
    [defaults setBool:NO forKey:@"AutorestoreAlertSuppression"];
    [defaults setBool:NO forKey:@"closeAlertSuppression"];
}

- (IBAction)changeSmoothScroll:(id)sender {
    if (theme.smoothScroll == [sender state])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.smoothScroll = [sender state] ? YES : NO;
}

- (IBAction)changeAutosaveOnTimer:(id)sender {
    if (theme.autosaveOnTimer == [sender state])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.autosaveOnTimer = [sender state] ? YES : NO;
}

- (IBAction)changeAutosave:(id)sender {
    if (theme.autosave == [sender state])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.autosave = [sender state] ? YES : NO;
    _btnAutosaveOnTimer.enabled = themeToChange.autosave;
}


- (IBAction)changeTimerSlider:(id)sender {
    _timerTextField.integerValue = [sender integerValue];
    if ([sender integerValue] == 0 || theme.minTimer == 1000.0 / [sender integerValue]) {
        return;
    }
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.minTimer = (1000.0 / [sender integerValue]);
}

- (IBAction)changeTimerTextField:(id)sender {
    _timerSlider.integerValue = [sender integerValue];
    if ([sender integerValue] == 0 || theme.minTimer == 1000.0 / [sender integerValue])
        return;
    Theme *themeToChange = [self cloneThemeIfNotEditable];
    themeToChange.minTimer = (1000.0 / [sender integerValue]);
}

#pragma mark End of Misc menu

- (IBAction)changeOverwriteStyles:(id)sender {
    if ([sender state] == 1) {
        if (![[NSUserDefaults standardUserDefaults] valueForKey:@"OverwriteStylesAlertSuppression"]) {
            NSMutableArray *customStyles = [[NSMutableArray alloc] initWithCapacity:style_NUMSTYLES * 2];
            for (GlkStyle *style in theme.allStyles) {
                if (!style.autogenerated) {
                    [customStyles addObject:style];
                }
            }
            if (customStyles.count) {
                [self showOverwriteStylesAlert:customStyles];
                return;
            }
        }
        [self overWriteStyles];
    }
}

- (void)showOverwriteStylesAlert:(NSArray *)styles {
    NSAlert *anAlert = [[NSAlert alloc] init];
    anAlert.messageText =
    [NSString stringWithFormat:@"This theme uses %ld custom %@.", styles.count, (styles.count == 1) ? @"style" : @"styles"];
    if (styles.count == 1)
        anAlert.informativeText = NSLocalizedString(@"Do you want to replace it with an autogenerated style?", nil);
    else
        anAlert.informativeText = NSLocalizedString(@"Do you want to replace them with autogenerated styles?", nil);

    anAlert.showsSuppressionButton = YES;
    anAlert.suppressionButton.title = NSLocalizedString(@"Do not show again.", nil);
    [anAlert addButtonWithTitle:NSLocalizedString(@"Okay", nil)];
    [anAlert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];

    Preferences * __unsafe_unretained weakSelf = self;

    [anAlert beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        NSString *alertSuppressionKey = @"OverwriteStylesAlertSuppression";

        if (anAlert.suppressionButton.state == NSOnState) {
            // Suppress this alert from now on
            [defaults setBool:YES forKey:alertSuppressionKey];
        }

        if (result == NSAlertFirstButtonReturn) {
            [weakSelf overWriteStyles];
        } else {
            weakSelf.btnOverwriteStyles.state = NSOffState;
        }
    }];
}

- (void)overWriteStyles {
    theme = [self cloneThemeIfNotEditable];
    for (GlkStyle *style in theme.allStyles) {
        style.autogenerated = YES;
    }
    [theme populateStyles];
    [Preferences rebuildTextAttributes];
}

- (IBAction)changeBorderSize:(id)sender {
    if (theme.border == [sender intValue])
        return;
    theme = [self cloneThemeIfNotEditable];
    theme.border = [sender intValue];
}

- (Theme *)cloneThemeIfNotEditable {
    if (!theme.editable) {
//        NSLog(@"Cloned theme %@", theme.name);
        if ([themeDuplicationTimestamp timeIntervalSinceNow] > -0.5 && lastDuplicatedTheme && lastDuplicatedTheme.editable) {
            return lastDuplicatedTheme;
        }

        Theme *clonedTheme = theme.clone;
        clonedTheme.editable = YES;
        NSString *name = [theme.name stringByAppendingString:@" (modified)"];
        NSUInteger counter = 2;
        while ([_arrayController findThemeByName:name]) {
            name = [NSString stringWithFormat:@"%@ (modified) %ld", theme.name, counter++];
        }
        clonedTheme.name = name;
        [self changeThemeName:name];
        _btnRemove.enabled = YES;
        theme = clonedTheme;
        lastDuplicatedTheme = clonedTheme;
        disregardTableSelection = YES;
        [self performSelector:@selector(restoreThemeSelection:) withObject:clonedTheme afterDelay:0.1];
        themeDuplicationTimestamp = [NSDate date];
        return clonedTheme;
    }
    return theme;
}

#pragma mark Zoom

+ (void)zoomIn {
    zoomDirection = ZOOMRESET;
    NSFont *gridroman = theme.gridNormal.font;
    NSLog(@"zoomIn gridroman.pointSize = %f", gridroman.pointSize);

    if (gridroman.pointSize < 200) {
        zoomDirection = ZOOMIN;
        [self scale:(gridroman.pointSize + 1) / gridroman.pointSize];
    }
}

+ (void)zoomOut {
    NSLog(@"zoomOut");
    zoomDirection = ZOOMRESET;
    NSFont *gridroman = theme.gridNormal.font;
    if (gridroman.pointSize > 6) {
        zoomDirection = ZOOMOUT;
        [self scale:(gridroman.pointSize - 1) / gridroman.pointSize];
    }
}

+ (void)zoomToActualSize {
    NSLog(@"zoomToActualSize");
    zoomDirection = ZOOMRESET;

    CGFloat scale;
    Theme *parent = theme.defaultParent;
    while (parent.defaultParent)
        parent = parent.defaultParent;

    if (parent)
        scale = parent.gridNormal.font.pointSize;

    if (scale < 6)
        scale = 12;

    [self scale:scale / theme.gridNormal.font.pointSize];
}

+ (void)scale:(CGFloat)scalefactor {
    NSLog(@"Preferences scale: %f", scalefactor);

    NSFont *gridroman = theme.gridNormal.font;
    NSFont *bufroman = theme.bufferNormal.font;
    NSFont *inputfont = theme.bufInput.font;


    if (scalefactor < 0)
        scalefactor = fabs(scalefactor);

//    if ((scalefactor < 1.01 && scalefactor > 0.99) || scalefactor == 0.0)
////        scalefactor = 1.0;
//        return;

    [prefs cloneThemeIfNotEditable];

    CGFloat fontSize = gridroman.pointSize;
    NSLog(@"fontSize before zoom: %f", fontSize);
    fontSize *= scalefactor;
    NSLog(@"fontSize after zoom: %f", fontSize);

    if (fontSize > 0) {
        theme.gridNormal.font = [NSFont fontWithDescriptor:gridroman.fontDescriptor
                                                      size:fontSize];
    }

    fontSize = bufroman.pointSize;
    fontSize *= scalefactor;
    if (fontSize > 0) {
        theme.bufferNormal.font = [NSFont fontWithDescriptor:bufroman.fontDescriptor
                                                        size:fontSize];
    }

    fontSize = inputfont.pointSize;
    fontSize *= scalefactor;
    if (fontSize > 0) {
        theme.bufInput.font = [NSFont fontWithDescriptor:inputfont.fontDescriptor
                                                    size:fontSize];
    }

    for (GlkStyle *style in theme.allStyles) {
        if (!style.autogenerated) {
            fontSize = style.font.pointSize;
            fontSize *= scalefactor;
            if (fontSize > 0) {
                style.font = [NSFont fontWithDescriptor:style.font.fontDescriptor
                                               size:fontSize];
            }
        }
    }

    [Preferences rebuildTextAttributes];

    /* send notification that default size has changed -- resize all windows */
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"DefaultSizeChanged"
     object:theme];
}

- (void)updatePanelAfterZoom {
    btnGridFont.title = fontToString(theme.gridNormal.font);
    btnBufferFont.title = fontToString(theme.bufferNormal.font);
    btnInputFont.title = fontToString(theme.bufInput.font);
}

#pragma mark Font panel

- (IBAction)showFontPanel:(id)sender {

    selectedFontButton = sender;
    NSFont *selectedFont = nil;
    NSColor *selectedFontColor = nil;
    NSColor *selectedDocumentColor = nil;


    if (sender == btnGridFont) {
        selectedFont = theme.gridNormal.font;
        selectedFontColor = theme.gridNormal.color;
        selectedDocumentColor = theme.gridBackground;
    }
    if (sender == btnBufferFont) {
        selectedFont = theme.bufferNormal.font;
        selectedFontColor = theme.bufferNormal.color;
        selectedDocumentColor = theme.bufferBackground;
    }
    if (sender == btnInputFont) {
        selectedFont = theme.bufInput.font;
        selectedFontColor = theme.bufInput.color;
        selectedDocumentColor = theme.bufferBackground;
    }

    if (selectedFont) {
        NSDictionary *attr =
        @{@"NSColor" : selectedFontColor, @"NSDocumentBackgroundColor" : selectedDocumentColor};

        [self.window makeFirstResponder:self.window];

        [NSFontManager sharedFontManager].target = self;
        [NSFontPanel sharedFontPanel].delegate = self;
        [[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];

        [[NSFontManager sharedFontManager] setSelectedAttributes:attr
                                                      isMultiple:NO];
        [[NSFontManager sharedFontManager] setSelectedFont:selectedFont
                                                isMultiple:NO];
    }
}



- (IBAction)changeFont:(id)fontManager {
    NSFont *newFont = nil;
    if (selectedFontButton) {
        newFont = [fontManager convertFont:[fontManager selectedFont]];
    } else {
        NSLog(@"Error! Preferences changeFont called with no font selected");
        return;
    }

    if (selectedFontButton == btnGridFont) {
        if ([theme.gridNormal.font isEqual:newFont])
            return;
        theme = [self cloneThemeIfNotEditable];
        theme.gridNormal.font = newFont;
        btnGridFont.title = fontToString(newFont);
    } else if (selectedFontButton == btnBufferFont) {
        if ([theme.bufferNormal.font isEqual:newFont])
            return;
        theme = [self cloneThemeIfNotEditable];
        theme.bufferNormal.font = newFont;
        btnBufferFont.title = fontToString(newFont);
    } else if (selectedFontButton == btnInputFont) {
        if ([theme.bufInput.font isEqual:newFont])
            return;
        theme = [self cloneThemeIfNotEditable];
        theme.bufInput.font = newFont;
        btnInputFont.title = fontToString(newFont);
    }

    [Preferences rebuildTextAttributes];
}

// This is sent from the font panel when changing font style there

- (void)changeAttributes:(id)sender {
    NSLog(@"changeAttributes:%@", sender);

    NSDictionary *newAttributes = [sender convertAttributes:@{}];

    NSLog(@"changeAttributes: Keys in newAttributes:");
//    for (NSString *key in newAttributes.allKeys) {
//        NSLog(@" %@ : %@", key, newAttributes[key]);
//    }

    //	"NSForegroundColorAttributeName"	"NSColor"
    //	"NSUnderlineStyleAttributeName"		"NSUnderline"
    //	"NSStrikethroughStyleAttributeName"	"NSStrikethrough"
    //	"NSUnderlineColorAttributeName"		"NSUnderlineColor"
    //	"NSStrikethroughColorAttributeName"	"NSStrikethroughColor"
    //	"NSShadowAttributeName"				"NSShadow"

    if (newAttributes[@"NSColor"]) {
        NSColorWell *colorWell = nil;
        NSFont *currentFont = [NSFontManager sharedFontManager].selectedFont;
        if (currentFont == theme.gridNormal.font)
            colorWell = clrGridFg;
        else if (currentFont == theme.bufferNormal.font)
            colorWell = clrBufferFg;
        else if (currentFont == theme.bufInput.font)
            colorWell = clrInputFg;
        colorWell.color = newAttributes[@"NSColor"];
        [self changeColor:colorWell];
    }
}

// This is sent from the font panel when changing background color there

- (void)changeDocumentBackgroundColor:(id)sender {
    //    NSLog(@"changeDocumentBackgroundColor");

    NSColorWell *colorWell = nil;
    NSFont *currentFont = [NSFontManager sharedFontManager].selectedFont;
    if (currentFont == theme.gridNormal.font)
        colorWell = clrGridBg;
    else if (currentFont == theme.bufferNormal.font)
        colorWell = clrBufferBg;
    else if (currentFont == theme.bufInput.font)
        colorWell = clrBufferBg;
    colorWell.color = [sender color];
    [self changeColor:colorWell];
}

- (NSFontPanelModeMask)validModesForFontPanel:(NSFontPanel *)fontPanel {
    return NSFontPanelAllModesMask;
//    NSFontPanelFaceModeMask | NSFontPanelCollectionModeMask |
//    NSFontPanelSizeModeMask | NSFontPanelTextColorEffectModeMask |
//    NSFontPanelDocumentColorEffectModeMask;
}

- (void)windowWillClose:(id)sender {
    if ([[NSFontPanel sharedFontPanel] isVisible])
        [[NSFontPanel sharedFontPanel] orderOut:self];
    if ([[NSColorPanel sharedColorPanel] isVisible])
        [[NSColorPanel sharedColorPanel] orderOut:self];
}

@end
@class GlkController;
@class GlkHyperlink;

@interface GlkWindow : NSView {
    NSMutableArray *styles;
    NSInteger bgnd;
    NSMutableArray *hyperlinks;
    GlkHyperlink *currentHyperlink;
    NSMutableDictionary *currentTerminators;

    BOOL char_request;
}
@property GlkController *glkctl;
@property(readonly) NSInteger name;

@property NSMutableDictionary *pendingTerminators;
@property BOOL terminatorsPending;

- (instancetype)initWithGlkController:(GlkController *)glkctl
                                 name:(NSInteger)name;
- (void)setStyle:(NSInteger)style
      windowType:(NSInteger)wintype
          enable:(NSInteger *)enable
           value:(NSInteger *)value;
- (BOOL)getStyleVal:(NSInteger)style
               hint:(NSInteger)hint
              value:(NSInteger *)value;
- (BOOL)wantsFocus;
- (void)grabFocus;
- (void)flushDisplay;
- (void)markLastSeen;
- (void)performScroll;
- (void)makeTransparent;
- (void)setBgColor:(NSInteger)bc;
- (void)clear;
- (void)putString:(NSString *)buf style:(NSInteger)style;
- (NSDictionary *)attributesFromStylevalue:(NSInteger)stylevalue;
- (void)moveToColumn:(NSInteger)x row:(NSInteger)y;
- (void)initLine:(NSString *)buf;
- (void)initChar;
- (void)cancelChar;
- (NSString *)cancelLine;
- (void)initMouse;
- (void)cancelMouse;
- (void)setHyperlink:(NSUInteger)linkid;
- (void)initHyperlink;
- (void)cancelHyperlink;

- (void)fillRects:(struct fillrect *)rects count:(NSInteger)n;
- (void)drawImage:(NSImage *)buf
             val1:(NSInteger)v1
             val2:(NSInteger)v2
            width:(NSInteger)w
           height:(NSInteger)h;
- (void)flowBreak;
- (void)prefsDidChange;
- (void)terpDidStop;

- (void)restoreSelection;
- (NSString *)sayMask:(NSUInteger)mask;

@end

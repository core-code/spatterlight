/*
 * Pop up a sheet/panel with more detailed info about a game.
 * This will show the cover art, headline and description.
 * Eventually, this might become the metadata editor.
 */

#import <Cocoa/Cocoa.h>

@class Game, Metadata;

void showInfoForFile(NSString *path, NSDictionary *info);

@class LibController, CoreDataManager;

@interface InfoController : NSWindowController <NSWindowDelegate, NSTextFieldDelegate, NSTextViewDelegate>

@property (weak) Game *game;
@property (weak) LibController *libcontroller;

@property NSString *path;
@property Metadata *meta;

@property BOOL inAnimation;

@property IBOutlet NSTextField *titleField;

- (instancetype)initWithGame:(Game *)game;

// Used for window restoration
- (instancetype)initWithpath:(NSString *)path;

- (void)animateIn:(NSRect)frame;
- (void)hideWindow;

- (void)updateImage;

@end

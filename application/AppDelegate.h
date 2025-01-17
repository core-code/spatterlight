/*
 * Launcher -- the main application controller
 */

#import <Cocoa/Cocoa.h>

@class HelpPanelController, LibController, CoreDataManager;

@class Preferences;

@interface AppDelegate : NSObject <NSWindowDelegate, NSWindowRestoration> 

@property Preferences *prefctl;
@property LibController *libctl;
@property HelpPanelController *helpLicenseWindow;

@property (readonly) CoreDataManager *coreDataManager;

- (IBAction)openDocument:(id)sender;

- (IBAction)showPrefs:(id)sender;
- (IBAction)showLibrary:(id)sender;
- (IBAction)showHelpFile:(id)sender;
- (IBAction)pruneLibrary:(id)sender;

- (void)addToRecents:(NSArray *)URLs;

@end

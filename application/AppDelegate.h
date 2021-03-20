/*
 * Launcher -- the main application controller
 */

@class HelpPanelController;

@interface AppDelegate : NSObject <NSWindowDelegate> 

@property HelpPanelController *helpLicenseWindow;

- (IBAction)showHelpFile:(id)sender;

@end

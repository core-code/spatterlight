/*
 * Application -- the main application controller
 */

#import "HelpPanelController.h"
#import "main.h"

@interface AppDelegate () <NSWindowDelegate> {
    HelpPanelController *_helpLicenseWindow;
}
@end

@implementation AppDelegate

#pragma mark -
#pragma mark License window

- (void)setHelpLicenseWindow:(HelpPanelController *)newValue {
    _helpLicenseWindow = newValue;
}

- (HelpPanelController *)helpLicenseWindow {
    if (!_helpLicenseWindow) {
        _helpLicenseWindow = [[HelpPanelController alloc]
                              initWithWindowNibName:@"HelpPanelController"];
        _helpLicenseWindow.window.identifier = @"licenseWin";
        _helpLicenseWindow.window.minSize = NSMakeSize(290, 200);
    }
    return _helpLicenseWindow;
}

- (IBAction)showHelpFile:(id)sender {
    //    NSLog(@"appdel: showHelpFile('%@')", [sender title]);
    id title = [sender title];
    id pathname = [NSBundle mainBundle].resourcePath;
    id filename =
    [NSString stringWithFormat:@"%@/docs/%@.rtf", pathname, title];

    NSURL *url = [NSURL fileURLWithPath:filename];
    NSError *error;

    if (!_helpLicenseWindow) {
        _helpLicenseWindow = [self helpLicenseWindow];
    }

    NSAttributedString *content = [[NSAttributedString alloc]
                                   initWithURL:url
                                   options:@{ NSDocumentTypeDocumentOption :
                                        NSRTFTextDocumentType }
                                   documentAttributes:nil
                                   error:&error];

    [_helpLicenseWindow showHelpFile:content withTitle:title];
    _helpLicenseWindow.window.representedFilename = filename;
}

@end

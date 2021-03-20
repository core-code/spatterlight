//
//  HelpPanelController.h
//  Spatterlight
//
//  Created by Administrator on 2017-06-23.
//
//


@class HelpScrollView;

@interface HelpPanelController : NSWindowController

@property IBOutlet NSTextView *textView;
@property IBOutlet NSScrollView *scrollView;

- (void)showHelpFile:(NSAttributedString *)text withTitle:(NSString *)title;

- (IBAction)copyButton:(id)sender;

@end

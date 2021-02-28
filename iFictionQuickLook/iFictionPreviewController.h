//
//  iFictionPreviewController.h
//  iFictionQuickLook
//
//  Created by Administrator on 2021-02-15.
//

#import <Cocoa/Cocoa.h>

@class UKSyntaxColor;

@interface iFictionPreviewController : NSViewController

@property UKSyntaxColor *syntaxColorer;

@property (unsafe_unretained) IBOutlet NSTextView *textview;
@property (weak) IBOutlet NSScrollView *scrollview;
@property (weak) IBOutlet NSView *superview;

@end

//
//  FadingView.m
//  Spatterlight
//
//  Created by Administrator on 2020-12-21.
//

#import "FadingView.h"

@implementation FadingView


- (void)fadeOut {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 1;
        self.animator.alphaValue = 0;
    }
    completionHandler:^{
        self.hidden = YES;
        self.alphaValue = 1;
    }];
}
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

@end

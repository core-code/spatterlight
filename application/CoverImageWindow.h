//
//  CoverImageWindow.h
//  Spatterlight
//
//  Created by Administrator on 2021-01-05.
//

#import <Foundation/Foundation.h>

@class GlkController;

NS_ASSUME_NONNULL_BEGIN

@interface CoverImageWindow : NSView

- (void)showLogoWindow;

@property (weak) GlkController* glkctl;

// The logo
/// Used to draw the fading logo
@property NSWindow* logoWindow;
/// The time we started fading the logo
@property NSDate* fadeStart;
/// Used to fade out the logo
@property NSTimer* fadeTimer;

@property NSTimeInterval waitTime;
@property NSTimeInterval fadeTime;

@end

NS_ASSUME_NONNULL_END

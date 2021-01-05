//
//  CoverImageWindow.m
//  Spatterlight
//
//  Created by Administrator on 2021-01-05.
//

#import "CoverImageWindow.h"
#import "GlkController.h"
#import "Theme.h"
#import "Game.h"
#import "Metadata.h"
#import "Image.h"


@implementation CoverImageWindow

// = Showing a logo =

- (NSImage*) resizeLogo: (NSImage*) input {
    NSSize oldSize = [input size];
    NSImage* result = input;

    if (oldSize.width > 512 || oldSize.height > 512) {
        CGFloat scaleFactor;

        if (oldSize.width > oldSize.height) {
            scaleFactor = 512/oldSize.width;
        } else {
            scaleFactor = 512/oldSize.height;
        }

        NSSize newSize = NSMakeSize(scaleFactor * oldSize.width, scaleFactor * oldSize.height);

        result = [[NSImage alloc] initWithSize: newSize];
        [result lockFocus];
        [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];

        [input drawInRect: NSMakeRect(0,0, newSize.width, newSize.height)
                 fromRect: NSMakeRect(0,0, oldSize.width, oldSize.height)
                operation: NSCompositeSourceOver
                 fraction: 1.0];
        [result unlockFocus];
    }

    return result;
}

- (NSImage*) logo {
    NSImage* result = [[NSImage alloc] initWithData:_glkctl.game.metadata.cover.data];
    if (result == nil) return nil;

    return [self resizeLogo: result];
}

- (void) positionLogoWindow {
    // Position relative to the window
    NSRect frame = [[[_glkctl window] contentView] convertRect: [[[_glkctl window] contentView] bounds] toView: nil];
    NSRect windowFrame = [[_glkctl window] frame];

    // Position on screen
    frame.origin.x += windowFrame.origin.x;
    frame.origin.y += windowFrame.origin.y;

    // Position the logo window
    [_logoWindow setFrame: frame
                 display: YES];
}

- (void) showLogoWindow {
    // Fading the logo out like this stops it from flickering
    _waitTime = 1.0;
    _fadeTime = 0.5;
    NSImage* logo = [self logo];

    if (logo == nil) return;
    if (_logoWindow) return;
    if (_fadeTimer) return;

    // Don't show this if this view is not on the screen
    if (_glkctl.theme.coverArtStyle != 0) return;
    if ([_glkctl window] == nil) return;
    if (![[_glkctl window] isVisible]) return;

    // Create the window
    _logoWindow = [[NSWindow alloc] initWithContentRect: [[[_glkctl window] contentView] frame]                // Gets the size, we position later
                                             styleMask: NSBorderlessWindowMask
                                               backing: NSBackingStoreBuffered
                                                 defer: YES];
    [_logoWindow setOpaque: NO];
    [_logoWindow setBackgroundColor: [NSColor clearColor]];

    // Create the image view that goes inside
    NSImageView* fadeContents = [[NSImageView alloc] initWithFrame: [[_logoWindow contentView] frame]];

    [fadeContents setImage: logo];
    [_logoWindow setContentView: fadeContents];

    _fadeTimer = [NSTimer timerWithTimeInterval: _waitTime
                                        target: self
                                      selector: @selector(startToFadeLogo)
                                      userInfo: nil
                                       repeats: NO];
    [[NSRunLoop currentRunLoop] addTimer: _fadeTimer
                                 forMode: NSDefaultRunLoopMode];

    // Position the window correctly
    [self positionLogoWindow];

    // Show the window
    [_logoWindow orderFront: self];
    [[_glkctl window] addChildWindow: _logoWindow
                          ordered: NSWindowAbove];
}

- (void) startToFadeLogo {
    _fadeTimer = nil;

    _fadeTimer = [NSTimer timerWithTimeInterval: 0.01
                                        target: self
                                      selector: @selector(fadeLogo)
                                      userInfo: nil
                                       repeats: YES];
    [[NSRunLoop currentRunLoop] addTimer: _fadeTimer
                                 forMode: NSDefaultRunLoopMode];

    _fadeStart = [NSDate date];
}

- (void) fadeLogo {
    NSTimeInterval timePassed = [[NSDate date] timeIntervalSinceDate: _fadeStart];
    CGFloat fadeAmount = timePassed/_fadeTime;

    if (fadeAmount < 0 || fadeAmount > 1) {
        // Finished fading: get rid of the window + the timer
        [_fadeTimer invalidate];
        _fadeTimer = nil;

        [[_logoWindow parentWindow] removeChildWindow: _logoWindow];
        _logoWindow = nil;

        _fadeStart = nil;
    } else {
        fadeAmount = -2.0*fadeAmount*fadeAmount*fadeAmount + 3.0*fadeAmount*fadeAmount;

        [_logoWindow setAlphaValue: 1.0 - fadeAmount];
    }
}

@end

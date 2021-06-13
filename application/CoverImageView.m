//
//  CoverImageWindow.m
//  Spatterlight
//
//  Created by Administrator on 2021-01-05.
//

#import "CoverImageView.h"
#import "GlkController.h"
#import "CoverImageHandler.h"
#import "Theme.h"
#import "Game.h"
#import "Metadata.h"
#import "Image.h"


@implementation CoverImageView

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)canBecomeKeyView {
    return YES;
}

- (void)keyDown:(NSEvent *)theEvent {
    [_delegate forkInterpreterTask];
}

- (void)mouseDown:(NSEvent *)theEvent {
    [_delegate forkInterpreterTask];
    [super mouseDown:theEvent];
}

- (void)layout {
    if (_image && !_delegate.glkctl.ignoreResizes) {
        [_delegate positionImage];
    }
    [super layout];
}

- (void)createImage {
    Metadata *meta = _delegate.glkctl.game.metadata;

    _image = [[NSImage alloc] initWithData:(NSData *)meta.cover.data];

    NSImageRep *rep = [[_image representations] objectAtIndex:0];
    _sizeInPixels = NSMakeSize(rep.pixelsWide, rep.pixelsHigh);

    self.frame = NSMakeRect(0,0, _image.size.width, _image.size.height);

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.accessibilityLabel = meta.coverArtDescription;

    CALayer *layer = [CALayer layer];
    layer.magnificationFilter = _sizeInPixels.height < 350 ? kCAFilterNearest : kCAFilterTrilinear;
    layer.contents = _image;

    [self setLayer:layer];
}




@end
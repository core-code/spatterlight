//
//  NSImage+Categories.m
//  Spatterlight
//
//  Created by Administrator on 2021-06-02.
//

#include "zimage.h"
#include "spat-mg1.h"
#include "neo.h"


#import "NSImage+Categories.h"

@implementation NSImage (Categories)

- (NSImage *)imageWithTint:(NSColor *)tint {
    NSImage *image = self.copy;
    [image lockFocus];

    [tint set];

    NSRect imageRect = NSMakeRect(0, 0, image.size.width, image.size.height);
    NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);

    [image unlockFocus];

    return image;
}

- (nullable NSBitmapImageRep *)bitmapImageRepresentation {
    NSInteger width = (NSInteger)self.size.width;
    NSInteger height = (NSInteger)self.size.height;

    if(width < 1 || height < 1)
        return nil;

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
                             initWithBitmapDataPlanes:NULL
                             pixelsWide:width
                             pixelsHigh:height
                             bitsPerSample:8
                             samplesPerPixel:4
                             hasAlpha:YES
                             isPlanar:NO
                             colorSpaceName:NSDeviceRGBColorSpace
                             bytesPerRow:width * 4
                             bitsPerPixel:32];

    NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:ctx];
    [self drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    [ctx flushGraphics];
    [NSGraphicsContext restoreGraphicsState];
    return rep;
}

- (nullable NSImage *)resizedToPixelDimensions:(NSSize)newSize
{
    if (!self.isValid) return nil;

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
                             initWithBitmapDataPlanes:NULL
                             pixelsWide:(NSInteger)newSize.width
                             pixelsHigh:(NSInteger)newSize.height
                             bitsPerSample:8
                             samplesPerPixel:4
                             hasAlpha:YES
                             isPlanar:NO
                             colorSpaceName:NSDeviceRGBColorSpace
                             bytesPerRow:0
                             bitsPerPixel:0];
    rep.size = newSize;

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
    [self drawInRect:NSMakeRect(0, 0, newSize.width, newSize.height) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];

    NSImage *newImage = [[NSImage alloc] initWithSize:newSize];
    [newImage addRepresentation:rep];
    return newImage;
}

@end

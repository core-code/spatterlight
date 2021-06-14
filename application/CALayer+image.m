//
//  CALayer+image.m
//  Spatterlight
//
//  Created by Administrator on 2021-06-14.
//

#import "CALayer+image.h"

@implementation CALayer (image)

- (NSImage *)getImage {
    CGImageRef cgImage = [self getCgImage];
    NSImage *nsimage = [[NSImage alloc] initWithCGImage:cgImage size:self.frame.size];
//    CGImageRelease(cgImage);
//    CGContextRelease(cgContext);
    return nsimage;
}


- (CGImageRef)getCgImage {
    NSInteger width = (NSInteger)self.frame.size.width;
    NSInteger height = (NSInteger)self.frame.size.height;

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
                             bytesPerRow:0
                             bitsPerPixel:32];

    NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    CGContextRef cgContext = ctx.CGContext;
    [self renderInContext:cgContext];
    CGImageRef cgImage = CGBitmapContextCreateImage(cgContext);
    return cgImage;
}

@end

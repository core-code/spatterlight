//
//  NSView+snapshot.m
//  DragDrop
//
//  Created by Administrator on 2021-06-04.
//

#import "NSView+snapshot.h"

@implementation NSView (snapshot)

- (NSBitmapImageRep *)snapshotRep {
    NSBitmapImageRep *bitmap = [self bitmapImageRepForCachingDisplayInRect:[self visibleRect]];
    [self cacheDisplayInRect:[self visibleRect] toBitmapImageRep:bitmap];
    return bitmap;
}

- (NSImage *)snapshot {
    NSBitmapImageRep *bitmap = [self snapshotRep];
    if (!bitmap) {
        return nil;
    }
    NSImage *image = [[NSImage alloc] initWithCGImage:bitmap.CGImage size:self.bounds.size];
    return image;
}

@end

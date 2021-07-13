//
//  NSImage+Categories.h
//  Spatterlight
//
//  Created by Administrator on 2021-06-02.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (Categories)

- (NSImage *)imageWithTint:(NSColor *)tint;
- (nullable NSBitmapImageRep *)bitmapImageRepresentation;
- (nullable NSImage *)resizedToPixelDimensions:(NSSize)newSize;

@end

NS_ASSUME_NONNULL_END

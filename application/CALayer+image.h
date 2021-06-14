//
//  CALayer+image.h
//  Spatterlight
//
//  Created by Administrator on 2021-06-14.
//

#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface CALayer (image)

- (NSImage *)getImage;
- (CGImageRef)getCgImage;

@end

NS_ASSUME_NONNULL_END

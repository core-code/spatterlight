//
//  ImageExtractor.h
//  SpatterlightThumbnails
//
//  Created by Administrator on 2021-01-30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageExtractor : NSObject

- (NSImage *)extractImageFromFile:(NSString*)path;

@end

NS_ASSUME_NONNULL_END

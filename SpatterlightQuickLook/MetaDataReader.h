//
//  MetaDataReader.h
//  SpatterlightQuickLook
//
//  Created by Administrator on 2021-01-30.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MetaDataReader : NSObject {
    NSMutableArray *ifidbuf;
    NSMutableDictionary *metabuf;
}

- (instancetype)initWithURL:(NSURL *)url;

@property NSMutableDictionary *metaData;

@end

NS_ASSUME_NONNULL_END

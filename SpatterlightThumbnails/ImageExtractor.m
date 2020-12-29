//
//  ImageExtractor.m
//  SpatterlightThumbnails
//
//  Created by Administrator on 2021-01-30.
//

#import <Cocoa/Cocoa.h>

#include "babel_handler.h"
#include "ifiction.h"
#include "treaty.h"

#import "ImageExtractor.h"

@implementation ImageExtractor

- (NSImage *)extractImageFromFile:(NSString*)path
{
    NSLog(@"extractImageFromFile %@", path);
    char *format;
    int rv;

    NSArray *gGameFileTypes = @[
        @"blb",   @"blorb", @"glb", @"gblorb", @"zlb",    @"zblorb"
    ];

//    if ([[[path pathExtension] lowercaseString] isEqualToString: @"ifiction"])
//    {
//        [self importMetadataFromFile: path];
//        return nil;
//    }


    if (![gGameFileTypes containsObject: [[path pathExtension] lowercaseString]])
    {

        NSLog(@"Can not recognize the file extension.");
        return nil;
    }

    format = babel_init((char*)[path UTF8String]);
    if (!format || !babel_get_authoritative())
    {
        NSLog(@"Babel can not identify the file format.");
        babel_release();
        return nil;
    }

    NSImage *img = nil;
    int imglen;

    imglen = babel_treaty(GET_STORY_FILE_COVER_EXTENT_SEL, NULL, 0);
    if (imglen > 0)
    {
        char *imgbuf = malloc(imglen);
        if (imgbuf) {

            rv = babel_treaty(GET_STORY_FILE_COVER_SEL, imgbuf, imglen);
            NSData *imgdata = [[NSData alloc] initWithBytesNoCopy: imgbuf length: imglen freeWhenDone: YES];
            img = [[NSImage alloc] initWithData: imgdata];
        }
    }

    babel_release();

    return img;
}
@end

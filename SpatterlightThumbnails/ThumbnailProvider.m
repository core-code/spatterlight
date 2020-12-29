//
//  ThumbnailProvider.m
//  SpatterlightThumbnails
//
//  Created by Administrator on 2020-12-29.
//

#import "ThumbnailProvider.h"
#import <Cocoa/Cocoa.h>

//#import "AppDelegate.h"
//#import "CoreDataManager.h"
//#import "Game.h"
//#import "Metadata.h"
//#import "Image.h"

#import "ImageExtractor.h"
#include <math.h>


@implementation ThumbnailProvider

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request completionHandler:(void (^)(QLThumbnailReply * _Nullable, NSError * _Nullable))handler  API_AVAILABLE(macos(10.15)) API_AVAILABLE(macos(10.15)){

    // There are three ways to provide a thumbnail through a QLThumbnailReply. Only one of them should be used.
    NSLog(@"provideThumbnailForFileRequest called");
    // First way: Draw the thumbnail into the current context, set up with AppKit's coordinate system.
    if (@available(macOS 10.15, *)) {
        handler([QLThumbnailReply replyWithContextSize:request.maximumSize currentContextDrawingBlock:^BOOL {
            // Draw the thumbnail here.

//            AppDelegate *appdel = (AppDelegate*)[NSApplication sharedApplication].delegate;
//            CoreDataManager *manager = appdel.coreDataManager;
//            NSManagedObjectContext *context = manager.mainManagedObjectContext;
//
            NSURL *url = request.fileURL;
//
//            NSError *error = nil;
//            NSArray *fetchedObjects;
//
//            NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
//
//            fetchRequest.entity = [NSEntityDescription entityForName:@"Game" inManagedObjectContext:context];
//            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"path like[c] %@", url.path];
//
//            fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
//            if (fetchedObjects == nil) {
//                NSLog(@"ThumbnailProvider: %@",error);
//                return NO;
//            }
//
//            if (fetchedObjects.count == 0) {
//                NSLog(@"ThumbnailProvider: Found no Game object with with path %@", url.path);
//                return NO;
//            }
//
//            Game *game = fetchedObjects[0];
//            
//            NSImage *image = game.metadata.cover.data;
            ImageExtractor *imageExtractor = [[ImageExtractor alloc] init];
            NSImage *image = [imageExtractor extractImageFromFile:url.path];
            if (!image) {
                NSLog(@"image was nil");
                return YES;
            }
            NSSize maximumSize = request.maximumSize;
            NSSize imageSize = [image size];

             // calculate `newImageSize` and `contextSize` such that the image fits perfectly and respects the constraints
            NSSize newImageSize = maximumSize;
            NSSize contextSize = maximumSize;
            CGFloat aspectRatio = imageSize.height / imageSize.width;
            CGFloat proposedHeight = aspectRatio * maximumSize.width;

             if (proposedHeight <= maximumSize.height) {
                 newImageSize.height = proposedHeight;
                 contextSize.height = MAX(floor(proposedHeight), request.minimumSize.height);
             } else {
                 newImageSize.width = maximumSize.height / aspectRatio;
                 contextSize.width = MAX(floor(newImageSize.width), request.minimumSize.width);
             }

            // draw the image centered
            [image drawInRect:NSMakeRect(contextSize.width/2 - newImageSize.width/2,
                                  contextSize.height/2 - newImageSize.height/2,
                                  newImageSize.width,
                                         newImageSize.height)];


            // Return YES if the thumbnail was successfully drawn inside this block.
            return YES;
        }], nil);
    } else {
        // Fallback on earlier versions
    }

    /*

     // Second way: Draw the thumbnail into a context passed to your block, set up with Core Graphics's coordinate system.
     handler([QLThumbnailReply replyWithContextSize:request.maximumSize drawingBlock:^BOOL(CGContextRef  _Nonnull context) {
     // Draw the thumbnail here.

     // Return YES if the thumbnail was successfully drawn inside this block.
     return YES;
     }], nil);

     // Third way: Set an image file URL.
     handler([QLThumbnailReply replyWithImageFileURL:[NSBundle.mainBundle URLForResource:@"fileThumbnail" withExtension:@"jpg"]], nil);

     */
}

@end

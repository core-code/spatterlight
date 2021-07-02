//
//  IFDBDownloader.m
//  Spatterlight
//
//  Created by Administrator on 2019-12-11.
//

#import "IFDBDownloader.h"
#import "IFictionMetadata.h"
#import "Metadata.h"
#import "Image.h"
#import "Game.h"
#import "Ifid.h"
#import "NSData+Categories.h"
#import "ImageCompareViewController.h"
#import "IFDB.h"
#import "NotificationBezel.h"

@interface IFDBDownloader () {
    NSString *coverArtUrl;
}
@end

@implementation IFDBDownloader

- (instancetype)initWithContext:(NSManagedObjectContext *)context {
    self = [super init];
    if (self) {
        _context = context;
    }
    return self;
}

- (BOOL)downloadMetadataForTUID:(NSString*)tuid imageOnly:(BOOL)imageOnly {
    if (!tuid || tuid.length == 0)
        return NO;

    NSURL *url = [NSURL URLWithString:[@"https://ifdb.org/viewgame?ifiction&id=" stringByAppendingString:tuid]];
    return [self downloadMetadataFromURL:url imageOnly:imageOnly];
}

- (BOOL)downloadMetadataForIFID:(NSString*)ifid imageOnly:(BOOL)imageOnly {
    if (!ifid || ifid.length == 0)
        return NO;

    NSURL *url = [NSURL URLWithString:[@"https://ifdb.org/viewgame?ifiction&ifid=" stringByAppendingString:ifid]];
    return [self downloadMetadataFromURL:url imageOnly:imageOnly];
}

- (BOOL)downloadMetadataFor:(Game*)game imageOnly:(BOOL)imageOnly {
    BOOL result = NO;
    if (game.metadata.tuid) {
        result = [self downloadMetadataForTUID:game.metadata.tuid  imageOnly:imageOnly];
    } else {
        result = [self downloadMetadataForIFID:game.ifid imageOnly:imageOnly];
        if (!result) {
            for (Ifid *ifidObj in game.metadata.ifids) {
                result = [self downloadMetadataForIFID:ifidObj.ifidString  imageOnly:imageOnly];
               if (result)
                   break;
            }
        }
    }
    if (result && imageOnly) {
        game.metadata.coverArtURL = coverArtUrl;
    }

    if (!result)
        [IFDBDownloader showNoDataFoundBezel];
    return result;
}

- (BOOL)downloadMetadataFromURL:(NSURL*)url imageOnly:(BOOL)imageOnly {

    if (!url)
        return NO;

    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    NSURLResponse *response = nil;
    NSError *error = nil;

    NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response
                                                     error:&error];
    if (error) {
        if (!data) {
            NSLog(@"Error connecting to url %@: %@", url, [error localizedDescription]);
            return NO;
        }
    }
    else
    {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode == 200 && data) {

            if (imageOnly) {
                coverArtUrl = [IFDBDownloader coverArtUrlFromXMLData:data];
                if (!coverArtUrl.length) {
                    return NO;
                }
            } else {
                IFictionMetadata *result = [[IFictionMetadata alloc] initWithData:data andContext:_context];
                if (!result || result.stories.count == 0) {
                    return NO;
                }
            }
        } else return NO;
    }
    return YES;
}

+ (void)showNoDataFoundBezel {
    dispatch_sync(dispatch_get_main_queue(), ^{
        NotificationBezel *bezel = [[NotificationBezel alloc] initWithScreen:NSScreen.screens.firstObject];
        [bezel showStandardWithText:@"? No data found"];
    });
}

+ (NSString *)coverArtUrlFromXMLData:(NSData *)data {
    NSString *result = @"";
    NSError *error = nil;
    NSXMLDocument *xml =
    [[NSXMLDocument alloc] initWithData:data
                                options:NSXMLDocumentTidyXML
                                  error:&error];
    NSXMLElement *root = xml.rootElement;
    NSXMLElement *namespace = [NSXMLElement namespaceWithName:@"ns" stringValue:@"http://ifdb.org/api/xmlns"];
    [root addNamespace:namespace];
    NSArray *urls = [root nodesForXPath:@"//ns:url" error:&error];
    if (urls.count) {
        NSXMLElement *url = urls.firstObject;
        result = url.stringValue;
    }
    return result;
}

- (BOOL)downloadImageFor:(Metadata *)metadata
{
//    NSLog(@"libctl: download image from url %@", metadata.coverArtURL);

    if (!metadata.coverArtURL)
        return NO;

    Image *img = [self fetchImageForURL:metadata.coverArtURL];

    __block BOOL accepted = NO;

    if (img) {

        dispatch_sync(dispatch_get_main_queue(), ^{

            ImageCompareViewController *imageCompare = [[ImageCompareViewController alloc] initWithNibName:@"ImageCompareViewController" bundle:nil];

            if ([imageCompare userWantsImage:(NSData *)img.data ratherThanImage:(NSData *)metadata.cover.data type:DOWNLOADED]) {
                metadata.cover = img;
                metadata.coverArtDescription = img.imageDescription;
                accepted = YES;
            }
        });

        return accepted;
    }

    NSURL *url = [NSURL URLWithString:metadata.coverArtURL];

    if (!url) {
        NSLog(@"Could not create url from %@", metadata.coverArtURL);
        return NO;
    }

    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    NSURLResponse *response = nil;
    NSError *error = nil;

    NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response
                                                     error:&error];
    if (error) {
        if (!data) {
            NSLog(@"Error connecting to url %@: %@", url, [error localizedDescription]);
            return NO;
        }
    }
    else
    {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode == 200 && data) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                ImageCompareViewController *imageCompare = [[ImageCompareViewController alloc] initWithNibName:@"ImageCompareViewController" bundle:nil];

                if ([imageCompare userWantsImage:data ratherThanImage:(NSData *)metadata.cover.data type:DOWNLOADED]) {
                    [self insertImageData:data inMetadata:metadata];
                    accepted = YES;
                }
            });

        }
    }
    return accepted;
}

- (Image *)insertImageData:(NSData *)data inMetadata:(Metadata *)metadata {
    if ([data isPlaceHolderImage]) {
        NSLog(@"insertImage: image is placeholder!");
        return [self findPlaceHolderInMetadata:metadata imageData:data];
    }

   Image *img = (Image *) [NSEntityDescription
                     insertNewObjectForEntityForName:@"Image"
                     inManagedObjectContext:metadata.managedObjectContext];
    img.data = [data copy];
    img.originalURL = metadata.coverArtURL;
    img.imageDescription = metadata.coverArtDescription;
    metadata.cover = img;
    [metadata.managedObjectContext save:nil];
    return img;
}

- (Image *)findPlaceHolderInMetadata:(Metadata *)metadata imageData:(NSData *)data {
    Image *placeholder = [self fetchImageForURL:@"Placeholder"];
    if (!placeholder) {
        placeholder = (Image *) [NSEntityDescription
                          insertNewObjectForEntityForName:@"Image"
                          inManagedObjectContext:metadata.managedObjectContext];
        placeholder.data = [data copy];
        placeholder.originalURL = @"Placeholder";
        placeholder.imageDescription = @"Inform 7 placeholder cover image: The worn spine of an old book, laying open on top of another open book. Caption: \"Interactive fiction by Inform. Photograph: Scot Campbell\".";
        metadata.cover = placeholder;
        metadata.coverArtDescription = placeholder.imageDescription;
    }
    return placeholder;
}

- (Image *)fetchImageForURL:(NSString *)imgurl {
    NSError *error = nil;
    NSArray *fetchedObjects;

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    fetchRequest.entity = [NSEntityDescription entityForName:@"Image" inManagedObjectContext:_context];

    fetchRequest.includesPropertyValues = NO; //only fetch the managedObjectID
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"originalURL like[c] %@",imgurl];

    fetchedObjects = [_context executeFetchRequest:fetchRequest error:&error];
    if (fetchedObjects == nil) {
        NSLog(@"Problem! %@",error);
    }

    if (fetchedObjects.count > 1) {
        NSLog(@"Found more than one Image with originalURL %@",imgurl);
    }
    else if (fetchedObjects.count == 0) {
    // Found no previously loaded Image object with url imgurl
        return nil;
    }

    return fetchedObjects[0];
}

@end

//
//  PreviewViewController.m
//  SpatterlightQuickLook
//
//  Created by Administrator on 2021-01-29.
//
#import <Cocoa/Cocoa.h>
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>

#import "PreviewViewController.h"
#import <Quartz/Quartz.h>
#import <Cocoa/Cocoa.h>
#import <CoreData/CoreData.h>

#import "Game.h"
#import "Metadata.h"
#import "Image.h"


@interface PreviewViewController () <QLPreviewingController>

@end

@implementation PreviewViewController

- (NSString *)nibName {
    return @"PreviewViewController";
}

- (void)loadView {
    [super loadView];
    NSLog(@"loadView");

    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    // Do any additional setup after loading the view.
}

#pragma mark - Core Data stack

@synthesize persistentContainer = _persistentContainer;

- (NSPersistentContainer *)persistentContainer {
    @synchronized (self) {
        if (_persistentContainer == nil) {
            _persistentContainer = [[NSPersistentContainer alloc] initWithName:@"Spatterlight"];

            NSURL *directory = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.net.ccxvii.spatterlight"];

            NSURL *url = [NSURL fileURLWithPath:[directory.path stringByAppendingPathComponent:@"Spatterlight.storedata"]];

            NSPersistentStoreDescription *description = [[NSPersistentStoreDescription alloc] initWithURL:url];

            description.readOnly = YES;
            description.shouldMigrateStoreAutomatically = NO;

            _persistentContainer.persistentStoreDescriptions = @[ description ];

            NSLog(@"persistentContainer url path:%@", url.path);

            [_persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *description, NSError *error) {
                if (error != nil) {
                    NSLog(@"Failed to load Core Data stack: %@", error);
                    abort();
                }
            }];
        }
    }
    return _persistentContainer;
}

/*
 * Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.
 */
- (void)preparePreviewOfSearchableItemWithIdentifier:(NSString *)identifier queryString:(NSString *)queryString completionHandler:(void (^)(NSError * _Nullable))handler {
    NSLog(@"preparePreviewOfSearchableItemWithIdentifier");
    
    // Perform any setup necessary in order to prepare the view.
    
    // Call the completion handler so Quick Look knows that the preview is fully loaded.
    // Quick Look will display a loading spinner while the completion handler is not called.

    handler(nil);
}


- (void)preparePreviewOfFileAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))handler {
    NSLog(@"preparePreviewOfFileAtURL");
    // Add the supported content types to the QLSupportedContentTypes array in the Info.plist of the extension.
    
    // Perform any setup necessary in order to prepare the view.
    
    // Call the completion handler so Quick Look knows that the preview is fully loaded.
    // Quick Look will display a loading spinner while the completion handler is not called.


    NSManagedObjectContext *context = self.persistentContainer.newBackgroundContext;
    if (!context) {
        NSLog(@"context is nil!");
        handler(nil);
    }

    [context performBlockAndWait:^{
        NSError *error = nil;
        NSArray *fetchedObjects;

        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

        fetchRequest.entity = [NSEntityDescription entityForName:@"Game" inManagedObjectContext:context];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"fileName like[c] %@", url.path.lastPathComponent];

        fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
        if (fetchedObjects == nil) {
            NSLog(@"QuickLook: %@",error);
            handler(nil);
            return;
        }

        if (fetchedObjects.count == 0) {
            NSLog(@"QuickLook: Found no Game object with fileName %@", url.path.lastPathComponent);

            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"path like[c] %@", url.path];

            fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
            if (fetchedObjects == nil) {
                NSLog(@"QuickLook: %@",error);
                handler(nil);
                return;
            }
            if (fetchedObjects.count == 0) {
                NSLog(@"QuickLook: Found no Game object with path %@", url.path);
                fetchRequest.predicate = [NSPredicate predicateWithFormat:@"fileName like[c] %@", url.path.lastPathComponent];
                fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
                if (fetchedObjects.count == 0) {
                    NSLog(@"QuickLook: Found no Game object with file name  %@", url.path.lastPathComponent);
                    handler(nil);
                    return;

                }

            }
        }

        Game *game = fetchedObjects[0];
        NSLog(@"filename: %@", game.fileName);

        //    MetaDataReader *metaDataReader = [[MetaDataReader alloc] initWithURL:url];
        //    NSDictionary *metadata = [metaDataReader.metaData allValues].firstObject;

        Metadata *meta = game.metadata;

        NSDictionary *attributes = [NSEntityDescription
                                    entityForName:@"Metadata"
                                    inManagedObjectContext:context].attributesByName;

        NSMutableDictionary *metadata = [[NSMutableDictionary alloc] initWithCapacity:attributes.count];

        for (NSString *attr in attributes) {
            //NSLog(@"Setting my %@ to %@", attr, [theme valueForKey:attr]);
            [metadata setValue:[meta valueForKey:attr] forKey:attr];
        }
        metadata[@"ifid"] = game.ifid;
        metadata[@"cover"] = game.metadata.cover.data;
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL generatingThumbnail = NO;
            if (metadata[@"cover"]) {
                self.imageView.image = [[NSImage alloc] initWithData:(NSData *)metadata[@"cover"]];
                self.imageView.accessibilityLabel = metadata[@"coverArtDescription"];
            } else {
                generatingThumbnail = YES;
                [self generateThumbnailRepresentationsForURL:url];
            }
            [self sizeImage];
            self.textview.hidden = YES;
            [self updateWithMetadata:metadata];
            [self sizeText];
            double delayInSeconds = 0.01;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self sizeImage];
                [self sizeText];
                if (!generatingThumbnail)
                    self.textview.hidden = NO;
            });
        });
        handler(nil);
    }];
}

- (void)sizeImage {

    self.preferredContentSize = NSMakeSize(582, 296);

    NSSize imgsize;

    if (_imageView.image) {
        imgsize = _originalImageSize;
        if (imgsize.width == 0 || imgsize.height == 0) {
            imgsize = _imageView.image.size;
            _originalImageSize = imgsize;
        }

        CGFloat ratio = imgsize.width / imgsize.height;

        imgsize.height = _imageView.frame.size.height;
        imgsize.width = imgsize.height * ratio;

        CGFloat maxWidth = (self.view.frame.size.width / 3) * 2;
        if (imgsize.width > maxWidth) {
            imgsize.width = maxWidth;
            imgsize.height =  imgsize.width / ratio;
        }
        //        [_imageView setFrameSize:imgsize];
        _imageView.image.size = imgsize;
    } else {
        imgsize = NSMakeSize(1, _imageView.frame.size.height);
    }

    imgsize.height = _imageView.frame.size.height;
    [_imageView setFrameSize:imgsize];

    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowOffset = NSMakeSize(1, -1);
    shadow.shadowColor = [NSColor controlShadowColor];
    shadow.shadowBlurRadius = 1;
    _imageView.wantsLayer = YES;
    _imageView.superview.wantsLayer = YES;
    _imageView.shadow = shadow;
}

- (void)sizeText {

    NSScrollView *scrollView = _textview.enclosingScrollView;
    NSRect frame = scrollView.frame;
    frame.origin.x = NSMaxX(_imageView.frame) + 10;
    frame.size.width = self.view.frame.size.width - frame.origin.x - 20;
    [_textview.layoutManager glyphRangeForTextContainer:_textview.textContainer];
    CGFloat textHeight = [_textview.layoutManager
                          usedRectForTextContainer:_textview.textContainer].size.height;
    if (textHeight < self.view.frame.size.height - 50) {
        frame.size.height = MIN(textHeight + _textview.textContainer.lineFragmentPadding * 2, self.view.frame.size.height);
        frame.origin.y = ceil((self.view.frame.size.height - textHeight) / 2);
    }
    if (frame.size.width < 50) {
        frame.size.width = scrollView.frame.size.width;
    }

    if (frame.size.height > self.view.frame.size.height) {
        frame.size.height = self.view.frame.size.height - 50;
        frame.origin.y = 0;
    }

    NSLog(@"New scrollview frame: %@", NSStringFromRect(frame));
    NSLog(@"Superview frame: %@", NSStringFromRect(self.view.frame));

    scrollView.frame = frame;
    [scrollView.contentView scrollToPoint:NSZeroPoint];
}

- (void)updateWithMetadata:(NSDictionary *)metadict {

    if (metadict) {
        NSFont *systemFont = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
        NSMutableDictionary *attrDict = [[NSMutableDictionary alloc] init];
        attrDict[NSFontAttributeName] = systemFont;
        attrDict[NSForegroundColorAttributeName] = [NSColor controlTextColor];
        [self addInfoLine:metadict[@"title"] attributes:attrDict linebreak:NO];
        attrDict[NSFontAttributeName] = [NSFont systemFontOfSize:[NSFont systemFontSize]];
        [self addInfoLine:metadict[@"headline"] attributes:attrDict linebreak:YES];
        [self addInfoLine:metadict[@"author"] attributes:attrDict linebreak:YES];
        [self addInfoLine:metadict[@"blurb"] attributes:attrDict linebreak:YES];
        attrDict[NSFontAttributeName] = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
        [self addInfoLine:[@"IFID: " stringByAppendingString:metadict[@"ifid"]] attributes:attrDict linebreak:YES];
    }
}

- (void)addInfoLine:(NSString *)string attributes:(NSDictionary *)attrDict linebreak:(BOOL)linebreak {
    if (string == nil || string.length == 0)
        return;
    NSTextStorage *textstorage = _textview.textStorage;
    if (linebreak)
        string = [@"\n\n" stringByAppendingString:string];
    NSAttributedString *attString = [[NSAttributedString alloc] initWithString:string attributes:attrDict];
    [textstorage appendAttributedString:attString];
}

- (void)generateThumbnailRepresentationsForURL:(NSURL *)url {

    // Set up the parameters of the request.
    CGSize size = NSMakeSize(60, 90);
    CGFloat scale = [NSScreen mainScreen].backingScaleFactor;

    // Create the thumbnail request.
    if (@available(macOS 10.15, *)) {
        QLThumbnailGenerationRequest *request = [[QLThumbnailGenerationRequest alloc] initWithFileAtURL:url size:size scale:scale representationTypes:QLThumbnailGenerationRequestRepresentationTypeAll];

        QLThumbnailGenerator *generator = [QLThumbnailGenerator sharedGenerator];

        __unsafe_unretained PreviewViewController *weakSelf = self;

        [generator generateBestRepresentationForRequest:request completionHandler:^(QLThumbnailRepresentation *thumbnail, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (thumbnail == nil || error != nil) {
                    NSLog(@"Failed to generate thumbnail!");
                    // Handle the error case gracefully.60
                } else {
                    // Display the thumbnail that you created.
                    NSLog(@"Generated thumbnail!");
                    weakSelf.imageView.image = thumbnail.NSImage;
                    [weakSelf.imageView setFrameSize:NSMakeSize(256,256)];
                    NSLog(@"self.imageView.image.size %@", NSStringFromSize(weakSelf.imageView.image.size));
                    NSLog(@"self.imageView.frame.size %@", NSStringFromSize(weakSelf.imageView.frame.size));
                    [weakSelf sizeText];
                    weakSelf.textview.hidden = NO;

                }
            });
        }];
    } else NSLog(@"QLThumbnailGenerationRequest not available!");
}

@end


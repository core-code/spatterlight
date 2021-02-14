//
//  PreviewViewController.m
//  SpatterlightQuickLook
//
//  Created by Administrator on 2021-01-29.
//
#import <Cocoa/Cocoa.h>
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>

#import <Quartz/Quartz.h>
#import <Cocoa/Cocoa.h>
#import <CoreData/CoreData.h>

#import "Game.h"
#import "Metadata.h"
#import "Image.h"

#import "PreviewViewController.h"

#import "YazIFBibliographic.h"
#import "YazIFIdentification.h"
#import "YazIFStory.h"
#import "YazIFictionMetadata.h"
#import "LibraryEntry.h"

#import "NSDate+relative.h"

#import "UKSyntaxColor.h"

#import "Blorb.h"

/* the treaty of babel headers */
#include "babel_handler.h"

@interface MyTextView : NSTextView

@property BOOL darkMode;
@end

@implementation MyTextView

- (void)viewDidChangeEffectiveAppearance {

    NSString *name = self.effectiveAppearance.name;
    UKSyntaxColor *syntaxColorer = ((PreviewViewController *)self.delegate).syntaxColorer;
    if ([name containsString:@"Dark"]) {
        if (syntaxColorer && !_darkMode) { // Changed to dark mode
            syntaxColorer.darkMode = YES;
            [syntaxColorer recolorCompleteFile:nil];
            [self.textStorage setAttributedString:syntaxColorer.coloredString];
        }
        _darkMode = YES;
    } else {
        if (syntaxColorer && _darkMode) { // Changed to light mode
            syntaxColorer.darkMode = NO;
            [syntaxColorer recolorCompleteFile:nil];
            [self.textStorage setAttributedString:syntaxColorer.coloredString];
        }
        _darkMode = NO;
    }
}

@end

@interface ConstraintLessView : NSView

- (void)addSizableMasks;

- (void)removeAllConstraints;

@end

@implementation ConstraintLessView

- (void)removeAllConstraints
{
    NSView *superview = self.superview;
    while (superview != nil) {
        for (NSLayoutConstraint *c in superview.constraints) {
            if (c.firstItem == self || c.secondItem == self) {
                [superview removeConstraint:c];
            }
        }
        superview = superview.superview;
    }

    [self removeConstraints:self.constraints];
    self.translatesAutoresizingMaskIntoConstraints = YES;
}

- (void)addSizableMasks {
    self.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
}

@end



@interface PreviewViewController () <QLPreviewingController, NSTextViewDelegate>

@end

@implementation PreviewViewController

- (NSString *)nibName {
    return @"PreviewViewController";
}

- (void)loadView {
    [super loadView];
    NSLog(@"loadView");
    NSLog(@"self.view.frame %@", NSStringFromRect(self.view.frame));
    _textview.darkMode = [_textview.effectiveAppearance.name containsString:@"Dark"];

    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    _preferredWidth = 582;
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
    NSLog(@"Identifier: %@", identifier );
    NSLog(@"queryString: %@", queryString );


    // Perform any setup necessary in order to prepare the view.
    
    // Call the completion handler so Quick Look knows that the preview is fully loaded.
    // Quick Look will display a loading spinner while the completion handler is not called.

    handler(nil);
}

- (void)showXML:(NSURL *)url handler:(void (^)(NSError *))handler {
    NSLog(@"showXML");
    NSError *error = nil;
    _textview.textColor  = [NSColor controlTextColor];
    NSXMLDocument *xml =
    [[NSXMLDocument alloc] initWithContentsOfURL:url options: NSXMLDocumentTidyXML error:&error];

    if (error)
        NSLog(@"Error: %@", error);

    NSString *contents = [xml XMLStringWithOptions:NSXMLNodePrettyPrint];
    if (!contents || !contents.length) {
        contents = @"<No iFiction data found in file>";
    }
    NSURL *directory = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.net.ccxvii.spatterlight"];

    NSURL *plisturl = [NSURL fileURLWithPath:[directory.path stringByAppendingPathComponent:@"XML.plist"]];

    _syntaxColorer = [[UKSyntaxColor alloc] initWithString:contents];

    if (@available(macOS 10.13, *)) {
        _syntaxColorer.syntaxDefinitionDictionary = [NSDictionary dictionaryWithContentsOfURL:plisturl error:&error];
    }

    if (error)
        NSLog(@"Error: %@", error);

    NSMutableDictionary *defaultText = [NSMutableDictionary new];

    NSMutableParagraphStyle *style;

    if (@available(macOS 10.15, *)) {
        defaultText[NSFontAttributeName] = [NSFont systemFontOfSize:[NSFont systemFontSize] weight:NSFontWeightRegular];
        style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        style.firstLineHeadIndent = 0;
        style.headIndent = 60;
        defaultText[NSParagraphStyleAttributeName] = style;
    }

    _syntaxColorer.defaultTextAttributes = defaultText;

    _syntaxColorer.darkMode = _textview.darkMode;
    [_syntaxColorer recolorCompleteFile:nil];

    NSView *superview = _imageView.superview;


    __block NSString *blockcontents = contents;
    __unsafe_unretained PreviewViewController *weakSelf = self;

    __block NSScrollView *scrollView = weakSelf.textview.enclosingScrollView;


    dispatch_async(dispatch_get_main_queue(), ^{

        //        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, 846);

        NSRect frame = NSZeroRect;

        frame.size = superview.frame.size;
        scrollView.frame = frame;
        scrollView.contentView.frame = frame;
        weakSelf.textview.frame = NSMakeRect(0, 0, scrollView.frame.size.width, MAXFLOAT);
        [weakSelf.imageView removeFromSuperview];
        [weakSelf.textview.textStorage setAttributedString:weakSelf.syntaxColorer.coloredString];
        [scrollView removeFromSuperview];
        [superview addSubview:scrollView];
        weakSelf.textview.drawsBackground = YES;



        //    [superview addSubview:scrollView];
    });


    double delayInSeconds = 0.2;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        //

        //    while (superview.superview != self.view) {
        //        NSView *supersuper = superview.superview;
        //        [superview removeFromSuperview];
        //        superview = supersuper;
        //    }


        //    superview.frame = frame;


        //    superview.frame = self.view.bounds;


        //    [self.view setFrameSize:NSMakeSize(820, 846)];



        //    NSLog(@"Setting scrollview frame to %@", NSStringFromRect(scrollView.frame));


        //    ConstraintLessView *constraintLessView = (ConstraintLessView *)self.view;
        //
        //    [constraintLessView removeAllConstraints];
        //    [constraintLessView addSizableMasks];
        //
        ////    superview.frame = NSMakeRect(0,0, 820, 846);
        ////    scrollView.frame = superview.frame;
        //

        NSRect frame = NSZeroRect;

        frame.size = superview.frame.size;
        scrollView.frame = frame;
        scrollView.contentView.frame = frame;
        self.textview.frame = NSMakeRect(0, 0, scrollView.frame.size.width, MAXFLOAT);
        scrollView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;

        //        [weakSelf.textview.textStorage setAttributedString:weakSelf.syntaxColorer.coloredString];



        handler(nil);

        //    if (scrollView.frame.origin.x < 0)
        //        scrollView.frame = NSMakeRect(0,0, scrollView.superview.frame.size.width, scrollView.superview.frame.size.height);
        //    NSLog(@"Setting scrollview frame to %@", NSStringFromRect(scrollView.frame));
    });


    //    [self.view.superview addConstraint:[NSLayoutConstraint constraintWithItem:scrollView
    //                                                         attribute:NSLayoutAttributeLeft
    //                                                         relatedBy:NSLayoutRelationEqual
    //                                                            toItem:self.view.superview
    //                                                         attribute:NSLayoutAttributeLeft
    //                                                        multiplier:1.0
    //                                                          constant:0]];
    //
    //    [self.view.superview addConstraint:[NSLayoutConstraint constraintWithItem:scrollView
    //                                                         attribute:NSLayoutAttributeRight
    //                                                         relatedBy:NSLayoutRelationEqual
    //                                                            toItem:self.view.superview
    //                                                         attribute:NSLayoutAttributeRight
    //                                                        multiplier:1.0
    //                                                          constant:0]];
    //
    //    [self.view.superview addConstraint:[NSLayoutConstraint constraintWithItem:scrollView
    //                                                         attribute:NSLayoutAttributeTop
    //                                                         relatedBy:NSLayoutRelationEqual
    //                                                            toItem:self.view.superview
    //                                                         attribute:NSLayoutAttributeTop
    //                                                        multiplier:1.0
    //                                                          constant:0]];

    //    scrollView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    //    superview.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    //    self.view.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;

    //    [self turnOffWrapping];
    //    _textview.string = contents;
    //    double delayInSeconds = 0.2;
    //    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    //    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    //        self.preferredContentSize = NSZeroSize;
    //    });
    //    self.preferredContentSize = NSZeroSize;
    //    [self.view.window setContentSize:NSMakeSize(820, 846)];
    //    NSRect frame = self.view.window.frame;
    //    frame.size = NSMakeSize(820, 846);
    //    [self.view.window setFrame:frame display:YES];
    //    NSView *newSuper = scrollView.superview;
    //    newSuper.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
}

//-(void) turnOffWrapping
//{
//    const float            LargeNumberForText = 1.0e7;
//    NSTextContainer*    textContainer = [_textview textContainer];
//    NSRect                frame;
//    NSScrollView*        scrollView = [_textview enclosingScrollView];
//
//    // Make sure we can see right edge of line:
//    [scrollView setHasHorizontalScroller:YES];
//
//    // Make text container so wide it won't wrap:
//    [textContainer setContainerSize: NSMakeSize(LargeNumberForText, LargeNumberForText)];
//    [textContainer setWidthTracksTextView:NO];
//    [textContainer setHeightTracksTextView:NO];
//
//    // Make sure text view is wide enough:
//    frame.origin = NSMakePoint(0.0, 0.0);
//    frame.size = [scrollView contentSize];
//
//    [_textview setMaxSize:NSMakeSize(LargeNumberForText, LargeNumberForText)];
//    [_textview setHorizontallyResizable:YES];
//    [_textview setVerticallyResizable:YES];
//    [_textview setAutoresizingMask:NSViewNotSizable];
//}

- (void)preparePreviewOfFileAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))handler {
    NSLog(@"preparePreviewOfFileAtURL");
    NSLog(@"self.view.frame %@", NSStringFromRect(self.view.frame));


    _ifid = nil;
    _addedFileInfo = NO;
    _showingIcon = NO;
    // Add the supported content types to the QLSupportedContentTypes array in the Info.plist of the extension.
    
    // Perform any setup necessary in order to prepare the view.
    
    // Call the completion handler so Quick Look knows that the preview is fully loaded.
    // Quick Look will display a loading spinner while the completion handler is not called.

    if ([url.path.pathExtension.lowercaseString isEqualToString:@"ifiction"]) {
        [self showXML:url handler:handler];
        handler(nil);
        return;
    }

    NSManagedObjectContext *context = self.persistentContainer.newBackgroundContext;
    if (!context) {
        NSLog(@"context is nil!");
        [self noPreviewForURL:url handler:handler];
        return;
    }

    __block NSMutableDictionary *metadata = nil;

    __unsafe_unretained PreviewViewController *weakSelf = self;
    [context performBlockAndWait:^{
        NSError *error = nil;
        NSArray *fetchedObjects;

        NSFetchRequest *fetchRequest = [NSFetchRequest new];

        fetchRequest.entity = [NSEntityDescription entityForName:@"Game" inManagedObjectContext:context];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"fileName like[c] %@", url.path.lastPathComponent];

        fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
        if (fetchedObjects == nil) {
            NSLog(@"QuickLook: %@",error);
            [weakSelf noPreviewForURL:url handler:handler];
            return;
        }

        if (fetchedObjects.count == 0) {
            NSLog(@"QuickLook: Found no Game object with fileName %@", url.path.lastPathComponent);

            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"path like[c] %@", url.path];

            fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
            if (fetchedObjects == nil) {
                NSLog(@"QuickLook: %@",error);
                [weakSelf noPreviewForURL:url handler:handler];
                return;
            }
            if (fetchedObjects.count == 0) {
                NSLog(@"QuickLook: Found no Game object with path %@", url.path);
                weakSelf.ifid = [weakSelf ifidFromFile:url.path];
                if (weakSelf.ifid) {
                    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"ifid like[c] %@", weakSelf.ifid];
                    fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
                }
                if (fetchedObjects.count == 0) {
                    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"fileName like[c] %@", url.path.lastPathComponent];
                    fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
                }
                if (fetchedObjects.count == 0) {
                    NSLog(@"QuickLook: Found no Game object with file name  %@", url.path.lastPathComponent);
                    metadata = [weakSelf metadataFromURL:url];
                    if (metadata == nil || metadata.count == 0) {
                        [weakSelf noPreviewForURL:url handler:handler];
                        return;
                    } else NSLog(@"Found metadata in blorb");
                }
            }
        }


        if (metadata == nil || metadata.count == 0) {

            Game *game = fetchedObjects[0];
            Metadata *meta = game.metadata;

            NSDictionary *attributes = [NSEntityDescription
                                        entityForName:@"Metadata"
                                        inManagedObjectContext:context].attributesByName;

            metadata = [[NSMutableDictionary alloc] initWithCapacity:attributes.count];

            for (NSString *attr in attributes) {
                //NSLog(@"Setting my %@ to %@", attr, [theme valueForKey:attr]);
                [metadata setValue:[meta valueForKey:attr] forKey:attr];
            }
            metadata[@"ifid"] = game.ifid;
            metadata[@"cover"] = game.metadata.cover.data;
            metadata[@"lastPlayed"] = game.lastPlayed;
        }

    }];

    if (metadata == nil || metadata.count == 0) {
        [weakSelf noPreviewForURL:url handler:handler];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (metadata[@"cover"]) {
            weakSelf.imageView.image = [[NSImage alloc] initWithData:(NSData *)metadata[@"cover"]];
            weakSelf.imageView.accessibilityLabel = metadata[@"coverArtDescription"];
        } else {
            weakSelf.showingIcon = YES;
            weakSelf.imageView.image = [[NSWorkspace sharedWorkspace] iconForFile:url.path];
        }

        NSSize viewSize = self.view.frame.size;
        if (viewSize.width - viewSize.height > 20 ) {
            [self tryToStretchWindow];
        }

        [weakSelf sizeImage];
        weakSelf.textview.hidden = YES;
        [weakSelf updateWithMetadata:metadata url:url];
        if (metadata.count <= 2)
            [self addFileInfo:url];
        else
            NSLog(@"Metadata count: %ld", metadata.count);
        [self sizeText];
        double delayInSeconds = 0.1;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self sizeText];
            self.textview.hidden = NO;
            [self printFinalLayout];
        });
        //            delayInSeconds = 0.2;
        //            popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        //            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        //                [weakSelf sizeText];
        //            });

    });
    handler(nil);

}

- (void)printFinalLayout{
    //    if (self.view.frame.size.height > 296) {
    //        //        double delayInSeconds = 1;
    //        //        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    //        //        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    //        self.preferredContentSize = NSMakeSize(self.view.frame.size.width, 296);
    //        //        });
    //    }
    NSLog(@"Final layout: view size: %@ image view frame %@ scroll view frame:%@", NSStringFromSize(self.view.frame.size), NSStringFromRect(_imageView.frame), NSStringFromRect(_textview.enclosingScrollView.frame));
}



- (void)sizeImageToFitWidth:(CGFloat)maxWidth height:(CGFloat)maxHeight {

    NSSize imgsize;

    imgsize = _originalImageSize;
    if (imgsize.width == 0 || imgsize.height == 0) {
        imgsize = _imageView.image.size;
        _originalImageSize = imgsize;
    }

    if (imgsize.height == 0)
        return;

    CGFloat ratio = imgsize.width / imgsize.height;

    imgsize.height = maxHeight;
    imgsize.width = imgsize.height * ratio;

    if (imgsize.width > maxWidth) {
        imgsize.width = maxWidth;
        imgsize.height =  imgsize.width / ratio;
    }

    _imageView.image.size = imgsize;

    //    imgsize.height = self.view.frame.size.height;
    [_imageView setFrameSize:imgsize];
}


- (void)sizeImage {
    if (!_imageView.image)
        return;
    _imageView.imageScaling = NSImageScaleProportionallyUpOrDown
    ;
    NSSize viewSize = self.view.frame.size;
    if (viewSize.width - viewSize.height > 20 ) {
        [self sizeImageHorizontally];
    } else [self sizeImageVertically];

    [self imageShadow];
}

- (void)imageShadow {
    NSShadow *shadow = [NSShadow new];
    shadow.shadowOffset = NSMakeSize(1, -1);
    shadow.shadowColor = [NSColor controlShadowColor];
    shadow.shadowBlurRadius = 1;
    _imageView.wantsLayer = YES;
    _imageView.superview.wantsLayer = YES;
    _imageView.shadow = shadow;
}

- (void)sizeImageHorizontally {

    NSSize viewSize = self.view.frame.size;

    [self sizeImageToFitWidth:round(2 * viewSize.width / 3 - 40) height:256];
    _imageView.imageAlignment =  NSImageAlignLeft;
    NSRect frame = _imageView.frame;
    frame.size.height = viewSize.height;
    frame.size.width = _imageView.image.size.width;
    frame.origin.y = 0;
    frame.origin.x = 20;
    _imageView.frame = frame;
    // 256 is the default height of Finder file previews minus margins
}

- (void)sizeImageVertically {
    NSLog(@"sizeImageVertically");
    NSSize viewSize = self.view.frame.size;

    [_imageView removeFromSuperview];
    //We want the image to be at  amost two thirds of the view height
    [self sizeImageToFitWidth:viewSize.width - 40 height:round(viewSize.height / 2)];
    // 256 is the default height of Finder file previews minus margins

    NSRect frame = _imageView.frame;
    frame.size.height = _imageView.image.size.height + 20;
    frame.size.width = viewSize.width - 40;
    frame.origin.y = viewSize.height - frame.size.height - 20;
    frame.origin.x = 20;
    _imageView.frame = frame;
    _imageView.imageAlignment =  NSImageAlignTopLeft;
    [self.view addSubview:_imageView];
}


- (void)sizeText {
    NSSize viewSize = self.view.frame.size;
    if (viewSize.width - viewSize.height > 20 ) {
        [self sizeTextHorizontally];
    } else [self sizeTextVertically];
}



- (void)tryToStretchWindow {
    CGFloat preferredWindowWidth = 612;
    CGFloat preferredWindowHeight = 296;
    CGFloat preferredImageWidth = 408;
    CGFloat preferredImageHeight = 256;

    NSSize imgsize;

    imgsize = _originalImageSize;
    if (imgsize.width == 0 || imgsize.height == 0) {
        imgsize = _imageView.image.size;
        _originalImageSize = imgsize;
    }

    if (imgsize.height == 0)
        return;

    CGFloat ratio = imgsize.width / imgsize.height;
    if (preferredImageHeight * ratio > preferredImageWidth && !self.showingIcon) {
        preferredWindowWidth = round(preferredWindowHeight * ratio * 1.5);
        NSLog(@"Image too wide! 256 * ratio (%f) = %f > 408. Trying to stretch window to width %f", ratio, 256 * ratio, preferredWindowWidth);
    }

    if (preferredWindowWidth > self.view.window.screen.visibleFrame.size.width / 3)
        preferredWindowWidth = self.view.window.screen.visibleFrame.size.width / 3;

    self.preferredContentSize = NSMakeSize(preferredWindowWidth, preferredWindowHeight);
}

- (void)sizeTextHorizontally {
    NSScrollView *scrollView = _textview.enclosingScrollView;
    NSRect frame = scrollView.frame;

    // The icon image usually has horizontal padding built-in
    frame.origin.x = NSMaxX(_imageView.frame) + (_showingIcon ? 10 : 20);
    frame.size.width = self.view.frame.size.width - frame.origin.x - 20;
    scrollView.frame = frame;

    [_textview.layoutManager glyphRangeForTextContainer:_textview.textContainer];
    CGFloat textHeight = [_textview.layoutManager
                          usedRectForTextContainer:_textview.textContainer].size.height;
    if (textHeight < self.view.frame.size.height - 50) {
        frame.size.height = MIN(textHeight + _textview.textContainerInset.height * 2, self.view.frame.size.height - 20);
        frame.origin.y = ceil((self.view.frame.size.height - textHeight) / 2);
        if (frame.origin.y < 0)
            frame.origin.y = 0;
    }

    scrollView.frame = frame;

    //    NSLog(@"New scrollview frame: %@", NSStringFromRect(frame));
    //    NSLog(@"Superview frame: %@", NSStringFromRect(self.view.frame));

    [scrollView.contentView scrollToPoint:NSZeroPoint];
}

- (void)sizeTextVertically {
    NSLog(@"sizeTextVertically");

    NSScrollView *scrollView = _textview.enclosingScrollView;
    NSRect frame = scrollView.frame;

    NSSize viewSize = self.view.frame.size;

    frame.size.height = viewSize.height - _imageView.frame.size.height - 20;

    if (frame.size.height < viewSize.height / 2 - 20)
    {
        NSLog(@"That is too small! Trying to resize image height to %f", round (viewSize.height / 2));
        [self sizeImageToFitWidth:self.view.frame.size.width height:round (viewSize.height / 2)];
        frame.size.height = viewSize.height - _imageView.frame.size.height - 20;
        NSLog(@"New height %f", frame.size.height);
    }

    frame.origin = NSMakePoint(20, 0);

    scrollView.frame = frame;
    [scrollView.contentView scrollToPoint:NSZeroPoint];
}

- (void)updateWithMetadata:(NSDictionary *)metadict url:(NSURL *)url {

    if (metadict && metadict.count) {
        NSFont *systemFont = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
        NSMutableDictionary *attrDict = [NSMutableDictionary new];
        attrDict[NSFontAttributeName] = systemFont;
        attrDict[NSForegroundColorAttributeName] = [NSColor controlTextColor];
        [self addInfoLine:metadict[@"title"] attributes:attrDict linebreak:NO];

        if (!metadict[@"title"]) {
            [self addInfoLine:url.path.lastPathComponent attributes:attrDict linebreak:YES];
            if (metadict[@"IFhd"]) {
                attrDict[NSFontAttributeName] = [NSFont systemFontOfSize:[NSFont systemFontSize]];
                NSString *resBlorbStr = @"Resource associated with game ";
                if (metadict[@"IFhdTitle"])
                    resBlorbStr = [resBlorbStr stringByAppendingString:metadict[@"IFhdTitle"]];
                else
                    resBlorbStr = [resBlorbStr stringByAppendingString:metadict[@"IFhd"]];
                [self addInfoLine:resBlorbStr attributes:attrDict linebreak:YES];
            }
        }
        [self addStarRating:metadict];
        attrDict[NSFontAttributeName] = [NSFont systemFontOfSize:[NSFont systemFontSize]];
        [self addInfoLine:metadict[@"headline"] attributes:attrDict linebreak:YES];
        [self addInfoLine:metadict[@"author"] attributes:attrDict linebreak:YES];
        [self addInfoLine:metadict[@"blurb"] attributes:attrDict linebreak:YES];
        NSDate * lastPlayed = metadict[@"lastPlayed"];
        if (lastPlayed) {
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.dateFormat = @"dd MMM yyyy HH.mm";
            [self addInfoLine:[NSString stringWithFormat:@"Last played %@", [formatter stringFromDate:lastPlayed]] attributes:attrDict linebreak:YES];
        }
        BOOL noMeta = (metadict[@"headline"] == nil && metadict[@"author"] == nil && metadict[@"blurb"] == nil);

        if (!noMeta) {
            attrDict[NSFontAttributeName] = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
        } else {
            attrDict[NSFontAttributeName] = [NSFont systemFontOfSize:[NSFont systemFontSize]];
        }
        if  (metadict[@"ifid"])
            [self addInfoLine:[@"IFID: " stringByAppendingString:metadict[@"ifid"]] attributes:attrDict linebreak:YES];
        if (noMeta)
            [self addFileInfo:url];
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


- (void)addStarRating:(NSDictionary *)dict {
    //+ (NSAttributedString *)starWithRating:(CGFloat)rating
    //                            outOfTotal:(NSInteger)totalNumberOfStars
    //                          withFontSize:(CGFloat) fontSize {
    NSInteger rating = NSNotFound;
    if (dict[@"myRating"]) {
        rating = ((NSNumber *)dict[@"myRating"]).integerValue;
    } else if  (dict[@"starRating"]) {
        rating = ((NSNumber *)dict[@"starRating"]).integerValue;
    }

    if (rating == NSNotFound)
        return;

    NSUInteger totalNumberOfStars = 5;
    NSFont *currentFont = [NSFont fontWithName:@"SF Pro" size:12];
    if (!currentFont)
        currentFont = [NSFont systemFontOfSize:20 weight:NSFontWeightRegular];

    if (@available(macOS 10.13, *)) {
        NSDictionary *activeStarFormat = @{
            NSFontAttributeName : currentFont,
            NSForegroundColorAttributeName : [NSColor colorNamed:@"customControlColor"]
        };
        NSDictionary *inactiveStarFormat = @{
            NSFontAttributeName : currentFont,
            NSForegroundColorAttributeName : [NSColor colorNamed:@"customControlColor"]
        };

        NSMutableAttributedString *starString = [NSMutableAttributedString new];
        [starString appendAttributedString:[[NSAttributedString alloc]
                                            initWithString:@"\n\n" attributes:activeStarFormat]];

        for (int i=0; i < totalNumberOfStars; ++i) {
            //Full star
            if (rating >= i+1) {
                [starString appendAttributedString:[[NSAttributedString alloc]
                                                    initWithString:@"􀋃 " attributes:activeStarFormat]];
            }
            //Half star
            else if (rating > i) {
                [starString appendAttributedString:[[NSAttributedString alloc]
                                                    initWithString:@"􀋄 " attributes:activeStarFormat]];
            }
            // Grey star
            else {
                [starString appendAttributedString:[[NSAttributedString alloc]
                                                    initWithString:@"􀋂 " attributes:inactiveStarFormat]];
            }
        }
        [_textview.textStorage appendAttributedString:starString];
    }
}

- (NSString *) unitStringFromBytes:(CGFloat)bytes {
    static const char units[] = { '\0', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y' };
    static int maxUnits = sizeof units - 1;

    int multiplier = 1000;
    int exponent = 0;

    while (bytes >= multiplier && exponent < maxUnits) {
        bytes /= multiplier;
        exponent++;
    }
    NSNumberFormatter* formatter = [NSNumberFormatter new];

    NSString *unitString = [NSString stringWithFormat:@"%cB", units[exponent]];
    if ([unitString isEqualToString:@"kB"])
        unitString = @"K";

    return [NSString stringWithFormat:@"%@ %@", [formatter stringFromNumber: [NSNumber numberWithInt: round(bytes)]], unitString];
}

- (void)noPreviewForURL:(NSURL *)url handler:(void (^)(NSError *))handler {
    _showingIcon = YES;
    _imageView.image = [[NSWorkspace sharedWorkspace] iconForFile:url.path];
    NSFont *systemFont = [NSFont systemFontOfSize:20 weight:NSFontWeightBold];
    NSMutableDictionary *attrDict = [NSMutableDictionary new];
    attrDict[NSFontAttributeName] = systemFont;
    attrDict[NSForegroundColorAttributeName] = [NSColor controlTextColor];
    [self addInfoLine:url.path.lastPathComponent attributes:attrDict linebreak:NO];

    if ([url.path.pathExtension.lowercaseString isEqualToString:@"d$$"]){
        attrDict[NSFontAttributeName] = [NSFont systemFontOfSize:[NSFont systemFontSize]];
        [self addInfoLine:@"Possibly an AGT game. Try opening in Spatterlight to convert to AGX format." attributes:attrDict linebreak:YES];
    }
    if (_ifid && _ifid.length) {
        attrDict[NSFontAttributeName] = [NSFont systemFontOfSize:[NSFont systemFontSize]];
        [self addInfoLine:[@"IFID: " stringByAppendingString:_ifid] attributes:attrDict linebreak:YES];
    }

    [self addFileInfo:url];

    NSSize viewSize = self.view.frame.size;

    if (viewSize.width - viewSize.height > 20 ) {
        [self tryToStretchWindow];
    }
    [self sizeImage];
    [self sizeText];
    handler(nil);
    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self sizeText];
        self.textview.hidden = NO;
        [self printFinalLayout];
    });
}

- (void)addFileInfo:(NSURL *)url {
    if (_addedFileInfo)
        return;
    _addedFileInfo = YES;
    NSMutableDictionary *attrDict = [NSMutableDictionary new];
    attrDict[NSFontAttributeName] = [NSFont systemFontOfSize:[NSFont systemFontSize]];
    attrDict[NSForegroundColorAttributeName] = [NSColor controlTextColor];
    NSError *error = nil;
    NSDictionary * fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:&error];
    if (fileAttributes) {
        NSDate *modificationDate = (NSDate *)fileAttributes[NSFileModificationDate];
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.dateFormat = @"d MMM yyyy HH.mm";
        [self addInfoLine:[NSString stringWithFormat:@"Last modified %@", [formatter stringFromDate:modificationDate]] attributes:attrDict linebreak:YES];
        NSInteger fileSize = ((NSNumber *)fileAttributes[NSFileSize]).integerValue;
        [self addInfoLine:[self unitStringFromBytes:fileSize] attributes:attrDict linebreak:YES];
    } else {
        NSLog(@"Could not read file attributes!");
    }
}


- (NSMutableDictionary *)metadataFromURL:(NSURL *)url {
    NSMutableDictionary *metaDict = [NSMutableDictionary new];
    if (![Blorb isBlorbURL:url])
        return nil;

    Blorb *blorb = [[Blorb alloc] initWithData:[NSData dataWithContentsOfFile:url.path]];
    metaDict[@"cover"] = [blorb coverImageData];

    NSData *data = blorb.metaData;

    LibraryEntry *entry = nil;

    IFictionMetadata *metadata = nil;
    if (data) {
        metadata = [[IFictionMetadata alloc] initWithData:data];
        for (IFStory *storyMetadata in metadata.stories) {
            entry = [[LibraryEntry alloc] initWithStoryMetadata:storyMetadata];
            break;
        }
    } else {
        metaDict[@"IFhd"] = [blorb ifidFromIFhd];
        if (metaDict[@"IFhd"]) {
            metaDict[@"IFhdTitle"] = [self titleFromIfid:metaDict[@"IFhd"]];
        } else NSLog(@"No IFdh resource in Blorb file");
    }

    metaDict[@"title"] = entry.title;
    metaDict[@"blurb"] = entry.storyMetadata.bibliographic.storyDescription;
    metaDict[@"author"] = entry.storyMetadata.bibliographic.author;
    metaDict[@"headline"] = entry.storyMetadata.bibliographic.headline;
    if (_ifid)
        metaDict[@"ifid"] = _ifid;
    else
        metaDict[@"ifid"] = entry.storyMetadata.identification.ifids.firstObject;

    return metaDict;
}

- (NSString *)titleFromIfid:(NSString *)ifid {
    NSManagedObjectContext *context = self.persistentContainer.newBackgroundContext;
    if (!context) {
        NSLog(@"context is nil!");
        return @"";;
    }

    __block Game *game;

    [context performBlockAndWait:^{
        NSError *error = nil;
        NSArray *fetchedObjects;

        NSFetchRequest *fetchRequest = [NSFetchRequest new];

        fetchRequest.entity = [NSEntityDescription entityForName:@"Game" inManagedObjectContext:context];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"ifid like[c] %@", ifid];

        fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
        if (fetchedObjects && fetchedObjects.count) {
            game = fetchedObjects[0];
        }
    }];

    return game.metadata.title;
}

- (NSString *)ifidFromFile:(NSString *)path {
    void *context = get_babel_ctx();
    char *format = babel_init_ctx((char*)path.UTF8String, context);
    if (!format || !babel_get_authoritative_ctx(context))
    {
        babel_release_ctx(context);
        return nil;
    }

    char buf[TREATY_MINIMUM_EXTENT];

    int rv = babel_treaty_ctx(GET_STORY_FILE_IFID_SEL, buf, sizeof buf, context);
    if (rv <= 0)
    {
        babel_release_ctx(context);
        return nil;
    }

    babel_release_ctx(context);
    return @(buf);
}

@end


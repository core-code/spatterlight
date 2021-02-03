//
//  PreviewViewController.m
//  SpatterlightQuickLook
//
//  Created by Administrator on 2021-01-29.
//
#import <Cocoa/Cocoa.h>

#import "PreviewViewController.h"
#import <Quartz/Quartz.h>
#import <Cocoa/Cocoa.h>
#import <CoreData/CoreData.h>

#import "Game.h"
#import "Metadata.h"
#import "Image.h"

#import "Blorb.h"

//#import "CoreDataManager.h"
//#import "Game.h"
//#import "Metadata.h"
//#import "Image.h"


@interface VerticallyCenteredTextFieldCell : NSTextFieldCell

@end

@implementation VerticallyCenteredTextFieldCell

- (NSRect) titleRectForBounds:(NSRect)frame {

    CGFloat stringHeight = self.attributedStringValue.size.height;
    NSRect titleRect = [super titleRectForBounds:frame];
    CGFloat oldOriginY = frame.origin.y;
    titleRect.origin.y = frame.origin.y + (frame.size.height - stringHeight) / 2.0;
    titleRect.size.height = titleRect.size.height - (titleRect.origin.y - oldOriginY);
    return titleRect;
}

- (void) drawInteriorWithFrame:(NSRect)cFrame inView:(NSView*)cView {
    [super drawInteriorWithFrame:[self titleRectForBounds:cFrame] inView:cView];
}

@end

@interface PreviewViewController () <QLPreviewingController>

@end

@implementation PreviewViewController

//#pragma mark - Core Data stack
//
//@synthesize coreDataManager = _coreDataManager;
//
//- (CoreDataManager *)coreDataManager {
//    // The persistent container for the application. This implementation creates and returns a container, having loaded the store for the application to it.
//    @synchronized (self) {
//        if (_coreDataManager == nil) {
//            _coreDataManager = [[CoreDataManager alloc] initWithModelName:@"Spatterlight"];
//        }
//    }
//
//    return _coreDataManager;
//}

- (NSString *)nibName {
    return @"PreviewViewController";
}

- (void)loadView {
    [super loadView];
    NSLog(@"loadView");

    //    _managedObjectContext = self.coreDataManager.mainManagedObjectContext;
    // Do any additional setup after loading the view.
}

@synthesize persistentContainer = _persistentContainer;

- (NSPersistentContainer *)persistentContainer  API_AVAILABLE(macos(10.12)){
    /*
     The persistent container for the application. This implementation
     creates and returns a container, having loaded the store for the
     application to it. This property is optional since there are legitimate
     error conditions that could cause the creation of the store to fail.
     */
    @synchronized (self) {
        if (_persistentContainer == nil) {
            _persistentContainer = [[NSPersistentContainer alloc] initWithName:@"Spatterlight"];

            NSURL *directory = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.net.ccxvii.spatterlight"];

        NSURL *url = [NSURL fileURLWithPath:[directory.path stringByAppendingPathComponent:@"Spatterlight.storedata"]];

            NSPersistentStoreDescription *description = [[NSPersistentStoreDescription alloc] initWithURL:url];

            description.readOnly = NO;
            description.shouldMigrateStoreAutomatically = YES;

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
    if (!context)
        NSLog(@"context is nil!");



    [context performBlockAndWait:^{
    NSError *error = nil;
    NSArray *fetchedObjects;

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    fetchRequest.entity = [NSEntityDescription entityForName:@"Game" inManagedObjectContext:context];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"fileName like[c] %@", url.path.lastPathComponent];

    fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
    if (fetchedObjects == nil) {
        NSLog(@"QuickLook: %@",error);
        return;
    }

    if (fetchedObjects.count == 0) {
        NSLog(@"QuickLook: Found no Game object with fileName %@", url.path.lastPathComponent);

        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"path like[c] %@", url.path];

        fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
        if (fetchedObjects == nil) {
            NSLog(@"QuickLook: %@",error);
            return;
        }
        if (fetchedObjects.count == 0) {
            NSLog(@"QuickLook: Found no Game object with path %@", url.path);
            return;
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
        if ([attr isEqualToString:@"cover"])
            [metadata setValue:(NSData *)meta.cover.data forKey:attr];
        else
            [metadata setValue:[meta valueForKey:attr] forKey:attr];
    }
        [self updateSideViewWithMetadata:metadata];

        handler(nil);
    }];
}

- (void) updateSideViewWithMetadata:(NSDictionary *)somedata
{
//    Metadata *somedata = somegame.metadata;

    if (somedata[@"description"] == nil && somedata[@"author"] == nil && somedata[@"headline"] == nil && somedata[@"cover"] == nil) {
//        ifidField.stringValue = somegame.ifid;
        [self updateSideViewWithString:somedata[@"title"]];
        return;
    }

    totalHeight = 0;

    NSLayoutConstraint *xPosConstraint;
    NSLayoutConstraint *yPosConstraint;
    NSLayoutConstraint *widthConstraint;
    NSLayoutConstraint *heightConstraint;
    NSLayoutConstraint *rightMarginConstraint;
    NSLayoutConstraint *topSpacerYConstraint;

    NSFont *font;
    CGFloat spaceBefore = 0.0;
    NSView *lastView;

    self.view.translatesAutoresizingMaskIntoConstraints = NO;

    NSView *clipView = self.view;
    CGFloat superViewWidth = clipView.frame.size.width;

    //    if (superViewWidth < 24)
    //        return;

    [clipView addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                         attribute:NSLayoutAttributeLeft
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:clipView
                                                         attribute:NSLayoutAttributeLeft
                                                        multiplier:1.0
                                                          constant:0]];

    [clipView addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                         attribute:NSLayoutAttributeRight
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:clipView
                                                         attribute:NSLayoutAttributeRight
                                                        multiplier:1.0
                                                          constant:0]];

    [clipView addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                         attribute:NSLayoutAttributeTop
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:clipView
                                                         attribute:NSLayoutAttributeTop
                                                        multiplier:1.0
                                                          constant:0]];

    if (somedata[@"cover"])
    {

        NSImage *theImage = [[NSImage alloc] initWithData:somedata[@"cover"]];

        CGFloat ratio = theImage.size.width / theImage.size.height;

        // We make the image double size to make enlarging when draggin divider to the right work
        theImage.size = NSMakeSize(superViewWidth * 2, superViewWidth * 2 / ratio );

        imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0,0,theImage.size.width,theImage.size.height)];

        [self.view addSubview:imageView];

        imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
        imageView.translatesAutoresizingMaskIntoConstraints = NO;

        imageView.imageScaling = NSImageScaleProportionallyUpOrDown;

        xPosConstraint = [NSLayoutConstraint constraintWithItem:imageView
                                                      attribute:NSLayoutAttributeLeft
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:self.view
                                                      attribute:NSLayoutAttributeLeft
                                                     multiplier:1.0
                                                       constant:0];

        yPosConstraint = [NSLayoutConstraint constraintWithItem:imageView
                                                      attribute:NSLayoutAttributeTop
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:self.view
                                                      attribute:NSLayoutAttributeTop
                                                     multiplier:1.0
                                                       constant:0];

        widthConstraint = [NSLayoutConstraint constraintWithItem:imageView
                                                       attribute:NSLayoutAttributeWidth
                                                       relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                          toItem:self.view
                                                       attribute:NSLayoutAttributeWidth
                                                      multiplier:1.0
                                                        constant:0];

        heightConstraint = [NSLayoutConstraint constraintWithItem:imageView
                                                        attribute:NSLayoutAttributeHeight
                                                        relatedBy:NSLayoutRelationLessThanOrEqual
                                                           toItem:imageView
                                                        attribute:NSLayoutAttributeWidth
                                                       multiplier:( 1 / ratio)
                                                         constant:0];

        rightMarginConstraint = [NSLayoutConstraint constraintWithItem:imageView
                                                             attribute:NSLayoutAttributeRight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeRight
                                                            multiplier:1.0
                                                              constant:0];

        [self.view addConstraint:xPosConstraint];
        [self.view addConstraint:yPosConstraint];
        [self.view addConstraint:widthConstraint];
        [self.view addConstraint:heightConstraint];
        rightMarginConstraint.priority = 999;
        [self.view addConstraint:rightMarginConstraint];

        imageView.image = theImage;

        lastView = imageView;
    } else {
        imageView = nil;
        //NSLog(@"No image");
        topSpacer = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, superViewWidth, 0)];
        topSpacer.boxType = NSBoxSeparator;


        [self.view addSubview:topSpacer];

        topSpacer.frame = NSMakeRect(0,0, superViewWidth, 1);

        topSpacer.translatesAutoresizingMaskIntoConstraints = NO;


        xPosConstraint = [NSLayoutConstraint constraintWithItem:topSpacer
                                                      attribute:NSLayoutAttributeLeft
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:self.view
                                                      attribute:NSLayoutAttributeLeft
                                                     multiplier:1.0
                                                       constant:0];

        yPosConstraint = [NSLayoutConstraint constraintWithItem:topSpacer
                                                      attribute:NSLayoutAttributeTop
                                                      relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                         toItem:self.view
                                                      attribute:NSLayoutAttributeTop
                                                     multiplier:1.0
                                                       constant:clipView.frame.size.height/4];

        yPosConstraint.priority = NSLayoutPriorityDefaultLow;

        widthConstraint = [NSLayoutConstraint constraintWithItem:topSpacer
                                                       attribute:NSLayoutAttributeWidth
                                                       relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                          toItem:self.view
                                                       attribute:NSLayoutAttributeWidth
                                                      multiplier:1.0
                                                        constant:0];


        [self.view addConstraint:xPosConstraint];
        [self.view addConstraint:yPosConstraint];
        [self.view addConstraint:widthConstraint];

        lastView = topSpacer;
    }

    if (somedata[@"title"]) // Every game will have a title unless something is broken
    {

        font = [NSFont fontWithName:@"Playfair Display Black" size:30];

        NSFontDescriptor *descriptor = font.fontDescriptor;

        NSArray *array = @[@{NSFontFeatureTypeIdentifierKey : @(kNumberCaseType),
                             NSFontFeatureSelectorIdentifierKey : @(kUpperCaseNumbersSelector)}];

        descriptor = [descriptor fontDescriptorByAddingAttributes:@{NSFontFeatureSettingsAttribute : array}];

        NSString *title = (NSString *)somedata[@"title"];
        if (title.length > 9)
        {
            font = [NSFont fontWithDescriptor:descriptor size:30];
            //NSLog(@"Long title (length = %lu), smaller text.", agame.metadata.title.length);
        }
        else
        {
            font = [NSFont fontWithDescriptor:descriptor size:50];
        }

        NSString *longestWord = @"";

        for (NSString *word in [title componentsSeparatedByString:@" "])
        {
            if (word.length > longestWord.length) longestWord = word;
        }
        //NSLog (@"Longest word: %@", longestWord);

        // The magic number -24 means 10 points of margin and two points of textfield border on each side.
        while ([longestWord sizeWithAttributes:@{ NSFontAttributeName:font }].width > superViewWidth - 24)
        {
            //            NSLog(@"Font too large! Width %f, max allowed %f", [longestWord sizeWithAttributes:@{NSFontAttributeName:font}].width,  superViewWidth - 24);
            font = [[NSFontManager sharedFontManager] convertFont:font toSize:font.pointSize - 2];
        }
        //        NSLog(@"Font not too large! Width %f, max allowed %f", [longestWord sizeWithAttributes:@{NSFontAttributeName:font}].width,  superViewWidth - 24);

        spaceBefore = [@"X" sizeWithAttributes:@{NSFontAttributeName:font}].height * 0.7;

        lastView = [self addSubViewWithtext:title andFont:font andSpaceBefore:spaceBefore andLastView:lastView];

        titleField = (NSTextField *)lastView;
    }
    else
    {
        NSLog(@"Error! No title!");
        titleField = nil;
        //        return;
    }

    NSBox *divider = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, superViewWidth, 1)];

    divider.boxType = NSBoxSeparator;
    divider.translatesAutoresizingMaskIntoConstraints = NO;

    xPosConstraint = [NSLayoutConstraint constraintWithItem:divider
                                                  attribute:NSLayoutAttributeLeft
                                                  relatedBy:NSLayoutRelationEqual
                                                     toItem:self.view
                                                  attribute:NSLayoutAttributeLeft
                                                 multiplier:1.0
                                                   constant:0];

    yPosConstraint = [NSLayoutConstraint constraintWithItem:divider
                                                  attribute:NSLayoutAttributeTop
                                                  relatedBy:NSLayoutRelationEqual
                                                     toItem:lastView
                                                  attribute:NSLayoutAttributeBottom
                                                 multiplier:1.0
                                                   constant:spaceBefore * 0.9];

    widthConstraint = [NSLayoutConstraint constraintWithItem:divider
                                                   attribute:NSLayoutAttributeWidth
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:self.view
                                                   attribute:NSLayoutAttributeWidth
                                                  multiplier:1.0
                                                    constant:0];

    heightConstraint = [NSLayoutConstraint constraintWithItem:divider
                                                    attribute:NSLayoutAttributeHeight
                                                    relatedBy:NSLayoutRelationEqual
                                                       toItem:nil
                                                    attribute:NSLayoutAttributeNotAnAttribute
                                                   multiplier:1.0
                                                     constant:1];

    [self.view addSubview:divider];

    [self.view addConstraint:xPosConstraint];
    [self.view addConstraint:yPosConstraint];
    [self.view addConstraint:widthConstraint];
    [self.view addConstraint:heightConstraint];

    lastView = divider;

    if (somedata[@"headline"])
    {
        //font = [NSFont fontWithName:@"Playfair Display Regular" size:13];
        font = [NSFont fontWithName:@"HoeflerText-Regular" size:16];

        NSFontDescriptor *descriptor = font.fontDescriptor;

        NSArray *array = @[@{ NSFontFeatureTypeIdentifierKey : @(kLetterCaseType),
                              NSFontFeatureSelectorIdentifierKey : @(kSmallCapsSelector)}];

        descriptor = [descriptor fontDescriptorByAddingAttributes:@{NSFontFeatureSettingsAttribute : array}];
        font = [NSFont fontWithDescriptor:descriptor size:16.f];

        NSString *headline = (NSString *)somedata[@"headline"];
        lastView = [self addSubViewWithtext:headline.lowercaseString andFont:font andSpaceBefore:4 andLastView:lastView];

        headlineField = (NSTextField *)lastView;
    }
    else
    {
        //        NSLog(@"No headline");
        headlineField = nil;
    }

    if (somedata[@"author"])
    {
        font = [NSFont fontWithName:@"Gentium Plus Italic" size:14.f];

        NSString *author = (NSString *)somedata[@"author"];
        lastView = [self addSubViewWithtext:author andFont:font andSpaceBefore:25 andLastView:lastView];

        authorField = (NSTextField *)lastView;
    }
    else
    {
        //        NSLog(@"No author");
        authorField = nil;
    }

    if (somedata[@"description"])
    {
        font = [NSFont fontWithName:@"Gentium Plus" size:14.f];

        NSString *blurb = (NSString *)somedata[@"description"];

        lastView = [self addSubViewWithtext:blurb andFont:font andSpaceBefore:23 andLastView:lastView];

        blurbField = (NSTextField *)lastView;

    }
    else
    {
        //        NSLog(@"No blurb.");
        blurbField = nil;
    }

    NSLayoutConstraint *bottomPinConstraint = [NSLayoutConstraint constraintWithItem:self.view
                                                                           attribute:NSLayoutAttributeBottom
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:lastView
                                                                           attribute:NSLayoutAttributeBottom
                                                                          multiplier:1.0
                                                                            constant:0];
    [self.view addConstraint:bottomPinConstraint];

    if (imageView == nil) {
        CGFloat windowHeight = self.view.frame.size.height;

        CGFloat topConstraintConstant = (windowHeight - totalHeight - 60) / 2;
        if (topConstraintConstant < 0)
            topConstraintConstant = 0;

        topSpacerYConstraint = [NSLayoutConstraint constraintWithItem:topSpacer
                                                            attribute:NSLayoutAttributeTop
                                                            relatedBy:NSLayoutRelationLessThanOrEqual
                                                               toItem:self.view
                                                            attribute:NSLayoutAttributeTop
                                                           multiplier:1.0
                                                             constant:topConstraintConstant];
        topSpacerYConstraint.priority = 999;

        if (clipView.frame.size.height < self.view.frame.size.height) {
            topSpacerYConstraint.constant = 0;
            yPosConstraint.constant = 0;
        }

        [self.view addConstraint:topSpacerYConstraint];

    }
}

- (NSTextField *) addSubViewWithtext:(NSString *)text andFont:(NSFont *)font andSpaceBefore:(CGFloat)space andLastView:(id)lastView
{
    NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];

    para.minimumLineHeight = font.pointSize + 3;
    para.maximumLineHeight = para.minimumLineHeight;

    if (font.pointSize > 40)
        para.maximumLineHeight = para.maximumLineHeight + 3;

    if (font.pointSize > 25)
        para.maximumLineHeight = para.maximumLineHeight + 3;

    para.alignment = NSCenterTextAlignment;
    para.lineSpacing = 1;

    if (font.pointSize > 25)
        para.lineSpacing = 0.2f;

    NSMutableDictionary *attr = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 font,
                                 NSFontAttributeName,
                                 para,
                                 NSParagraphStyleAttributeName,
                                 nil];

    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:text attributes:attr];


    if (font.pointSize == 16.f)
    {
        [attrString addAttribute:NSKernAttributeName value:@1.f range:NSMakeRange(0, text.length)];
    }

    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor textColor] range:NSMakeRange(0, text.length)] ;

    CGRect contentRect = [attrString boundingRectWithSize:CGSizeMake(self.view.frame.size.width - 24, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin];
    // I guess the magic number -24 here means that the text field inner width differs 4 points from the outer width. 2-point border?

    NSTextField *textField = [[NSTextField alloc] initWithFrame:contentRect];

    //    textField.delegate = self;

    textField.translatesAutoresizingMaskIntoConstraints = NO;

    textField.bezeled=NO;
    textField.drawsBackground = NO;
    textField.editable = NO;
    textField.selectable = YES;
    textField.bordered = NO;
    [textField.cell setUsesSingleLineMode:NO];
    textField.allowsEditingTextAttributes = YES;
    textField.alignment = para.alignment;

    [textField.cell setWraps:YES];
    [textField.cell setScrollable:NO];

    [textField setContentCompressionResistancePriority:25 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [textField setContentCompressionResistancePriority:25 forOrientation:NSLayoutConstraintOrientationVertical];

    NSLayoutConstraint *xPosConstraint = [NSLayoutConstraint constraintWithItem:textField
                                                                      attribute:NSLayoutAttributeLeft
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.view
                                                                      attribute:NSLayoutAttributeLeft
                                                                     multiplier:1.0
                                                                       constant:10];

    NSLayoutConstraint *yPosConstraint;

    if (lastView)
    {
        yPosConstraint = [NSLayoutConstraint constraintWithItem:textField
                                                      attribute:NSLayoutAttributeTop
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:lastView
                                                      attribute:NSLayoutAttributeBottom
                                                     multiplier:1.0
                                                       constant:space];
    }
    else
    {
        yPosConstraint = [NSLayoutConstraint constraintWithItem:textField
                                                      attribute:NSLayoutAttributeTop
                                                      relatedBy:NSLayoutRelationEqual
                                                         toItem:self.view
                                                      attribute:NSLayoutAttributeTop
                                                     multiplier:1.0
                                                       constant:space];
    }

    NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:textField
                                                                       attribute:NSLayoutAttributeWidth
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:self.view
                                                                       attribute:NSLayoutAttributeWidth
                                                                      multiplier:1.0
                                                                        constant:-20];

    NSLayoutConstraint *rightMarginConstraint = [NSLayoutConstraint constraintWithItem:textField
                                                                             attribute:NSLayoutAttributeRight
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:self.view
                                                                             attribute:NSLayoutAttributeRight
                                                                            multiplier:1.0
                                                                              constant:-10];

    textField.attributedStringValue = attrString;

    [[self view] addSubview:textField];

    [[self view] addConstraint:xPosConstraint];
    [[self view] addConstraint:yPosConstraint];
    [[self view] addConstraint:widthConstraint];
    [[self view] addConstraint:rightMarginConstraint];

    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:textField
                                                                        attribute:NSLayoutAttributeHeight
                                                                        relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                           toItem:nil
                                                                        attribute:NSLayoutAttributeNotAnAttribute
                                                                       multiplier:1.0
                                                                         constant: contentRect.size.height + 1];

    [[self view] addConstraint:heightConstraint];

    totalHeight += NSHeight(textField.bounds) + space;

    return textField;
}

- (void) updateSideViewWithString:(NSString *)aString {
    NSFont *font;
    NSClipView *clipView = (NSClipView *)self.view;
    if (!aString)
        return;
    [titleField removeFromSuperview];
    titleField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, clipView.frame.size.width, clipView.frame.size.height)];
    titleField.drawsBackground = NO;
    self.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    titleField.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;


    titleField.cell = [[VerticallyCenteredTextFieldCell alloc] initTextCell:aString];

    [self.view addSubview:titleField];

    NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];

    font = [NSFont titleBarFontOfSize:16];

    para.alignment = NSCenterTextAlignment;
    para.lineBreakMode = NSLineBreakByTruncatingMiddle;

    NSMutableDictionary *attr = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 font,
                                 NSFontAttributeName,
                                 para,
                                 NSParagraphStyleAttributeName,
                                 [NSColor disabledControlTextColor],
                                 NSForegroundColorAttributeName,
                                 nil];

    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:aString attributes:attr];
    titleField.attributedStringValue = attrString;
}


@end


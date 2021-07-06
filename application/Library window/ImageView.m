//
//  ImageView.m
//  Spatterlight
//
//  Created by Administrator on 2021-06-06.
//

#import <QuartzCore/QuartzCore.h>

#import "ImageView.h"

#import "Game.h"
#import "Metadata.h"
#import "Image.h"

#import "NSImage+Categories.h"
#import "NSData+Categories.h"
#import "ImageCompareViewController.h"
#import "IFDBDownloader.h"
#import "MyFilePromiseProvider.h"
#import "Blorb.h"
#import "BlorbResource.h"
#import "NotificationBezel.h"

#import "OSImageHashing.h"

#define FILTERTAG ((NSInteger) 100)
#define DESCRIPTIONTAG ((NSInteger) 200)

@interface ImageView ()
{
    NSSet<NSPasteboardType> *nonURLTypes;

    NSPasteboardType PasteboardFileURLPromise,
    PasteboardFilePromiseContent,
    PasteboardFilePasteLocation;

    NSArray<NSString *> *imageTypes;
}
@end

@implementation ImageView

// This is called when loaded from InfoPanel.nib
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.enabled = YES;

        nonURLTypes = [NSSet setWithObjects:NSPasteboardTypeTIFF, NSPasteboardTypePNG, nil];
        _acceptableTypes = [NSSet setWithObject:NSURLPboardType];
        _acceptableTypes = [_acceptableTypes setByAddingObjectsFromSet:nonURLTypes];
        [self registerForDraggedTypes:_acceptableTypes.allObjects];
        _numberForSelfSourcedDrag = NSNotFound;

        PasteboardFileURLPromise = (NSPasteboardType)kPasteboardTypeFileURLPromise;
        PasteboardFilePromiseContent = (NSPasteboardType)kPasteboardTypeFilePromiseContent;
        PasteboardFilePasteLocation = (NSPasteboardType)@"com.apple.pastelocation";

        imageTypes = NSImage.imageTypes;
        imageTypes = [imageTypes arrayByAddingObjectsFromArray:@[ @"public.neochrome", @"public.mcga", @"public.dat", @"public.blorb" ]];
    }
    return self;
}

- (instancetype)initWithGame:(Game *)game image:(nullable NSImage *)anImage {
    if (!anImage && game.metadata.cover.data)
        anImage = [[NSImage alloc] initWithData:(NSData *)game.metadata.cover.data];
    if (anImage)
        self = [self initWithFrame:NSMakeRect(0, 0, anImage.size.width, anImage.size.height)];
    else
        self = [self initWithFrame:NSZeroRect];
    if (self) {
        _image = anImage;
        _game = game;

        if (_image)
            [self processImage:_image];
    }
    return self;
}

+ (NSMenu *)defaultMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    menu.autoenablesItems = YES;
    menu.showsStateColumn = YES;

    NSMenuItem *reload = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Reload from Blorb" , nil) action:@selector(reloadFromBlorb:) keyEquivalent:@""];
    NSMenuItem *open = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Select image file", nil) action:@selector(selectImageFile:) keyEquivalent:@""];
    NSMenuItem *filter = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Filter", nil) action:@selector(toggleFilter:) keyEquivalent:@""];
    NSMenuItem *download = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Download image", nil) action:@selector(downloadImage:) keyEquivalent:@""];
    NSMenuItem *cut = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Cut", nil) action:@selector(cut:) keyEquivalent:@""];
    NSMenuItem *copy = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy", nil) action:@selector(copy:) keyEquivalent:@""];
    NSMenuItem *paste = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Paste", nil) action:@selector(paste:) keyEquivalent:@""];
    NSMenuItem *delete = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Delete", nil) action:@selector(delete:) keyEquivalent:@""];
    NSMenuItem *save = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Save image", nil) action:@selector(saveImage:) keyEquivalent:@""];
    NSMenuItem *addDescription = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Add description", nil) action:@selector(addDescription:) keyEquivalent:@""];

    [menu addItem:open];
    [menu addItem:download];
    [menu addItem:reload];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:save];
    [menu addItem:[NSMenuItem separatorItem]];
    addDescription.tag = DESCRIPTIONTAG;
    [menu addItem:addDescription];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:cut];
    [menu addItem:copy];
    [menu addItem:paste];
    [menu addItem:delete];
    [menu addItem:[NSMenuItem separatorItem]];
    filter.state = NSOffState;
    filter.tag = FILTERTAG;
    [menu addItem:filter];

    return menu;
}

- (void)updateLayer {
    NSArray *layers = self.layer.sublayers.copy;
    for (CALayer *sub in layers)
        [sub removeFromSuperlayer];
    self.layer.mask = nil;
    if (_isSelected || _isReceivingDrag) {

        if (self.frame.size.width * self.frame.size.height == 0)
            return;

        // Create a selection border
        CAShapeLayer *shapelayer = [CAShapeLayer layer];

        shapelayer.fillColor = NSColor.clearColor.CGColor;
        shapelayer.frame = self.bounds;

        shapelayer.lineJoin = kCALineJoinRound;
        shapelayer.strokeColor = NSColor.selectedControlColor.CGColor;
        CGFloat lineWidth = 4;
        shapelayer.lineWidth = lineWidth;
        CGRect borderRect = NSMakeRect(lineWidth / 2, lineWidth / 2, self.bounds.size.width - lineWidth, self.bounds.size.height - lineWidth);
        CGPathRef roundedRectPath = CGPathCreateWithRoundedRect(borderRect, 2.5, 2.5, NULL);
        shapelayer.path = roundedRectPath;
        [self.layer addSublayer:shapelayer];
        shapelayer.drawsAsynchronously = YES;
        CFRelease(roundedRectPath);

        // Use a mask layer to hide the sharp corners of the image
        // that stick out from the rounded corners of the selection border
        CAShapeLayer *masklayer = [CAShapeLayer layer];
        masklayer.fillColor = NSColor.blackColor.CGColor;
        masklayer.frame = self.bounds;
        masklayer.lineJoin = kCALineJoinRound;
        masklayer.lineWidth = 0;
        borderRect = NSMakeRect(0, 0, masklayer.frame.size.width,  masklayer.frame.size.height);
        roundedRectPath = CGPathCreateWithRoundedRect(borderRect, 5, 5, NULL);
        masklayer.path = roundedRectPath;
        self.layer.mask = masklayer;
        CFRelease(roundedRectPath);
    }
}

- (BOOL)wantsUpdateLayer {
    return YES;
}

- (void)processImage:(NSImage *)image {
    _image = image;
    CALayer *layer = [CALayer layer];

    NSImageRep *rep = image.representations.lastObject;
    NSSize sizeInPixels = NSMakeSize(rep.pixelsWide, rep.pixelsHigh);
    image.size = sizeInPixels;

    if (_game.metadata.cover.interpolation == kUnset) {
        _game.metadata.cover.interpolation = sizeInPixels.width < 350 ? kNearestNeighbor : kTrilinear;
    }

    layer.magnificationFilter = (_game.metadata.cover.interpolation == kNearestNeighbor) ? kCAFilterNearest : kCAFilterTrilinear;

    layer.drawsAsynchronously = YES;
    layer.contentsGravity = kCAGravityResize;

    layer.contents = image;

    self.layer = layer;

    self.accessibilityLabel = _game.metadata.coverArtDescription;
    if (!self.accessibilityLabel.length)
        self.accessibilityLabel = [NSString stringWithFormat:@"cover image for %@", _game.metadata.title];
}

- (BOOL)acceptsFirstResponder {
   return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    _isSelected = YES;
    [self updateLayer];
    return YES;
}

- (BOOL)resignFirstResponder {
    _isSelected = NO;
    [self updateLayer];
    return YES;
}

- (NSSize) intrinsicContentSize {
    return _intrinsic;
}

#pragma mark Actions

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(paste:)) {
        NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
        if ([pasteBoard canReadObjectForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingContentsConformToTypesKey:[NSImage imageTypes]}]) {
            return YES;
        } else {
            NSMutableSet *types = [NSMutableSet setWithArray:pasteBoard.types];
            [types intersectSet:_acceptableTypes];
            if (types.count)
                return YES;
        }
        return NO;
    }
    
    else if (menuItem.action == @selector(cut:) || menuItem.action == @selector(copy:) || menuItem.action == @selector(delete:)) {
        return !_isPlaceholder;
    }

    else if (menuItem.action == @selector(reloadFromBlorb:)) {
        return [Blorb isBlorbURL:[NSURL fileURLWithPath:_game.path]];
    }

    else if (menuItem.action == @selector(saveImage:)) {
        return (!_isPlaceholder);
    }

    else if (menuItem.action == @selector(toggleFilter:)) {
        NSMenuItem *filter = [self.menu itemWithTag:FILTERTAG];
        if (!_isPlaceholder) {
            filter.state = (_game.metadata.cover.interpolation == kNearestNeighbor) ? NSOffState : NSOnState;
            return YES;
        } else {
            filter.state = NSOffState;
            return NO;
        }
    }

    else if (menuItem.action == @selector(addDescription:)) {
        NSMenuItem *description = [self.menu itemWithTag:DESCRIPTIONTAG];
        if (!_isPlaceholder) {
            description.title = (_game.metadata.coverArtDescription.length || _game.metadata.cover.imageDescription.length) ? NSLocalizedString(@"Edit description", nil) : NSLocalizedString(@"Add description", nil);
            return YES;
        } else {
            description.title = NSLocalizedString(@"Add description", nil);
            return NO;
        }
    }

    return YES;
}

- (void)cut:(id)sender {
    [self copy:nil];

    //Delete the cover relation of the Metadata object
    Image *image = _game.metadata.cover;
    _game.metadata.cover = nil;
    _game.metadata.coverArtDescription = nil;

    //If the Image object becomes an orphan, delete it from the Core Data store
    if (image && image.metadata.count == 0)
        [_game.managedObjectContext deleteObject:image];
}

- (void)copy:(id)sender {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb writeObjects:@[_image]];
}

- (void)delete:(id)sender {
    if (_isPlaceholder) {
        NSBeep();
        return;
    }
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Are you sure?", nil);
    alert.informativeText = NSLocalizedString(@"Do you want to delete this cover image?", nil);
    alert.icon = _image;
    [alert addButtonWithTitle:NSLocalizedString(@"Delete", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];

    NSInteger choice = [alert runModal];

    if (choice == NSAlertFirstButtonReturn) {
        //Delete the cover relation of the Metadata object
        Image *image = _game.metadata.cover;
        if (!image)
            return;
        _game.metadata.cover = nil;
        _game.metadata.coverArtDescription = nil;

        //If the Image object becomes an orphan, delete it from the Core Data store
        if (image.metadata.count == 0)
            [_game.managedObjectContext deleteObject:image];
    }
}

- (void)paste:(id)sender {
    NSPasteboard *pb = [NSPasteboard  generalPasteboard];
    NSArray *objects = [pb readObjectsForClasses:@[[NSURL class], [NSImage class]] options:nil];

    NSData *imgData1 = (NSData *)_game.metadata.cover.data;

    for (id item in objects) {
        if ([item isKindOfClass:[NSImage class]]) {
            NSData *imgData2 = ((NSImage *)item).TIFFRepresentation;
            if ([imgData1 isEqual:imgData2]) {
                NSBeep();
                return;
            }
            [self replaceCoverImage:(NSImage *)item sourceUrl:@"pasteboard"];
            break;
        } else if ([item isKindOfClass:[NSURL class]]) {
            NSURL *url = (NSURL *)item;
            if ([_game.metadata.coverArtURL isEqualToString:url.path]) {
                NSBeep();
                return;
            }
            if (![url.scheme isEqualToString:@"file"]) {
                NSArray *objects2 = [pb readObjectsForClasses:@[[NSImage class]] options:nil];
                if ([objects2.firstObject isKindOfClass:[NSImage class]]) {
                    NSImage *image = (NSImage *)objects2.firstObject;
                    NSData *imgData2 = image.TIFFRepresentation;
                    if ([imgData1 isEqual:imgData2]) {
                        NSBeep();
                        return;
                    }
                    [self replaceCoverImage:image sourceUrl:url.path];
                    break;
                }
            }
            if ([self imageFromURL:url dontAsk:YES])
                break;
        }
    }
}

- (void)keyDown:(NSEvent *)event {
    unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];
    if (!_isPlaceholder && (key == NSDeleteCharacter || key == NSBackspaceCharacter))
        [self delete:nil];
    else
        [super keyDown:event];
}

- (IBAction)selectImageFile:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = NO;
    panel.prompt = NSLocalizedString(@"Select an image", nil);

    panel.allowedFileTypes = imageTypes;

    [panel beginSheetModalForWindow:self.window
                  completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            double delayInSeconds = 0.3;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self imageFromURL:panel.URL dontAsk:YES];
            });
        }
    }];
}

- (IBAction)reloadFromBlorb:(id)sender {
    Blorb *blorb = [[Blorb alloc] initWithData:[NSData dataWithContentsOfFile:_game.path]];
    NSData *data = [blorb coverImageData];
    BOOL success = NO;
    if (data) {
        [self processImageData:data sourceUrl:_game.path dontAsk:YES];
        success = YES;
        NSData *metadata = [blorb metaData];
        if (metadata) {
            NSString *imageDescription = [ImageView coverArtDescriptionFromXMLData:metadata];
            if (imageDescription.length)
                _game.metadata.coverArtDescription = imageDescription;
        }
    }
    if (!success) {
        NotificationBezel *bezel = [[NotificationBezel alloc] initWithScreen:self.window.screen];
        [bezel showStandardWithText:@"? No image found"];
    }
}

+ (NSString *)coverArtDescriptionFromXMLData:(NSData *)data {
    NSString *result = @"";
    NSError *error = nil;
    NSXMLDocument *xml =
    [[NSXMLDocument alloc] initWithData:data
                                options:NSXMLDocumentTidyXML
                                  error:&error];
    NSArray *descriptions = [xml.rootElement nodesForXPath:@"story/cover/description" error:&error];
    if (descriptions.count) {
        NSXMLElement *description = descriptions.firstObject;
        result = description.stringValue;
    } else {
        NSLog(@"No cover image description found in metadata!");
    }
    return result;
}

- (IBAction)downloadImage:(id)sender {
    IFDBDownloader *downloader = [[IFDBDownloader alloc] initWithContext:_game.managedObjectContext];
    Game *game = _game;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([downloader downloadMetadataFor:game reportFailure:YES imageOnly:YES]) {
            [downloader downloadImageFor:game.metadata];
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [game.metadata.managedObjectContext save:nil];
            });
        }
    });
}

- (IBAction)toggleFilter:(id)sender {
    _game.metadata.cover.interpolation = (_game.metadata.cover.interpolation == kTrilinear) ? kNearestNeighbor : kTrilinear;
    self.layer.magnificationFilter = (_game.metadata.cover.interpolation == kNearestNeighbor) ? kCAFilterNearest : kCAFilterTrilinear;
}

- (IBAction)saveImage:(id)sender {
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.nameFieldLabel = NSLocalizedString(@"Save image: ", nil);
    panel.allowedFileTypes = @[ @"png" ];
    panel.extensionHidden = NO;
    [panel setCanCreateDirectories:YES];
    NSString *fileName = [_game.path.lastPathComponent.stringByDeletingPathExtension stringByAppendingPathExtension:@"png"];
    if (!fileName.length)
        fileName = @"image.png";
    panel.nameFieldStringValue = NSLocalizedString(fileName, nil);

    [panel beginSheetModalForWindow:self.window
                  completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSURL *url = panel.URL;

            NSData *bitmapData = [self pngData];

            NSError *error = nil;

            if (![bitmapData writeToURL:url options:NSDataWritingAtomic error:&error]) {
                NSLog(@"Error: Could not write PNG data to url %@: %@", url.path, error);
            }
        }
    }];
}

- (IBAction)addDescription:(id)sender {

    NSAlert *alert = [[NSAlert alloc] init];
    Metadata *metadata = _game.metadata;
    NSTextField *entryField = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0, 300, 150)];
    entryField.editable = YES;
    if (metadata.coverArtDescription.length)
        entryField.stringValue = metadata.coverArtDescription;
    else if (metadata.cover.imageDescription.length)
        entryField.stringValue = metadata.cover.imageDescription;

    alert.accessoryView = entryField;
    alert.window.initialFirstResponder = entryField;

    [alert setMessageText:NSLocalizedString(@"Image description", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Okay", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];

    NSModalResponse choice = [alert runModal];

    if (choice == NSAlertFirstButtonReturn && ![entryField.stringValue isEqualToString:metadata.coverArtDescription]) {
        metadata.coverArtDescription = entryField.stringValue;
        metadata.cover.imageDescription = entryField.stringValue;
        metadata.userEdited = @YES;
        metadata.source = @(kUser);
    }

}

#pragma mark Dragging target stuff

- (BOOL)shouldAllowDrag:(id<NSDraggingInfo>)draggingInfo {
    if (draggingInfo.draggingSequenceNumber == _numberForSelfSourcedDrag)
        return NO;
    NSDictionary *filteringOptions = @{ NSPasteboardURLReadingContentsConformToTypesKey:NSImage.imageTypes};

    BOOL canAccept = NO;

    NSPasteboard *pasteBoard = draggingInfo.draggingPasteboard;

    if ([pasteBoard canReadObjectForClasses:@[[NSURL class]] options:filteringOptions]) {
        canAccept = YES;
    } else {
        NSMutableSet *types = [NSMutableSet setWithArray:pasteBoard.types];
        [types intersectSet:_acceptableTypes];
        if (types.count)
            canAccept = YES;
    }

    if ([draggingInfo.draggingSource isKindOfClass:[ImageView class]]) {
        ImageView *source = (ImageView *)draggingInfo.draggingSource;
        if ([source.game.ifid isEqualToString:self.game.ifid])
            canAccept = NO;
    }

    return canAccept;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    BOOL allow = [self shouldAllowDrag:sender];
    _isReceivingDrag = allow;
    [self updateLayer];
    return allow ? NSDragOperationCopy : NSDragOperationNone;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    _isReceivingDrag = NO;
    [self updateLayer];
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
    BOOL allow = [self shouldAllowDrag:sender];
    return allow;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)draggingInfo {
    NSDictionary *filteringOptions = @{ NSPasteboardURLReadingContentsConformToTypesKey:imageTypes };

    _isReceivingDrag = NO;
    NSPasteboard *pasteBoard = draggingInfo.draggingPasteboard;

    NSArray<NSURL *> *urls = [pasteBoard readObjectsForClasses:@[[NSURL class]] options:filteringOptions];

    NSImage *image;
    if (urls.count == 1) {
        NSURL *url = urls.firstObject;
        return [self imageFromURL:url dontAsk:NO];
    } else {
        image = [[NSImage alloc] initWithPasteboard:pasteBoard];
        if (image) {
            [self replaceCoverImage:image sourceUrl:@"pasteboard"];
            return YES;
        }
    }
    return NO;
}

- (BOOL)imageFromURL:(NSURL *)url dontAsk:(BOOL)dontAsk {
    NSData *data = nil;
    if ([Blorb isBlorbURL:url]) {
        // Only accept blorbs with image data but no executable chunk
        // (because it would be confusing to treat game files as image files)
        Blorb *blorb = [[Blorb alloc] initWithData:[NSData dataWithContentsOfURL:url]];
        if ([blorb findResourceOfUsage:ExecutableResource] == nil) {
            data = [blorb coverImageData];
            if (data) {
                [self processImageData:data sourceUrl:url.path dontAsk:dontAsk];
                return YES;
            }
        }
    }
    data = [NSData dataWithContentsOfURL:url];
    NSImage *image = [[NSImage alloc] initWithData:data];
    if (image) {
        [self processImageData:data sourceUrl:url.path dontAsk:dontAsk];
        return YES;
    } else {
        data = [NSData imageDataFromRetroURL:url];
        if (data) {
            [self processImageData:data sourceUrl:url.path dontAsk:dontAsk];
            return YES;
        }
    }
    return NO;
}


-(void)replaceCoverImage:(NSImage *)image sourceUrl:(NSString *)URLPath {
    NSData *data = image.TIFFRepresentation;
    [self processImageData:data sourceUrl:URLPath dontAsk:NO];
}

-(void)processImageData:(NSData *)image sourceUrl:(NSString *)URLPath dontAsk:(BOOL)dontAsk {
    if (!image)
        return;
    if ([URLPath isEqualToString:@"pasteboard"] ||
        [self compareByFileNames:URLPath data:image]) {
        dontAsk = YES;
    }
    Metadata *metadata = _game.metadata;
    IFDBDownloader *downloader = [[IFDBDownloader alloc] initWithContext:metadata.managedObjectContext];

    if (dontAsk) {
        metadata.coverArtURL = URLPath;
        metadata.coverArtDescription = nil;
        [downloader insertImageData:image inMetadata:metadata];
        metadata.userEdited = @YES;
        metadata.source = @(kUser);
        return;
    }

    double delayInSeconds = 0.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
        ImageCompareViewController *compare = [ImageCompareViewController new];
        // We always replace when pasting
        if ([compare userWantsImage:image ratherThanImage:(NSData *)metadata.cover.data type:LOCAL]) {
            metadata.coverArtURL = URLPath;
            metadata.coverArtDescription = nil;
            [downloader insertImageData:image inMetadata:metadata];
            metadata.userEdited = @YES;
            metadata.source = @(kUser);
        }
    });
}

- (BOOL)compareByFileNames:(NSString *)path data:(NSData *)data {

    if (!_game.metadata.cover.data) {
        return NO;
    }

    NSString *gameBaseName = _game.path.lastPathComponent.stringByDeletingPathExtension;

    NSString *fileBaseName = path.lastPathComponent.stringByDeletingPathExtension;

    // The fileBaseName may have been given a suffix, such as "image 2.png"
    // if there already was a file named "image.png" on the HDD.
    if (fileBaseName.length > gameBaseName.length && gameBaseName.length > 1) {
        fileBaseName = [fileBaseName substringToIndex:gameBaseName.length];
    }

    if ([gameBaseName isEqualToString:fileBaseName]) {
        SInt64 distance = [[OSImageHashing sharedInstance] hashDistance:(NSData *)_game.metadata.cover.data to:data];
        NSLog(@"distance: %lld", distance);
        if (distance < 11) {
            return YES;
        }
    }

    return NO;
}

#pragma mark Dragging source stuff

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    return NSDragOperationCopy;
}

- (void)mouseDown:(NSEvent*)event {
    _isSelected = YES;
    [self.window makeFirstResponder:self];
    [super mouseDown:event];
    [self updateLayer];
}

- (void)mouseDragged:(NSEvent*)event
{
    if (_isPlaceholder)
        return;

    NSDraggingItem *dragItem;

    if (@available(macOS 10.14, *)) {

        MyFilePromiseProvider *provider = [[MyFilePromiseProvider alloc] initWithFileType: NSPasteboardTypePNG delegate:self];

        dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:provider];

    } else {
        NSPasteboardItem *pasteboardItem = [NSPasteboardItem new];

        [pasteboardItem setDataProvider:self forTypes:@[NSPasteboardTypePNG, PasteboardFileURLPromise, PasteboardFilePromiseContent]];

        // Create the dragging item for the drag operation
        dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pasteboardItem];
    }

    [dragItem setDraggingFrame:self.bounds contents:self.image];
    NSDraggingSession *session = [self beginDraggingSessionWithItems:@[dragItem] event:event source:self];
    _numberForSelfSourcedDrag = session.draggingSequenceNumber;

}

// For pre-10.14
- (void)pasteboard:(NSPasteboard *)sender item:(NSPasteboardItem *)item provideDataForType:(NSString *)type
{
    //sender has accepted the drag and now we need to send the data for the type we promised
    if ( [type isEqual:NSPasteboardTypePNG]) {
        //set data for PNG type on the pasteboard as requested
        [sender setData:[self pngData] forType:NSPasteboardTypePNG];
    } else if ([type isEqualTo:PasteboardFilePromiseContent]) {
        // The receiver will send this asking for the content type for the drop, to figure out
        // whether it wants to/is able to accept the file type.

        [sender setString:@"public.png" forType: PasteboardFilePromiseContent];
    }
    else if ([type isEqualTo: PasteboardFileURLPromise]) {
        // The receiver is interested in our data, and is happy with the format that we told it
        // about during the PasteboardFilePromiseContent request.
        // The receiver has passed us a URL where we are to write our data to.

        NSString *str = [sender stringForType:PasteboardFilePasteLocation];
        NSURL *destinationFolderURL = [NSURL fileURLWithPath:str];
        if (!destinationFolderURL) {
            NSLog(@"ERROR:- Receiver didn't tell us where to put the file?");
            return;
        }

        // Here, we build the file destination using the receivers destination URL
        NSString *baseFileName = _game.path.lastPathComponent.stringByDeletingPathExtension;

        if (!baseFileName.length)
            baseFileName = @"image";

        NSString *fileName = [baseFileName stringByAppendingPathExtension:@"png"];

        NSURL *destinationFileURL = [destinationFolderURL URLByAppendingPathComponent:fileName];

        NSUInteger index = 2;

        // Handle duplicate file names
        // by slapping on a number at the end.
        while ([[NSFileManager defaultManager] fileExistsAtPath:destinationFileURL.path]) {
            NSString *newFileName = [NSString stringWithFormat:@"%@ %ld", baseFileName, index];
            newFileName = [newFileName stringByAppendingPathExtension:@"png"];
            destinationFileURL = [destinationFolderURL URLByAppendingPathComponent:newFileName];
            index++;
        }

        NSData *bitmapData = [self pngData];

        NSError *error = nil;

        if (![bitmapData writeToURL:destinationFileURL options:NSDataWritingAtomic error:&error]) {
            NSLog(@"Error: Could not write PNG data to url %@: %@", destinationFileURL.path, error);
        }

        // And finally, tell the receiver where we wrote our file
        [sender setString:destinationFileURL.path forType:PasteboardFileURLPromise];
    }
}

- (NSString *)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider
                  fileNameForType:(NSString *)fileType {
    NSString *fileName = [_game.path.lastPathComponent.stringByDeletingPathExtension stringByAppendingPathExtension:@"png"];
    if (!fileName.length)
        fileName = @"image.png";

    return fileName;
}

- (void)filePromiseProvider:(NSFilePromiseProvider *)filePromiseProvider
          writePromiseToURL:(NSURL *)url
          completionHandler:(void (^)(NSError *errorOrNil))completionHandler {

    NSData *bitmapData = [self pngData];


    NSError *error = nil;

    if (![bitmapData writeToURL:url options:NSDataWritingAtomic error:&error]) {
        NSLog(@"Error: Could not write PNG data to url %@: %@", url.path, error);
        completionHandler(error);
    }

    completionHandler(nil);
    NSLog(@"Your image has been saved to %@", url.path);
}


- (NSData *)pngData {
    if (!self.image)
        NSLog(@"No image?");
    NSBitmapImageRep *bitmaprep = [self.image bitmapImageRepresentation];

    NSDictionary *props = @{ NSImageInterlaced: @(NO) };
    return [NSBitmapImageRep representationOfImageRepsInArray:@[bitmaprep] usingType:NSBitmapImageFileTypePNG properties:props];
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSString *)accessibilityRole {
    return NSAccessibilityImageRole;
}

@end

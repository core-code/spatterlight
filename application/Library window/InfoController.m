#import "InfoController.h"

#import "Game.h"
#import "Metadata.h"
#import "AppDelegate.h"
#import "LibController.h"
#import "CoreDataManager.h"
#import "Image.h"
#import "IFDBDownloader.h"
#import "ImageView.h"

#import "Constants.h"

#import <QuartzCore/QuartzCore.h>

#ifdef DEBUG
#define NSLog(FORMAT, ...)                                                     \
fprintf(stderr, "%s\n",                                                    \
[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#else
#define NSLog(...)
#endif

@interface InfoPanel : NSWindow

@property BOOL disableConstrainedWindow;

@end

@implementation InfoPanel

- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen {
    return (_disableConstrainedWindow ? frameRect : [super constrainFrameRect:frameRect toScreen:screen]);
}

@end

@interface HelperView : NSView

@end

@implementation HelperView

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    InfoController *infocontroller = (InfoController *)self.window.delegate;

    if (infocontroller.inAnimation) {
        [super keyDown:event];
        return;
    }
    
    unichar code = [event.characters characterAtIndex:0];

    switch (code) {
        case ' ': {
            [[self window] performClose:nil];
            break;
        }
        case NSUpArrowFunctionKey: {
            [infocontroller.libcontroller closeAndOpenNextAbove:infocontroller];
            break;
        }
        case NSDownArrowFunctionKey: {
            [infocontroller.libcontroller closeAndOpenNextBelow:infocontroller];
            break;
        }
        default: {
            [super keyDown:event];
            break;
        }
    }
}

@end

@interface InfoController () <NSWindowDelegate, NSTextFieldDelegate, NSTextViewDelegate>
{
    IBOutlet NSTextField *authorField;
    IBOutlet NSTextField *headlineField;
    IBOutlet NSTextField *ifidField;
    IBOutlet NSTextField *descriptionText;
    IBOutlet ImageView *imageView;

    NSWindowController *snapshotController;

    CoreDataManager *coreDataManager;
    NSManagedObjectContext *managedObjectContext;
}
@end

@implementation InfoController

- (instancetype)init {
    self = [super initWithWindowNibName:@"InfoPanel"];
    if (self) {
        coreDataManager = ((AppDelegate*)[NSApplication sharedApplication].delegate).coreDataManager;
        managedObjectContext = coreDataManager.mainManagedObjectContext;
    }

    return self;
}

- (instancetype)initWithGame:(Game *)game  {
    self = [self init];
    if (self) {
        _game = game;
        _path = [game urlForBookmark].path;
        if (!_path)
            _path = game.path;
        _meta = game.metadata;
    }
    return self;
}

// Used for window restoration

- (instancetype)initWithpath:(NSString *)path {
    self = [self init];
    if (self) {
        _path = path;
        _game = [self fetchGameWithPath:path];
        if (_game)
            _meta = _game.metadata;
    }
    return self;
}

- (void)windowDidLoad {
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(noteManagedObjectContextDidChange:)
     name:NSManagedObjectContextObjectsDidChangeNotification
     object:managedObjectContext];

    if (imageView) {
        imageView.game = _game;

        NSImage *image = [[NSImage alloc] initWithData:(NSData *)_meta.cover.data];
        if (!image) {
            image = [NSImage imageNamed:@"Question"];
            imageView.isPlaceholder = YES;
        }
        [imageView processImage:image];
    } else NSLog(@"Error! No imageView!");

    [self update];
    [self sizeToFitImageAnimate:NO];

    _titleField.editable = YES;
    _titleField.delegate = self;

    authorField.editable = YES;
    authorField.delegate = self;

    headlineField.editable = YES;
    headlineField.delegate = self;

    //    ifidField.editable = YES;
    //    ifidField.delegate = self;

    descriptionText.editable = YES;
    descriptionText.delegate = self;

    [self.window makeFirstResponder:imageView];

    self.window.delegate = self;
}


+ (NSArray *)restorableStateKeyPaths {
    return @[
        @"path", @"titleField.stringValue", @"authorField.stringValue",
        @"headlineField.stringValue", @"descriptionText.string"
    ];
}

- (Game *)fetchGameWithPath:(NSString *)path {
    NSError *error = nil;
    NSArray *fetchedObjects;

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

    fetchRequest.entity = [NSEntityDescription entityForName:@"Game" inManagedObjectContext:managedObjectContext];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"path like[c] %@",path];

    fetchedObjects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (fetchedObjects == nil) {
        NSLog(@"Problem! %@",error);
    }

    if (fetchedObjects.count > 1)
    {
        NSLog(@"Found more than one entry with path %@",path);
    }
    else if (fetchedObjects.count == 0)
    {
        NSLog(@"fetchGameWithPath: Found no Game object with path %@", path);
        return nil;
    }

    return fetchedObjects[0];
}

- (void)sizeToFitImageAnimate:(BOOL)animate {
    if (_inAnimation)
        return;
    NSRect frame;
    NSSize wellsize;
    NSSize imgsize;
    NSSize cursize;
    NSSize setsize;
    NSSize maxsize;
    double scale;

    maxsize = self.window.screen.visibleFrame.size;
    wellsize = imageView.frame.size;
    cursize = self.window.frame.size;

    maxsize.width = maxsize.width * 0.75 - (cursize.width - wellsize.width);
    maxsize.height = maxsize.height * 0.75 - (cursize.height - wellsize.height);

    NSArray *imageReps = imageView.image.representations;

    NSInteger width = 0;
    NSInteger height = 0;

    for (NSImageRep *imageRep in imageReps) {
        if (imageRep.pixelsWide > width)
            width = imageRep.pixelsWide;
        if (imageRep.pixelsHigh > height)
            height = imageRep.pixelsHigh;
    }

    imgsize = NSMakeSize(width, height);

    if (height == 0)
        return;
    
    CGFloat ratio = (CGFloat)width / (CGFloat)height;

    if (imgsize.width > maxsize.width) {
        scale = maxsize.width / imgsize.width;
        imgsize.width *= scale;
        imgsize.height *= scale;
    }

    if (imgsize.height > maxsize.height) {
        scale = maxsize.height / imgsize.height;
        imgsize.width *= scale;
        imgsize.height *= scale;
    }

    if (imgsize.width < 100) {
        imgsize.width = 100;
        imgsize.height = 100 / ratio;
    }
    if (imgsize.height < 150) {
        imgsize.height = 150;
        imgsize.width = 150 * ratio;
    }

    setsize.width = cursize.width - wellsize.width + imgsize.width;
    setsize.height = cursize.height - wellsize.height + imgsize.height;

    frame = self.window.frame;
    frame.origin.y += frame.size.height;
    frame.size.width = setsize.width;
    frame.size.height = setsize.height;
    frame.origin.y -= setsize.height;
    if (NSMaxY(frame) > NSMaxY(self.window.screen.visibleFrame))
        frame.origin.y = NSMaxY(self.window.screen.visibleFrame) - frame.size.height;
    if (frame.origin.y < 0)
        frame.origin.y = 0;
    [self.window setFrame:frame display:YES animate:animate];
}

- (void)noteManagedObjectContextDidChange:(NSNotification *)notification {
    if (_inAnimation)
        return;
    NSArray *updatedObjects = (notification.userInfo)[NSUpdatedObjectsKey];
    NSArray *deletedObjects =  (notification.userInfo)[NSDeletedObjectsKey];
    if ([deletedObjects containsObject:_game])
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.window performClose:nil];
        });
    if ([updatedObjects containsObject:_meta] || [updatedObjects containsObject:_game] || [updatedObjects containsObject:_meta.cover])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self update];
            [self updateImage];
        });
    }
}

- (void)update {
    if (!_path)
        _path = _game.urlForBookmark.path;
    if (!_path)
        _path = _game.path;
    if (_path)
        self.window.representedFilename = _path;
    if (_meta.title.length) {
        self.window.title =
        [NSString stringWithFormat:@"%@ Info", _meta.title];
    } else if (_path) {
        self.window.title =
        [NSString stringWithFormat:@"%@ Info", _path.lastPathComponent];
    } else self.window.title = NSLocalizedString(@"Game Info", nil);

    if (_meta) {
        if (_meta.title.length)
            _titleField.stringValue = _meta.title;
        if (_meta.author.length)
            authorField.stringValue = _meta.author;
        if (_meta.headline.length)
            headlineField.stringValue = _meta.headline;
        if (_meta.blurb.length)
            descriptionText.stringValue = _meta.blurb;
        if (_game.ifid.length)
            ifidField.stringValue = _game.ifid;
    }
}

- (void)updateImage {
    NSImage *image = nil;
    if (_meta.cover) {
        image = [[NSImage alloc] initWithData:(NSData *)_meta.cover.data];
        imageView.isPlaceholder = NO;
    }

    if (!image) {
        image = [NSImage imageNamed:@"Question"];
        imageView.isPlaceholder = YES;
    }
    [imageView processImage:image];
    [self sizeToFitImageAnimate:YES];
}

- (void)windowWillClose:(NSNotification *)notification {

    // Make sure that all edits are saved
    if (![_meta.title isEqualToString:_titleField.stringValue])
        _meta.title = _titleField.stringValue;
    if (![_meta.headline isEqualToString:headlineField.stringValue])
        _meta.headline = headlineField.stringValue;
    if (![_meta.author isEqualToString:authorField.stringValue])
        _meta.author = authorField.stringValue;
    if (![_meta.blurb isEqualToString:descriptionText.stringValue])
        _meta.blurb = descriptionText.stringValue;

    // Crazy stuff to make stacks of windows close in a pretty way
    NSArray <InfoController *> *windowArray = _libcontroller.infoWindows.allValues;
    if (windowArray.count > 1) {
        // We look at the title fields of the array of open info window controllers
        // and sort them alphabetically
        windowArray =
        [windowArray sortedArrayUsingComparator:
                      ^NSComparisonResult(InfoController * obj1, InfoController * obj2){
            NSString *title1 = obj1.titleField.stringValue;
            NSString *title2 = obj2.titleField.stringValue;
            return [title1 localizedCaseInsensitiveCompare:title2];
        }];
        NSUInteger index = [windowArray indexOfObject:self];
        if (index != NSNotFound) {
            InfoController *next;
            if (index == 0)
                next = windowArray.lastObject;
            else
                next = windowArray[index - 1];
            [next.window makeKeyAndOrderFront:nil];
        }
    }

    [self animateOut];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    if ([notification.object isKindOfClass:[NSTextField class]])
    {
        NSTextField *textfield = notification.object;

        if (textfield == _titleField)
        {
            if (![_meta.title isEqualToString:_titleField.stringValue])
                _meta.title = _titleField.stringValue;
        }
        else if (textfield == headlineField)
        {
            if (![_meta.headline isEqualToString:headlineField.stringValue])
                _meta.headline = headlineField.stringValue;
        }
        else if (textfield == authorField)
        {
            if (![_meta.author isEqualToString:authorField.stringValue])
                _meta.author = authorField.stringValue;

        }  else if (textfield == descriptionText)
        {
            if (![_meta.blurb isEqualToString:descriptionText.stringValue]) {
                _meta.blurb = descriptionText.stringValue;
                NSLog(@"changed blurb to %@", _meta.blurb);
            }
        }
        //		else if (textfield == ifidField)
        //		{
        //			_game.ifid = [ifidField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        //		}

        // When the user has edited text and pressed enter, we want the field to be deselected,
        // but we must check that the user did not end editing by selecting a different field,
        // because then the edited field is already deselected and we don't want to deselect
        // the new one.
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.window.firstResponder == textfield.currentEditor) {
                [self.window makeFirstResponder:nil];
            }
        });
    }
}

- (BOOL)control:(NSControl*)control textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector
{
    if (textView == descriptionText.currentEditor && commandSelector == @selector(insertNewline:))
    {
        // Insert a line-break character and don't cause the receiver
        // to end editing
        [textView insertNewlineIgnoringFieldEditor:self];
        return YES;
    }

    return NO;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return managedObjectContext.undoManager;
}

#pragma mark animation

- (void)makeAndPrepareSnapshotWindow:(NSRect)startingframe {
    CALayer *snapshotLayer = [self takeSnapshot];
    NSWindow *snapshotWindow = ([[NSWindow alloc]
                       initWithContentRect:startingframe
                       styleMask:0
                       backing:NSBackingStoreBuffered
                       defer:NO]);

    snapshotWindow.contentView.wantsLayer = YES;
    snapshotWindow.opaque = NO;
    snapshotWindow.releasedWhenClosed = YES;
    snapshotWindow.backgroundColor = NSColor.clearColor;
    [snapshotWindow setFrame:startingframe display:NO];
    [snapshotWindow.contentView.layer addSublayer:snapshotLayer];

    snapshotController = [[NSWindowController alloc] initWithWindow:snapshotWindow];
    // Compute the frame of the snapshot layer such that the snapshot is
    // positioned on startingframe.
    NSRect snapshotLayerFrame =
    [snapshotWindow convertRectFromScreen:startingframe];
    snapshotLayer.frame = snapshotLayerFrame;
    [snapshotWindow orderFront:nil];
}

- (CALayer *)takeSnapshot {
    CGImageRef windowSnapshot =
    CGWindowListCreateImage(CGRectNull,
                            kCGWindowListOptionIncludingWindow,
                            (CGWindowID)[self.window windowNumber],
                            kCGWindowImageBoundsIgnoreFraming);
    CALayer *snapshotLayer = [[CALayer alloc] init];
    snapshotLayer.frame = self.window.frame;
    snapshotLayer.contents = CFBridgingRelease(windowSnapshot);
    snapshotLayer.anchorPoint = CGPointMake(0, 0);
    return snapshotLayer;
}

- (CALayer *)takeRowSnapshotFocused:(BOOL)focused {
    LibController *libcontroller = _libcontroller;
    NSRect rowrect = [libcontroller rectForLineWithIfid:_game.ifid];

    NSWindow *keyWindow = libcontroller.window;
    if (focused) {
        for (NSWindow *win in NSApplication.sharedApplication.windows) {
            if (win.isKeyWindow) {
                keyWindow = win;
                break;
            }
        }
        [libcontroller.window makeKeyWindow];
    }

    NSView *view = libcontroller.window.contentView;
    NSRect winrect = [libcontroller.window convertRectFromScreen:rowrect];

    NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:winrect];
    [view cacheDisplayInRect:winrect toBitmapImageRep:bitmap];

    NSImage *result = [[NSImage alloc] initWithSize:winrect.size];
    [result addRepresentation:bitmap];

    CALayer *snapshotLayer = [[CALayer alloc] init];
    snapshotLayer.contents = result;

    if (focused)
        [keyWindow makeKeyWindow];

    return snapshotLayer;
}

- (void)animateIn:(NSRect)finalframe {
    NSRect targetFrame = [_libcontroller rectForLineWithIfid:_game.ifid];

    [self makeAndPrepareSnapshotWindow:targetFrame];
    NSWindow *localSnapshot = snapshotController.window;
    NSView *snapshotView = localSnapshot.contentView;
    CALayer *snapshotLayer = snapshotView.layer.sublayers.firstObject;

    CALayer *rowLayer = [self takeRowSnapshotFocused:NO];
    [snapshotLayer addSublayer:rowLayer];
    rowLayer.layoutManager  = [CAConstraintLayoutManager layoutManager];
    rowLayer.autoresizingMask = kCALayerHeightSizable | kCALayerWidthSizable;
    rowLayer.frame = snapshotLayer.frame;

    CABasicAnimation *fadeOutAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeOutAnimation.fromValue = [NSNumber numberWithFloat:1.0];
    fadeOutAnimation.toValue = [NSNumber numberWithFloat:0.0];
    fadeOutAnimation.additive = NO;
    fadeOutAnimation.removedOnCompletion = NO;
    fadeOutAnimation.beginTime = 0.0;
    fadeOutAnimation.duration = .2;
    fadeOutAnimation.fillMode = kCAFillModeForwards;

    snapshotLayer.layoutManager  = [CAConstraintLayoutManager layoutManager];
    snapshotLayer.autoresizingMask = kCALayerHeightSizable | kCALayerWidthSizable;

    [localSnapshot setFrame:targetFrame display:YES];

    [NSAnimationContext
     runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.2;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

        [rowLayer addAnimation:fadeOutAnimation forKey:nil];

        [[localSnapshot animator] setFrame:finalframe display:YES];
    }
     completionHandler:^{
        [rowLayer removeFromSuperlayer];
        self.window.alphaValue = 1.f;
        [self.window setFrame:finalframe display:YES];
        [self showWindow:nil];
        snapshotView.hidden = YES;
        [self->snapshotController close];
        self.inAnimation = NO;
    }];
}

- (void)animateOut {
    _inAnimation = YES;

    [self makeAndPrepareSnapshotWindow:self.window.frame];
    NSWindow *localSnapshot = snapshotController.window;
    NSView *snapshotView = localSnapshot.contentView;
    CALayer *snapshotLayer = localSnapshot.contentView.layer.sublayers.firstObject;

    LibController *libctrl = _libcontroller;

    snapshotLayer.layoutManager  = [CAConstraintLayoutManager layoutManager];
    snapshotLayer.autoresizingMask = kCALayerHeightSizable | kCALayerWidthSizable;
    NSRect targetFrame = [libctrl rectForLineWithIfid:_game.ifid];
    NSArray <InfoController *> *windowArray = libctrl.infoWindows.allValues;
    CALayer *rowLayer = [self takeRowSnapshotFocused:(windowArray.count < 2)];
    [snapshotLayer addSublayer:rowLayer];
    rowLayer.opacity = 0.0;
    rowLayer.layoutManager  = [CAConstraintLayoutManager layoutManager];
    rowLayer.autoresizingMask = kCALayerHeightSizable | kCALayerWidthSizable;
    rowLayer.frame = snapshotLayer.frame;

    CABasicAnimation *fadeInAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeInAnimation.fromValue = [NSNumber numberWithFloat:0.0];
    fadeInAnimation.toValue = [NSNumber numberWithFloat:0.5];
    fadeInAnimation.additive = NO;
    fadeInAnimation.removedOnCompletion = NO;
    fadeInAnimation.beginTime = 0.0;
    fadeInAnimation.duration = 0.3;
    fadeInAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    fadeInAnimation.fillMode = kCAFillModeForwards;


    [NSAnimationContext
     runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.3;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [[localSnapshot animator] setFrame:targetFrame display:YES];
        [rowLayer addAnimation:fadeInAnimation forKey:nil];
    }
     completionHandler:^{
        self.inAnimation = NO;
        snapshotView.hidden = YES;
        [self->snapshotController close];
        self->snapshotController = nil;

        // It seems we have to do it in this cumbersome way because the game.path used for key may have changed.
        // Probably a good reason to use something else as key.
        for (InfoController *controller in [libctrl.infoWindows allValues])
            if (controller == self) {
                NSArray *temp = [libctrl.infoWindows allKeysForObject:controller];
                NSString *key = [temp objectAtIndex:0];
                if (key) {
                    [libctrl.infoWindows removeObjectForKey:key];
                    return;
                }
            }
    }];
}

-(void)hideWindow {
    _inAnimation = YES;
    // So we need to get a screenshot of the window without flashing.
    // First, we find the frame that covers all the connected screens.
    CGRect allWindowsFrame = CGRectZero;

    for(NSScreen *screen in [NSScreen screens]) {
        allWindowsFrame = NSUnionRect(allWindowsFrame, screen.frame);
    }

    // Position our window to the very right-most corner out of visible range, plus padding for the shadow.
    CGRect frame = (CGRect){
        .origin = CGPointMake(CGRectGetWidth(allWindowsFrame) + 2 * 19.f, 0),
        .size = self.window.frame.size
    };

    // This is where things get nasty. Against what the documentation states, windows seem to be constrained
    // to the screen, so we override "constrainFrameRect:toScreen:" to return the original frame, which allows
    // us to put the window off-screen.
    ((InfoPanel *)self.window).disableConstrainedWindow = YES;

    [self.window setFrame:frame display:YES];
    [self showWindow:nil];
}

@end

//
//  PreviewViewController.h
//  SpatterlightQuickLook
//
//  Created by Administrator on 2021-01-29.
//

#import <Cocoa/Cocoa.h>

@class NSPersistentContainer, UKSyntaxColor, MyTextView;

API_AVAILABLE(macos(10.12))
@interface PreviewViewController : NSViewController {
    NSMutableArray *ifidbuf;
    NSMutableDictionary *metabuf;
}

@property NSSize originalImageSize;
@property CGFloat preferredWidth;
@property BOOL showingIcon;
@property BOOL dontResize;
@property BOOL addedFileInfo;


@property NSString *ifid;

@property UKSyntaxColor *syntaxColorer;

//@property (readonly) CoreDataManager *coreDataManager;
@property (readonly) NSPersistentContainer *persistentContainer;

//@property (weak) Game *game;
@property (weak) NSString *string;

//@property (weak) IBOutlet NSTextField *titleField;
//@property (weak) IBOutlet NSTextField *authorField;
//@property (weak) IBOutlet NSTextField *headlineField;
//@property (weak) IBOutlet NSTextField *ifidField;
//@property (weak) IBOutlet NSTextField *titleField;

@property (unsafe_unretained) IBOutlet MyTextView *textview;

@property (weak) IBOutlet NSImageView *imageView;
@property (weak) IBOutlet NSLayoutConstraint *scrollviewtTopConstraint;
@property (weak) IBOutlet NSLayoutConstraint *scrollviewBottomConstraint;

@end

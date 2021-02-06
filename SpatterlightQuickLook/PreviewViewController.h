//
//  PreviewViewController.h
//  SpatterlightQuickLook
//
//  Created by Administrator on 2021-01-29.
//

#import <Cocoa/Cocoa.h>

@class NSPersistentContainer;

API_AVAILABLE(macos(10.12))
@interface PreviewViewController : NSViewController {
    NSMutableArray *ifidbuf;
    NSMutableDictionary *metabuf;
}

@property NSSize originalImageSize;

//@property (readonly) CoreDataManager *coreDataManager;
@property (readonly) NSPersistentContainer *persistentContainer;

//@property (weak) Game *game;
@property (weak) NSString *string;

//@property (weak) IBOutlet NSTextField *titleField;
//@property (weak) IBOutlet NSTextField *authorField;
//@property (weak) IBOutlet NSTextField *headlineField;
//@property (weak) IBOutlet NSTextField *ifidField;
//@property (weak) IBOutlet NSTextField *titleField;

@property (unsafe_unretained) IBOutlet NSTextView *textview;

@property (weak) IBOutlet NSImageView *imageView;

@end

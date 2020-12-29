//
//  PreviewViewController.h
//  SpatterlightQuickLook
//
//  Created by Administrator on 2021-01-29.
//

#import <Cocoa/Cocoa.h>

@class Game, CoreDataManager;

@interface PreviewViewController : NSViewController {
    NSBox *topSpacer;
    NSImageView *imageView;
    NSTextField *titleField;
    NSTextField *headlineField;
    NSTextField *authorField;
    NSTextField *blurbField;
    NSTextField *ifidField;

    CGFloat totalHeight;

    NSMutableArray *ifidbuf;
    NSMutableDictionary *metabuf;
}

//@property (readonly) CoreDataManager *coreDataManager;
//@property (weak) NSManagedObjectContext *managedObjectContext;

//@property (weak) Game *game;
@property (weak) NSString *string;

@end

#import <Foundation/Foundation.h>

#include "glk.h"
#include "glkstart.h"
#include "fileref.h"

#import "TempLibrary.h"

extern void spatterglk_do_autosave(glui32 eventaddr);
extern void spatterglk_clear_autosave(void);
extern void spatterglk_set_can_restart_flag(int);
extern int spatterglk_can_restart_cleanly(void);
extern void spatterglk_shut_down_process(void) GLK_ATTRIBUTE_NORETURN;

NSDate *lastAutosaveTimestamp;

/* This object contains VM state which is not stored in a normal save file, but which is needed for an autorestore.

 (The reason it's not stored in a normal save file is that it's useless unless you serialize the entire Glk state along with the VM. Glulx normally doesn't do that, but for an autosave, we do.)
 */

@interface LibraryState : NSObject {}

- (instancetype) initWithLibrary:(TempLibrary*) library;

@property BOOL active;
@property glui32 protectstart, protectend;
@property glui32 iosys_mode, iosys_rock;
@property glui32 stringtable;
@property NSMutableArray *accel_params; // array of NSNumber -- manually retained!
@property NSMutableArray *accel_funcs; // array of GlulxAccelEntry -- manually retained!
@property glui32 gamefiletag;
@property NSMutableArray *id_map_list; // array of GlkObjIdEntry -- manually retained!

@end


@interface GlkObjIdEntry  : NSObject {
}

- (id) initWithClass:(int)objclass tag:(glui32)tag id:(glui32)dispid;

@property glui32 objclass;
@property glui32 tag;
@property glui32 dispid;

@end

@interface GlulxAccelEntry : NSObject {
	glui32 index;
	glui32 addr;
}

- (instancetype) initWithIndex:(glui32)index addr:(glui32)addr;

- (glui32) index;
- (glui32) addr;

@end

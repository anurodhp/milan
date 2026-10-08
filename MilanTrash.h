/* MilanTrash: the Mac model. Each volume has its own trash (~/.Trash for the home volume,
 * <mount>/.Trashes/<uid> elsewhere) so trashing is a rename, never a cross-disk copy. The Trash
 * window is a merged view of all of them under one virtual path. Put Back origins live in a
 * .milan-origins plist inside each trash directory. Nothing in a trash may be opened or run. */
#import <Foundation/Foundation.h>
#import "MilanFileOps.h"

extern NSString *const MilanTrashPath;	/* the virtual path of the merged Trash view */
extern NSString *const MilanTrashOriginsName;	/* sidecar file name, hidden from listings */

BOOL MilanPathInTrash(NSString *path);	/* inside any trash directory (or the virtual Trash itself) */
void MilanSetTrashHome(NSString *dir);	/* tests only: replaces ~/.Trash */

@interface MilanTrash : NSObject
/* Existing trash directories: the home one first, then one per mounted volume that has one. */
+ (NSArray *) trashDirectories;
+ (void) trashPaths: (NSArray *)paths done: (MilanOpDone)done;
+ (void) putBackPaths: (NSArray *)paths done: (MilanOpDone)done;	/* top-level trash items only */
+ (void) emptyDone: (MilanOpDone)done;
@end

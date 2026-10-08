/* MilanIcons: cheap icon lookup. Folders and plain files share one image per
 * type/extension; only .app bundles hit NSWorkspace per path. Main thread only. */
#import <AppKit/AppKit.h>
#import "MilanEntry.h"

@interface MilanIcons : NSObject
+ (NSImage *) iconForEntry: (MilanEntry *)e;
@end

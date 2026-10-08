/* MilanQuickLook: Space previews the selected item (PNG/TIFF image, or text) as an overlay on the window's content
 * area; Space or Esc closes it, the arrow keys step to the previous/next item. An overlay view, not a window: see
 * docs/notes.md on why extra X windows are avoided. */
#import <AppKit/AppKit.h>
#import "MilanEntry.h"

@protocol MilanQuickLookNavigator
/* Moves the browser selection by delta (-1 / +1) and returns the new entry, or nil at the ends. */
- (MilanEntry *) quickLookStep: (int)delta;
@end

@interface MilanQuickLook : NSObject
+ (BOOL) isActive;
+ (void) showEntry: (MilanEntry *)e over: (NSView *)area navigator: (id <MilanQuickLookNavigator>)nav;
+ (void) dismiss;
@end

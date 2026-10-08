/* The contract between the window controller and its three view styles. */
#import <AppKit/AppKit.h>
#import "MilanEntry.h"

@protocol MilanContentDelegate
- (void) contentOpen: (NSArray *)entries;
- (void) contentSelectionChanged;
- (NSMenu *) contentMenu;
- (void) contentLoadPath: (NSString *)path completion: (void (^)(NSArray *entries))done;
- (void) contentSortBy: (MilanSort)key;	/* list header click */
- (void) contentQuickLook;	/* Space bar */
/* Files dropped from a drag: onto a folder path, or (nil) the directory being browsed. */
- (void) contentDropPaths: (NSArray *)paths onto: (NSString *)folder copy: (BOOL)copy;
@end

@protocol MilanContent
- (NSView *) view;
- (void) setDelegate: (id <MilanContentDelegate>)d;
- (void) setPath: (NSString *)path entries: (NSArray *)entries;	/* navigate: clears selection */
- (void) reloadEntries: (NSArray *)entries;	/* refresh: keeps selection by path */
- (NSArray *) selectedEntries;
- (void) selectAll;
- (void) selectPath: (NSString *)path;
- (NSString *) browsedPath;	/* deepest directory shown (columns), else the root path */
@end

/* Shows a context menu at the event's location, and closes it again. See MilanContent.m for why this is not
 * -popUpContextMenu:. */
void MilanPopUpMenu(NSMenu *menu, NSView *view, NSEvent *event);
void MilanDismissMenu(void);

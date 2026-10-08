/* The contract between the window controller and its three view styles. */
#import <AppKit/AppKit.h>
#import "MilanEntry.h"

@protocol MilanContentDelegate
- (void) contentOpen: (NSArray *)entries;
- (void) contentSelectionChanged;
- (NSMenu *) contentMenu;
- (void) contentLoadPath: (NSString *)path completion: (void (^)(NSArray *entries))done;
- (void) contentSortBy: (MilanSort)key;	/* list header click */
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

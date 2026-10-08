/* MilanListView: sortable multi-column table (Name, Date Modified, Size, Kind). */
#import "MilanContent.h"

/* NSTableView that asks the delegate for the context menu and Return/Delete keys. */
@interface MilanTable : NSTableView
{
	id <MilanContentDelegate> menuDelegate;
}
- (void) setMenuDelegate: (id <MilanContentDelegate>)d;
@end

@interface MilanListView : NSObject <MilanContent, NSTableViewDataSource, NSTableViewDelegate>
{
	NSScrollView *scroll;
	MilanTable *table;
	NSArray *entries;
	NSString *path;
	id <MilanContentDelegate> delegate;
}
@end

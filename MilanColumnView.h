/* MilanColumnView: Finder-style column browser. Each column is its own table;
 * selecting a folder loads it (async) into a new column to the right. */
#import "MilanContent.h"

@class MilanColumn;

@interface MilanColumnView : NSObject <MilanContent>
{
	NSScrollView *scroll;
	NSView *doc;
	NSMutableArray *columns;	/* MilanColumn */
	id <MilanContentDelegate> delegate;
	unsigned gen;
	BOOL relaying;
}
- (void) column: (MilanColumn *)c selectionChanged: (NSArray *)sel;
- (void) column: (MilanColumn *)c open: (NSArray *)sel;
- (NSMenu *) menu;
- (id <MilanContentDelegate>) contentDelegate;
@end

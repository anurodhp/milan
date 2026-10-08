/* MilanIconView: custom-drawn icon grid. Only the visible rows are drawn.
 * MilanIconGrid is the document view; MilanIconView is the controller around it. */
#import "MilanContent.h"

@interface MilanIconGrid : NSView <NSDraggingSource>
{
@public
	id <MilanContentDelegate> delegate;
	NSArray *entries;
	NSString *path;
	NSMutableIndexSet *sel;
	NSInteger anchor, cols;
	BOOL relaying, rubber, dragging, pendingDrag;
	BOOL desktop;		/* transparent, no scrolling, icons flow down from the top right */
	NSInteger perCol;
	NSString *slotsKey;			/* defaults key holding {name: "col row"} for icons the user placed */
	NSMutableArray *slotCells;		/* per entry: NSArray {col,row} (columns count from the right edge) */
	NSMutableDictionary *cellToIndex;	/* col*10000+row -> entry index */
	NSInteger dragAnchor;
	NSPoint downPoint;
	NSRect rubberRect;
	NSMutableIndexSet *baseSel;
	NSMutableString *typed;
	NSTimeInterval typedAt;
}
- (void) setEntries: (NSArray *)e keepSelection: (BOOL)keep;
- (NSArray *) selectedEntries;
- (void) selectPath: (NSString *)p;
- (void) setDesktop: (BOOL)d;
- (void) setSlotsKey: (NSString *)k;
@end

@interface MilanIconView : NSObject <MilanContent>
{
	NSScrollView *scroll;
	MilanIconGrid *grid;
}
- (id) initForDesktop;
@end

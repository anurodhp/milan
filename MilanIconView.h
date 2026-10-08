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
@end

@interface MilanIconView : NSObject <MilanContent>
{
	NSScrollView *scroll;
	MilanIconGrid *grid;
}
- (id) initForDesktop;
@end

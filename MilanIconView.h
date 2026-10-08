/* MilanIconView: custom-drawn icon grid. Only the visible rows are drawn.
 * MilanIconGrid is the document view; MilanIconView is the controller around it. */
#import "MilanContent.h"

@interface MilanIconGrid : NSView
{
@public
	id <MilanContentDelegate> delegate;
	NSArray *entries;
	NSString *path;
	NSMutableIndexSet *sel;
	NSInteger anchor, cols;
	BOOL relaying;
}
- (void) setEntries: (NSArray *)e keepSelection: (BOOL)keep;
- (NSArray *) selectedEntries;
- (void) selectPath: (NSString *)p;
@end

@interface MilanIconView : NSObject <MilanContent>
{
	NSScrollView *scroll;
	MilanIconGrid *grid;
}
@end

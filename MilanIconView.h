/* MilanIconView: custom-drawn icon grid. Only the visible rows are drawn. */
#import "MilanContent.h"

@interface MilanIconView : NSView <MilanContent>
{
	NSScrollView *scroll;
	NSArray *entries;
	NSString *path;
	NSMutableIndexSet *sel;
	NSInteger anchor;
	id <MilanContentDelegate> delegate;
	NSInteger cols;
}
@end

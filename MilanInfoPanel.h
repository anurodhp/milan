/* MilanInfoPanel: one non-modal metadata panel per file; any number may be open. */
#import <AppKit/AppKit.h>
#import "MilanEntry.h"

@interface MilanInfoPanel : NSObject <NSWindowDelegate>
{
	NSPanel *panel;
	NSTextField *sizeField;
	MilanEntry *entry;
	volatile BOOL cancelled;
}
/* Shows (or raises, if already open for this path) the panel for a path. */
+ (void) showForPath: (NSString *)path;
@end

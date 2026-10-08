/* MilanWindow: one browser window -- toolbar, path field, content view, status line. */
#import <AppKit/AppKit.h>
#import "MilanContent.h"

@interface MilanWindow : NSObject <NSWindowDelegate, MilanContentDelegate, NSTableViewDataSource, NSTableViewDelegate>
{
	NSWindow *window;
	NSString *path;
	NSMutableArray *history;
	NSInteger hIndex;
	int mode;	/* 0 icons, 1 list, 2 columns */
	id <MilanContent> views[3];
	id <MilanContent> cur;
	NSView *host;
	NSTextField *status;
	NSSegmentedControl *modeSeg;
	NSButton *backBtn, *fwdBtn, *upBtn;
	BOOL showHidden, ascending, reloadPending;
	MilanSort sortKey;
	NSArray *entries;
	unsigned gen;
	void *watch;	/* dispatch_source_t */
	NSArray *clipPaths;
	BOOL clipCut;
	NSInteger clipChange;
	NSMenu *ctxMenu;
	NSScrollView *sidebar;
	NSTableView *sidebarTable;
	NSArray *favorites;
}
- (id) initWithPath: (NSString *)p;
- (NSWindow *) window;
- (NSString *) currentPath;
- (void) goTo: (NSString *)p;
- (void) runSelfTest;
- (void) goBack: (id)s;
- (void) goForward: (id)s;
- (void) goUp: (id)s;
- (void) goHome: (id)s;
- (void) goApplications: (id)s;
- (void) goRoot: (id)s;
- (void) setViewMode: (id)s;
- (void) setMode: (int)m;
- (void) viewAsIcons: (id)s;
- (void) viewAsList: (id)s;
- (void) viewAsColumns: (id)s;
- (void) toggleHidden: (id)s;
- (void) openSelection: (id)s;
- (void) getInfo: (id)s;
- (void) copyFiles: (id)s;
- (void) cutFiles: (id)s;
- (void) pasteFiles: (id)s;
- (void) trashSelection: (id)s;
- (void) newFolder: (id)s;
- (void) renameSelection: (id)s;
- (void) selectAllItems: (id)s;
- (BOOL) validateMenuItem: (NSMenuItem *)item;
@end

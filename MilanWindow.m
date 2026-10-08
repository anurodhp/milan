#import "MilanWindow.h"
#import "MilanIconView.h"
#import "MilanListView.h"
#import "MilanColumnView.h"
#import "MilanFileOps.h"
#import "MilanInfoPanel.h"
#import "MilanIcons.h"
#import "MilanTrash.h"
#import "MilanWallpaper.h"
#include <fcntl.h>
#include <sys/mount.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dispatch/dispatch.h>

#define BAR_H 40.0
#define STATUS_H 20.0
#define SIDEBAR_W 140.0

/* the desktop: a borderless window at the desktop level; Window Maker gives such a window no decoration, puts it
 * on every workspace, hides it from the window list and keeps it below everything (wmspec.c handleWindowType) */
@interface MilanDesktopWindow : NSWindow
@end

@implementation MilanDesktopWindow
- (BOOL) canBecomeKeyWindow { return YES; }
- (BOOL) canBecomeMainWindow { return NO; }
@end

@implementation MilanWindow

static NSButton *
barButton(NSString *title, NSRect r, id target, SEL action, NSString *tip)
{
	NSButton *b = [[[NSButton alloc] initWithFrame: r] autorelease];
	[b setTitle: title];
	[b setBezelStyle: NSTexturedRoundedBezelStyle];
	[b setTarget: target];
	[b setAction: action];
	[b setToolTip: tip];
	return b;
}

static NSButton *
iconButton(NSString *name, NSRect r, id target, SEL action, NSString *tip)
{
	NSButton *b = [[[NSButton alloc] initWithFrame: r] autorelease];
	[b setBordered: NO];
	[b setButtonType: NSMomentaryChangeButton];
	[b setImagePosition: NSImageOnly];
	[b setImage: [MilanIcons imageNamed: [NSString stringWithFormat: @"tb-%@-normal", name]]];
	[b setAlternateImage: [MilanIcons imageNamed: [NSString stringWithFormat: @"tb-%@-pressed", name]]];
	[b setTarget: target];
	[b setAction: action];
	[b setToolTip: tip];
	[b setIdentifier: name];
	return b;
}

static void
setEnabledIcon(NSButton *b, BOOL on)
{
	NSString *n = [b identifier];
	[b setEnabled: on];
	[b setImage: [MilanIcons imageNamed: [NSString stringWithFormat: @"tb-%@-%@", n, on ? @"normal" : @"disabled"]]];
}

- (id) initWithPath: (NSString *)p
{
	NSRect fr = NSMakeRect(120, 160, 860, 560);
	NSView *cv, *bar;
	CGFloat x = 8;
	static int cascade;

	self = [super init];
	history = [[NSMutableArray alloc] init];
	hIndex = -1;
	ascending = YES;
	fr.origin.x += cascade * 24; fr.origin.y -= cascade * 24;
	{
		NSString *o = [[NSUserDefaults standardUserDefaults] stringForKey: @"MilanOrigin"];	/* "x,y" */
		NSArray *xy = [o componentsSeparatedByString: @","];
		if ([xy count] == 2) { fr.origin.x = [[xy objectAtIndex: 0] doubleValue]; fr.origin.y = [[xy objectAtIndex: 1] doubleValue]; }
	}
	cascade = (cascade + 1) % 8;
	window = [[NSWindow alloc] initWithContentRect: fr
	    styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
	    backing: NSBackingStoreBuffered defer: NO];
	[window setReleasedWhenClosed: NO];
	{
		NSValue *saved = [MilanWindow savedFrameForPath: p];	/* the frame this folder had last time */
		if (saved) [window setFrame: [saved rectValue] display: NO];
	}
	[window setDelegate: self];
	[window setMinSize: NSMakeSize(480, 280)];
	cv = [window contentView];

	/* top panel: navigation, view mode, actions (Lucide glyphs, see tools/make_icons.sh) */
	bar = [[[NSView alloc] initWithFrame: NSMakeRect(0, NSHeight([cv bounds]) - BAR_H, NSWidth([cv bounds]), BAR_H)] autorelease];
	[bar setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
	backBtn = iconButton(@"back", NSMakeRect(x, 6, 30, 28), self, @selector(goBack:), @"Back"); x += 30;
	fwdBtn = iconButton(@"forward", NSMakeRect(x, 6, 30, 28), self, @selector(goForward:), @"Forward"); x += 30;
	upBtn = iconButton(@"up", NSMakeRect(x, 6, 30, 28), self, @selector(goUp:), @"Enclosing folder"); x += 42;
	[bar addSubview: backBtn]; [bar addSubview: fwdBtn]; [bar addSubview: upBtn];
	modeSeg = [[[NSSegmentedControl alloc] initWithFrame: NSMakeRect(x, 6, 108, 28)] autorelease];
	[modeSeg setSegmentCount: 3];
	{
		NSString *n[] = { @"icons", @"list", @"columns" };
		NSString *tips[] = { @"as Icons", @"as List", @"as Columns" };
		int i;
		for (i = 0; i < 3; i++) {
			[modeSeg setImage: [MilanIcons imageNamed: [NSString stringWithFormat: @"tb-%@-normal", n[i]]] forSegment: i];
			[modeSeg setWidth: 36 forSegment: i];
		}
		(void)tips;
	}
	[modeSeg setSelectedSegment: 0];
	[modeSeg setTarget: self];
	[modeSeg setAction: @selector(setViewMode:)];
	[bar addSubview: modeSeg];
	{
		NSString *n[] = { @"newfolder", @"info", @"copy", @"paste", @"trash" };
		NSString *tip[] = { @"New Folder", @"Get Info", @"Copy", @"Paste", @"Move to Trash" };
		SEL sels[] = { @selector(newFolder:), @selector(getInfo:), @selector(copyFiles:),
		               @selector(pasteFiles:), @selector(trashSelection:) };
		CGFloat rx = NSWidth([bar bounds]) - 5 * 34 - 8;
		int i;
		for (i = 0; i < 5; i++) {
			NSButton *b = iconButton(n[i], NSMakeRect(rx, 6, 32, 28), self, sels[i], tip[i]);
			[b setAutoresizingMask: NSViewMinXMargin];
			[bar addSubview: b];
			rx += 34;
		}
	}
	[cv addSubview: bar];

	/* favorites sidebar */
	{
		NSTableColumn *c;
		NSMutableArray *fav = [NSMutableArray array];
		NSString *h = NSHomeDirectory(), *d;
		NSFileManager *fm = [NSFileManager defaultManager];
		[fav addObject: [NSArray arrayWithObjects: @"Home", h, @"ft-folder", nil]];
		for (d in [NSArray arrayWithObjects: @"Desktop", @"Documents", @"Downloads", nil])
			if ([fm fileExistsAtPath: [h stringByAppendingPathComponent: d]])
				[fav addObject: [NSArray arrayWithObjects: d, [h stringByAppendingPathComponent: d], @"ft-folder", nil]];
		[fav addObject: [NSArray arrayWithObjects: @"Applications", @"/Applications", @"ft-app", nil]];
		[fav addObject: [NSArray arrayWithObjects: @"Computer", @"/", @"ft-disk", nil]];
		[fav addObject: [NSArray arrayWithObjects: @"Trash", MilanTrashPath, @"ft-trash", nil]];
		favorites = [fav retain];
		sidebarTable = [[NSTableView alloc] initWithFrame: NSMakeRect(0, 0, SIDEBAR_W, 200)];
		c = [[[NSTableColumn alloc] initWithIdentifier: @"favicon"] autorelease];
		[c setWidth: 22];
		[c setDataCell: [[[NSImageCell alloc] init] autorelease]];
		[sidebarTable addTableColumn: c];
		c = [[[NSTableColumn alloc] initWithIdentifier: @"fav"] autorelease];
		[c setWidth: SIDEBAR_W - 26];
		{
			NSTextFieldCell *tc = [[[NSTextFieldCell alloc] initTextCell: @""] autorelease];
			[tc setFont: [NSFont systemFontOfSize: 12]];
			[c setDataCell: tc];
		}
		[sidebarTable addTableColumn: c];
		[sidebarTable setHeaderView: nil];
		[sidebarTable setRowHeight: 24];
		[sidebarTable setIntercellSpacing: NSMakeSize(0, 0)];
		[sidebarTable setDataSource: self];
		[sidebarTable setDelegate: self];
		sidebar = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, STATUS_H, SIDEBAR_W, NSHeight([cv bounds]) - BAR_H - STATUS_H)] autorelease];
		[sidebar setHasVerticalScroller: YES];
		[sidebar setAutohidesScrollers: YES];
		[sidebar setBorderType: NSNoBorder];
		[sidebar setAutoresizingMask: NSViewHeightSizable];
		[sidebar setDocumentView: sidebarTable];
		[cv addSubview: sidebar];
	}
	host = [[[NSView alloc] initWithFrame: NSMakeRect(SIDEBAR_W, STATUS_H, NSWidth([cv bounds]) - SIDEBAR_W, NSHeight([cv bounds]) - BAR_H - STATUS_H)] autorelease];
	[host setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[cv addSubview: host];
	status = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, NSWidth([cv bounds]), STATUS_H)] autorelease];
	[status setEditable: NO]; [status setBezeled: NO]; [status setDrawsBackground: NO];
	[status setAlignment: NSCenterTextAlignment];
	[status setFont: [NSFont systemFontOfSize: 11]];
	[status setAutoresizingMask: NSViewWidthSizable | NSViewMaxYMargin];
	[cv addSubview: status];

	views[0] = [[MilanIconView alloc] init];
	views[1] = [[MilanListView alloc] init];
	views[2] = [[MilanColumnView alloc] init];
	{
		int i;
		for (i = 0; i < 3; i++) [views[i] setDelegate: self];
	}
	[self buildContextMenu];
	[self switchToMode: 0];
	[self goTo: p];
	[window makeKeyAndOrderFront: nil];
	[self performSelector: @selector(startSavingFrames) withObject: nil afterDelay: 1.5];
	return self;
}

- (id) initDesktop
{
	NSRect scr = [[NSScreen mainScreen] frame];
	NSView *dv;
	NSString *dir = [[NSUserDefaults standardUserDefaults] stringForKey: @"MilanDesktopPath"];	/* default ~/Desktop */
	self = [super init];
	if (![dir length]) dir = [NSHomeDirectory() stringByAppendingPathComponent: @"Desktop"];
	desktop = YES;
	history = [[NSMutableArray alloc] init];
	hIndex = -1;
	ascending = YES;
	[[NSFileManager defaultManager] createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL];
	window = [[MilanDesktopWindow alloc] initWithContentRect: scr styleMask: NSBorderlessWindowMask
	                                                 backing: NSBackingStoreBuffered defer: NO];
	[window setLevel: NSDesktopWindowLevel];
	[window setReleasedWhenClosed: NO];
	[window setDelegate: self];
	[window setTitle: @"Desktop"];
	dv = [[[MilanDesktopView alloc] initWithFrame: NSMakeRect(0, 0, scr.size.width, scr.size.height)] autorelease];
	[window setContentView: dv];
	/* keep icons clear of the menu bar (top) and the Window Maker dock column (right) */
	host = [[[NSView alloc] initWithFrame: NSMakeRect(0, 8, scr.size.width - 72, scr.size.height - 34)] autorelease];
	[host setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[dv addSubview: host];
	views[0] = [[MilanIconView alloc] initForDesktop];
	[views[0] setDelegate: self];
	[self buildContextMenu];
	cur = views[0];
	[[cur view] setFrame: [host bounds]];
	[host addSubview: [cur view]];
	[self goTo: dir];
	[window orderFront: nil];
	[window display];
	return self;
}

- (void) dealloc
{
	int i;
	[sidebarTable setDataSource: nil]; [sidebarTable setDelegate: nil];
	[sidebarTable release]; [favorites release];
	[self stopWatching];
	for (i = 0; i < 3; i++) { [views[i] setDelegate: nil]; [(id)views[i] release]; }
	[window setDelegate: nil];
	[window release]; [path release]; [history release]; [entries release];
	[clipPaths release]; [ctxMenu release]; [blankMenu release];
	[super dealloc];
}

- (NSWindow *) window { return window; }
/* the folder actions apply to: the window's own folder at once on navigation (the view only catches up
 * when the load completes); in columns view, the deepest open column */
- (NSString *) currentPath
{
	if (mode == 2 && [cur browsedPath]) return [cur browsedPath];
	return path ? path : NSHomeDirectory();
}

/* ---- navigation ---- */

- (void) goTo: (NSString *)p
{
	if (![p isEqualToString: MilanTrashPath]) p = [p stringByStandardizingPath];
	if ([p length] == 0) p = @"/";
	if (hIndex >= 0 && [[history objectAtIndex: hIndex] isEqualToString: p] && [p isEqualToString: path]) return;
	while ((NSInteger)[history count] > hIndex + 1) [history removeLastObject];
	[history addObject: p];
	hIndex = [history count] - 1;
	[self showHistoryEntry];
}

- (void) showHistoryEntry
{
	[path release];
	path = [[history objectAtIndex: hIndex] retain];
	setEnabledIcon(backBtn, hIndex > 0);
	setEnabledIcon(fwdBtn, hIndex < (NSInteger)[history count] - 1);
	setEnabledIcon(upBtn, ![path isEqualToString: @"/"] && ![path isEqualToString: MilanTrashPath]);
	[self syncSidebar];
	if (desktop) {
		[window setTitle: @"Desktop"];
	} else if ([path isEqualToString: MilanTrashPath]) {
		[window setTitle: @"Trash"];
	} else {
		[window setTitle: [path isEqualToString: @"/"] ? @"/" : [path lastPathComponent]];
		[window setRepresentedFilename: path];
	}
	[self load: YES];
	[self watchPath];
}

- (void) goBack: (id)s { if (hIndex > 0) { hIndex--; [self showHistoryEntry]; } }
- (void) goForward: (id)s { if (hIndex + 1 < (NSInteger)[history count]) { hIndex++; [self showHistoryEntry]; } }
- (void) goUp: (id)s { if (![path isEqualToString: @"/"] && ![path isEqualToString: MilanTrashPath]) [self goTo: [path stringByDeletingLastPathComponent]]; }
- (void) goHome: (id)s { [self goTo: NSHomeDirectory()]; }
- (void) goApplications: (id)s { [self goTo: @"/Applications"]; }
- (void) goRoot: (id)s { [self goTo: @"/"]; }
- (void) goTrash: (id)s { [self goTo: MilanTrashPath]; }

/* ---- favorites sidebar ---- */

- (NSInteger) numberOfRowsInTableView: (NSTableView *)t { return [favorites count]; }

- (id) tableView: (NSTableView *)t objectValueForTableColumn: (NSTableColumn *)c row: (NSInteger)r
{
	NSArray *f = [favorites objectAtIndex: r];
	if ([[c identifier] isEqualToString: @"favicon"]) {
		if ([[f objectAtIndex: 1] isEqualToString: MilanTrashPath]) {
			/* the Eau theme's own Recycler images (common_RecyclerEmpty/Full), as GWorkspace's dock uses */
			NSImage *ti = [NSImage imageNamed: MilanTrashHasItems() ? @"common_RecyclerFull" : @"common_RecyclerEmpty"];
			if (ti) return ti;
		}
		return [MilanIcons imageNamed: [f objectAtIndex: 2]];
	}
	return [f objectAtIndex: 0];
}

- (void) tableViewSelectionDidChange: (NSNotification *)n
{
	NSInteger r = [sidebarTable selectedRow];
	if (r >= 0 && !syncingSidebar) [self goTo: [[favorites objectAtIndex: r] objectAtIndex: 1]];
}

- (void) syncSidebar
{
	NSUInteger i;
	NSInteger row = -1;
	for (i = 0; i < [favorites count]; i++)
		if ([[[favorites objectAtIndex: i] objectAtIndex: 1] isEqualToString: path]) row = i;
	syncingSidebar = YES;
	if (row >= 0) [sidebarTable selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
	else [sidebarTable deselectAll: nil];
	syncingSidebar = NO;
}

/* ---- loading ---- */

- (void) load: (BOOL)navigate
{
	unsigned g = ++gen;
	[MilanEntry loadPath: path showHidden: showHidden sort: sortKey ascending: ascending
	          completion: ^(NSArray *e, NSString *err) {
			if (g != gen) return;
		[entries release];
		entries = [(e ? e : [NSArray array]) retain];
		if (desktop && !err) { NSArray *x = [[entries arrayByAddingObjectsFromArray: [self desktopExtras]] retain]; [entries release]; entries = x; }
		if (navigate) [cur setPath: path entries: entries];
		else [cur reloadEntries: entries];
		if (err) [status setStringValue: err];
		else [self contentSelectionChanged];
		[sidebarTable reloadData];
		[self syncSidebar];
	}];
}

/* Trash and mounted volumes, shown on the desktop after the folder's own items */
- (NSArray *) desktopExtras
{
	NSMutableArray *x = [NSMutableArray array];
	MilanEntry *t = [[[MilanEntry alloc] init] autorelease];
	struct statfs *fs = NULL;
	int n = getfsstat(NULL, 0, MNT_NOWAIT), i;
	t->name = [@"Trash" retain]; t->path = [MilanTrashPath retain]; t->isDir = YES; t->mode = S_IFDIR | 0755;
	t->kind = [@"Trash" retain];
	[x addObject: t];
	if (n > 0 && (fs = calloc((size_t)n, sizeof *fs))) n = getfsstat(fs, (int)(n * sizeof *fs), MNT_NOWAIT); else n = 0;
	for (i = 0; i < n; i++) {
		NSString *m = [NSString stringWithUTF8String: fs[i].f_mntonname];
		MilanEntry *v;
		if (!([m hasPrefix: @"/Volumes/"] || [m hasPrefix: @"/mnt/"] || [m hasPrefix: @"/media/"])) continue;
		if ((v = [MilanEntry entryForPath: m])) { v->isVolume = YES; [x addObject: v]; }
	}
	free(fs);
	return x;
}

- (void) contentLoadPath: (NSString *)p completion: (void (^)(NSArray *))done
{
	[MilanEntry loadPath: p showHidden: showHidden sort: sortKey ascending: ascending
	          completion: ^(NSArray *e, NSString *err) { done(e); }];
}

/* Like Finder: a drag to another volume copies, a drag within a volume moves. */
- (BOOL) crossesVolumes: (NSArray *)paths to: (NSString *)dest
{
	struct stat d, f;
	NSString *p;
	if (stat([dest fileSystemRepresentation], &d) != 0) return NO;
	for (p in paths)
		if (lstat([p fileSystemRepresentation], &f) == 0 && f.st_dev != d.st_dev) return YES;
	return NO;
}

- (void) contentDropPaths: (NSArray *)paths onto: (NSString *)folder copy: (BOOL)copy
{
	NSString *dest = folder ? folder : [self currentPath];
	MilanOpDone done = ^(NSString *e) { [self report: e]; [self load: NO]; };
	if ([dest isEqualToString: MilanTrashPath]) [MilanTrash trashPaths: paths done: done];	/* dropped on the Trash */
	else if (MilanPathInTrash(dest)) { NSBeep(); }	/* nothing is copied or moved into a Trash folder by hand */
	else if (copy || [self crossesVolumes: paths to: dest]) [MilanFileOps copyPaths: paths toDir: dest done: done];
	else [MilanFileOps movePaths: paths toDir: dest done: done];
}

- (void) contentSortBy: (MilanSort)key
{
	if (key == sortKey) ascending = !ascending; else { sortKey = key; ascending = YES; }
	if ([views[1] respondsToSelector: @selector(setSortKey:ascending:)]) [(id)views[1] setSortKey: sortKey ascending: ascending];
	[self load: NO];
}

/* kqueue-backed live refresh of the directory being browsed */
- (void) stopWatching
{
	if (watch) { dispatch_source_cancel((dispatch_source_t)watch); dispatch_release((dispatch_source_t)watch); watch = NULL; }
}

- (void) watchPath
{
	int fd;
	dispatch_source_t src;
	[self stopWatching];
	/* the merged Trash watches the home trash; the others reload after their own operations */
	fd = open([([path isEqualToString: MilanTrashPath] ? [[MilanTrash trashDirectories] objectAtIndex: 0] : path) fileSystemRepresentation], O_EVTONLY);
	if (fd < 0) return;
	/* the source lives on a global queue and hops to the main thread: main-queue sources do not wake
	 * GNUstep's run loop */
	src = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd,
	    DISPATCH_VNODE_WRITE | DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_EXTEND,
	    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
	dispatch_source_set_event_handler(src, ^{
		MilanRunOnMain(^{
			if (reloadPending) return;
			reloadPending = YES;
			[self runLater: ^{ reloadPending = NO; [self load: NO]; } after: 0.15];
		});
	});
	dispatch_source_set_cancel_handler(src, ^{ close(fd); });
	dispatch_resume(src);
	watch = src;
}

/* ---- view modes ---- */

- (void) switchToMode: (int)m
{
	NSView *v;
	if (desktop) return;	/* the desktop is always the icon view */
	mode = m;
	[modeSeg setSelectedSegment: m];
	for (v in [[[host subviews] copy] autorelease]) [v removeFromSuperview];
	cur = views[m];
	[[cur view] setFrame: [host bounds]];
	[host addSubview: [cur view]];
	if (entries) [cur setPath: path entries: entries];
	[window makeFirstResponder: [cur view] == nil ? nil : ([[cur view] isKindOfClass: [NSScrollView class]] ? [(NSScrollView *)[cur view] documentView] : [cur view])];
}

- (void) setMode: (int)m { if (m >= 0 && m < 3) [self switchToMode: m]; }
- (void) setViewMode: (id)s { [self switchToMode: (int)[modeSeg selectedSegment]]; }
- (void) viewAsIcons: (id)s { [self switchToMode: 0]; }
- (void) viewAsList: (id)s { [self switchToMode: 1]; }
- (void) viewAsColumns: (id)s { [self switchToMode: 2]; }
- (void) toggleHidden: (id)s { showHidden = !showHidden; [self load: NO]; }

/* ---- content delegate ---- */

- (void) contentSelectionChanged
{
	NSArray *s = [cur selectedEntries];
	NSUInteger n = [s count];
	if (n == 1) {
		MilanEntry *e = [s objectAtIndex: 0];
		[status setStringValue: [NSString stringWithFormat: @"%@ – %@", e->name, e->isDir ? [e kind] : [e sizeString]]];
	} else if (n)
		[status setStringValue: [NSString stringWithFormat: @"%lu of %lu selected", (unsigned long)n, (unsigned long)[entries count]]];
	else
		[status setStringValue: [NSString stringWithFormat: @"%lu items", (unsigned long)[entries count]]];
}

/* Nothing in a Trash is opened or run: only folders may be browsed. Every open path goes through here. */
- (BOOL) openAllowedFor: (NSArray *)sel
{
	MilanEntry *e;
	for (e in sel)
		if (MilanPathInTrash(e->path) && !(e->isDir && !e->isApp)) return NO;
	return YES;
}

- (void) contentOpen: (NSArray *)sel
{
	MilanEntry *e;
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	if (![self openAllowedFor: sel]) {
		NSBeep();
		[status setStringValue: @"Items in the Trash can't be opened. Put Back first."];
		return;
	}
	if ([sel count] == 1) {
		e = [sel objectAtIndex: 0];
		if (e->isDir && !e->isApp) {
			if (desktop) [[NSApp delegate] performSelector: @selector(openWindowAtPath:) withObject: e->path];
			else [self goTo: e->path];
			return;
		}
	}
	for (e in sel) {
		if (MilanPathInTrash(e->path)) continue;	/* belt and braces: never launch or open from a Trash */
		if (e->isApp) [ws launchApplication: e->path];
		else if (e->isDir) { [[NSApp delegate] performSelector: @selector(openWindowAtPath:) withObject: e->path]; }
		else [ws openFile: e->path];
	}
}

- (void) openSelection: (id)s { NSArray *a = [cur selectedEntries]; if ([a count]) [self contentOpen: a]; }

- (void) getInfo: (id)s
{
	MilanEntry *e;
	NSArray *a = [cur selectedEntries];
	if (![a count]) { [MilanInfoPanel showForPath: [cur browsedPath] ? [cur browsedPath] : path]; return; }
	for (e in a) [MilanInfoPanel showForPath: e->path];
}

/* ---- context menu ---- */

- (void) buildContextMenu
{
	const struct { const char *title; SEL action; } items[] = {
		{ "Open", @selector(openSelection:) }, { "Get Info", @selector(getInfo:) },
		{ "Set as Desktop Picture", @selector(setDesktopPicture:) },
		{ "Rename\xe2\x80\xa6", @selector(renameSelection:) }, { "Put Back", @selector(putBack:) },
		{ NULL, NULL },
		{ "Cut", @selector(cutFiles:) }, { "Copy", @selector(copyFiles:) }, { "Paste", @selector(pasteFiles:) },
		{ NULL, NULL },
		{ "Move to Trash", @selector(trashSelection:) }, { "New Folder", @selector(newFolder:) },
	};
	unsigned i;
	ctxMenu = [[NSMenu alloc] initWithTitle: @""];
	for (i = 0; i < sizeof items / sizeof items[0]; i++) {
		NSMenuItem *it;
		if (!items[i].title) { [ctxMenu addItem: [NSMenuItem separatorItem]]; continue; }
		it = (NSMenuItem *)[ctxMenu addItemWithTitle: [NSString stringWithUTF8String: items[i].title]
		                                      action: items[i].action keyEquivalent: @""];
		[it setTarget: self];
	}
}

- (NSMenu *) contentMenu
{
	if (![[cur selectedEntries] count]) {
		if (!blankMenu) {
			/* right-click on bare background: folder actions, plus Change Background on the desktop */
			blankMenu = [[NSMenu alloc] initWithTitle: @""];
			[[blankMenu addItemWithTitle: @"New Folder" action: @selector(newFolder:) keyEquivalent: @""] setTarget: self];
			[[blankMenu addItemWithTitle: @"Paste" action: @selector(pasteFiles:) keyEquivalent: @""] setTarget: self];
			[[blankMenu addItemWithTitle: @"Get Info" action: @selector(getInfo:) keyEquivalent: @""] setTarget: self];
			if (desktop) {
				[blankMenu addItem: [NSMenuItem separatorItem]];
				[[blankMenu addItemWithTitle: @"Change Background\u2026" action: @selector(changeBackground:) keyEquivalent: @""] setTarget: self];
			}
		}
		return blankMenu;
	}
	return ctxMenu;
}

- (void) changeBackground: (id)s { [MilanWallpaperPanel show]; }

/* PNG and TIFF only: GNUstep's gui here links libpng and libtiff, not libjpeg */
static BOOL
isPicture(MilanEntry *e)
{
	NSString *x = [[e->name pathExtension] lowercaseString];
	return !e->isDir && ([x isEqualToString: @"png"] || [x isEqualToString: @"tif"] || [x isEqualToString: @"tiff"]);
}

- (void) setDesktopPicture: (id)s
{
	MilanEntry *e = [[cur selectedEntries] count] == 1 ? [[cur selectedEntries] objectAtIndex: 0] : nil;
	MilanWallpaper *w = [MilanWallpaper shared];
	if (e && isPicture(e)) [w setImagePath: e->path fill: [w fill] color: [w color]];
}

- (BOOL) validateMenuItem: (NSMenuItem *)item
{
	SEL a = [item action];
	BOOL has = [[cur selectedEntries] count] > 0, inTrash = MilanPathInTrash([self currentPath]);
	if (a == @selector(changeBackground:)) return YES;
	if (a == @selector(setDesktopPicture:)) return [[cur selectedEntries] count] == 1 && isPicture([[cur selectedEntries] objectAtIndex: 0]);
	if (a == @selector(putBack:)) return inTrash && has;
	if (a == @selector(emptyTrash:)) return YES;
	if (inTrash && (a == @selector(newFolder:) || a == @selector(pasteFiles:) || a == @selector(renameSelection:)
	                || a == @selector(trashSelection:)))
		return NO;
	if (inTrash && a == @selector(openSelection:)) return has && [self openAllowedFor: [cur selectedEntries]];
	if (a == @selector(openSelection:) || a == @selector(copyFiles:) || a == @selector(cutFiles:)
	    || a == @selector(trashSelection:) || a == @selector(getInfo:))
		return has || a == @selector(getInfo:);
	if (a == @selector(renameSelection:)) return [[cur selectedEntries] count] == 1;
	if (a == @selector(pasteFiles:))
		return [[[NSPasteboard generalPasteboard] propertyListForType: NSFilenamesPboardType] count] > 0;
	if (a == @selector(goBack:)) return hIndex > 0;
	if (a == @selector(goForward:)) return hIndex + 1 < (NSInteger)[history count];
	if (a == @selector(toggleHidden:)) [item setState: showHidden ? NSOnState : NSOffState];
	return YES;
}

/* ---- file operations ---- */

- (NSArray *) selectedPaths
{
	NSMutableArray *p = [NSMutableArray array];
	MilanEntry *e;
	for (e in [cur selectedEntries]) [p addObject: e->path];
	return p;
}

- (void) report: (NSString *)err
{
	if (err) NSRunAlertPanel(@"Milan", @"%@", @"OK", nil, nil, err);
}

- (void) putOnPasteboard: (BOOL)cut
{
	NSArray *p = [self selectedPaths];
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	if (![p count]) return;
	[pb declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] owner: nil];
	[pb setPropertyList: p forType: NSFilenamesPboardType];
	[clipPaths release]; clipPaths = [p retain];
	clipCut = cut;
	clipChange = [pb changeCount];
}

- (void) copyFiles: (id)s { [self putOnPasteboard: NO]; }
- (void) cutFiles: (id)s { [self putOnPasteboard: YES]; }

- (void) pasteFiles: (id)s
{
	if (MilanPathInTrash([self currentPath])) { NSBeep(); return; }
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSArray *p = [pb propertyListForType: NSFilenamesPboardType];
	NSString *dest = [cur browsedPath] ? [cur browsedPath] : path;
	BOOL move = clipCut && clipChange == [pb changeCount];
	if (![p count]) return;
	if (move) {
		[MilanFileOps movePaths: p toDir: dest done: ^(NSString *e) { [self report: e]; [self load: NO]; }];
		[clipPaths release]; clipPaths = nil; clipCut = NO;
	} else
		[MilanFileOps copyPaths: p toDir: dest done: ^(NSString *e) { [self report: e]; [self load: NO]; }];
}

- (void) trashSelection: (id)s
{
	NSArray *p = [self selectedPaths];
	if ([p count])
		[MilanTrash trashPaths: p done: ^(NSString *e) { [self report: e]; [self load: NO]; }];
}

- (void) newFolder: (id)s
{
	if (MilanPathInTrash([self currentPath])) { NSBeep(); return; }
	[MilanFileOps newFolderIn: [cur browsedPath] ? [cur browsedPath] : path
	                     done: ^(NSString *made, NSString *e) {
		[self report: e];
		[self load: NO];
		if (made) [self performSelector: @selector(selectAndRename:) withObject: [[made copy] autorelease] afterDelay: 0.25];
	}];
}

- (void) selectAndRename: (NSString *)p { [cur selectPath: p]; [self renameSelection: nil]; }

- (void) renameSelection: (id)s
{
	NSArray *a = [cur selectedEntries];
	MilanEntry *e;
	NSPanel *pn;
	NSTextField *tf;
	NSButton *ok, *cancel;
	NSInteger r;
	if ([a count] != 1) return;
	e = [a objectAtIndex: 0];
	pn = [[[NSPanel alloc] initWithContentRect: NSMakeRect(0, 0, 320, 90)
	    styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: NO] autorelease];
	[pn setTitle: @"Rename"];
	tf = [[[NSTextField alloc] initWithFrame: NSMakeRect(16, 48, 288, 22)] autorelease];
	[tf setStringValue: e->name];
	ok = barButton(@"Rename", NSMakeRect(224, 12, 80, 26), NSApp, @selector(stopModalWithCode:), nil);
	cancel = barButton(@"Cancel", NSMakeRect(136, 12, 80, 26), NSApp, @selector(stopModalWithCode:), nil);
	[ok setTag: 1]; [cancel setTag: 0];
	[ok setTarget: self]; [ok setAction: @selector(modalButton:)];
	[cancel setTarget: self]; [cancel setAction: @selector(modalButton:)];
	[ok setKeyEquivalent: @"\r"];
	[[pn contentView] addSubview: tf]; [[pn contentView] addSubview: ok]; [[pn contentView] addSubview: cancel];
	[pn center];
	[pn makeFirstResponder: tf];
	r = [NSApp runModalForWindow: pn];
	[pn orderOut: nil];
	if (r == 1 && [[tf stringValue] length] && ![[tf stringValue] isEqualToString: e->name]
	    && [[tf stringValue] rangeOfString: @"/"].location == NSNotFound)
		[MilanFileOps renamePath: e->path to: [tf stringValue] done: ^(NSString *err) { [self report: err]; [self load: NO]; }];
}

- (void) modalButton: (id)b { [NSApp stopModalWithCode: [b tag]]; }
- (void) putBack: (id)s
{
	NSArray *p = [self selectedPaths];
	if ([p count])
		[MilanTrash putBackPaths: p done: ^(NSString *e) { [self report: e]; [self load: NO]; }];
}

- (void) emptyTrashNoConfirm
{
	[MilanTrash emptyDone: ^(NSString *e) { [self report: e]; [self load: NO]; }];
}

- (void) emptyTrash: (id)s
{
	if (NSRunAlertPanel(@"Empty the Trash?", @"All items in the Trash will be permanently deleted. This cannot be undone.",
	                    @"Empty Trash", @"Cancel", nil) != NSAlertDefaultReturn) return;
	[MilanTrash emptyDone: ^(NSString *e) { [self report: e]; [self load: NO]; }];
}

- (void) selectAllItems: (id)s { [cur selectAll]; }

/* ---- self test (-MilanSelfTest YES): drives the real actions on a scratch tree and logs PASS/FAIL ---- */

static void
check(BOOL ok, NSString *what)
{
	NSLog(@"SELFTEST %@: %@", ok ? @"PASS" : @"FAIL", what);
}

static BOOL
exists(NSString *p)
{
	struct stat st;
	return lstat([p fileSystemRepresentation], &st) == 0;
}

- (void) runLater: (void (^)(void))b after: (NSTimeInterval)t
{
	[self performSelector: @selector(runBlock:) withObject: [[b copy] autorelease] afterDelay: t];
}

- (void) runBlock: (void (^)(void))b { b(); }

- (void) runSelfTest
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *root = @"/tmp/milan-test", *trashHome = @"/tmp/milan-test-trash", *trashed = [trashHome stringByAppendingPathComponent: @"z.txt"];
	NSArray *steps;
	NSUInteger i;
	[fm removeItemAtPath: root error: NULL];
	[fm removeItemAtPath: trashHome error: NULL];
	MilanSetTrashHome(trashHome);
	[fm createDirectoryAtPath: [root stringByAppendingPathComponent: @"sub"] withIntermediateDirectories: YES attributes: nil error: NULL];
	[@"hello" writeToFile: [root stringByAppendingPathComponent: @"a.txt"] atomically: YES encoding: NSUTF8StringEncoding error: NULL];
	[@"int x;" writeToFile: [root stringByAppendingPathComponent: @"b.c"] atomically: YES encoding: NSUTF8StringEncoding error: NULL];
	[self goTo: root];
	steps = [NSArray arrayWithObjects:
	    ^{ [self switchToMode: 2]; [cur selectPath: [root stringByAppendingPathComponent: @"sub"]]; },
	    ^{ check([[cur browsedPath] isEqualToString: [root stringByAppendingPathComponent: @"sub"]], @"columns: selecting a folder opens it"); [self switchToMode: 1]; [self goTo: root]; },
	    ^{ [cur selectPath: [root stringByAppendingPathComponent: @"a.txt"]]; check([[cur selectedEntries] count] == 1, @"list: select a.txt"); [self copyFiles: nil]; [self pasteFiles: nil]; },
	    ^{ check(exists([root stringByAppendingPathComponent: @"a copy.txt"]), @"copy+paste makes 'a copy.txt'"); [cur selectPath: [root stringByAppendingPathComponent: @"b.c"]]; [self cutFiles: nil]; [self goTo: [root stringByAppendingPathComponent: @"sub"]]; },
	    ^{ [self pasteFiles: nil]; },
	    ^{ check(exists([root stringByAppendingPathComponent: @"sub/b.c"]) && !exists([root stringByAppendingPathComponent: @"b.c"]), @"cut+paste moves b.c into sub"); [self goTo: root]; },
	    ^{ [MilanFileOps renamePath: [root stringByAppendingPathComponent: @"a.txt"] to: @"z.txt" done: ^(NSString *e) { check(!e && exists([root stringByAppendingPathComponent: @"z.txt"]), @"rename a.txt -> z.txt"); }]; },
	    ^{ [cur selectPath: [root stringByAppendingPathComponent: @"z.txt"]]; check([[cur selectedEntries] count] == 1, @"select z.txt after rename (live refresh)"); [self getInfo: nil]; [self trashSelection: nil]; },
	    ^{ check(exists(trashed) && !exists([root stringByAppendingPathComponent: @"z.txt"]), @"trash moves z.txt to the (scratch) Trash"); [MilanFileOps newFolderIn: root done: ^(NSString *m, NSString *e) { check(m != nil, @"new folder"); }]; },
	    ^{ [self goTo: MilanTrashPath]; },
	    ^{ NSArray *e = [cur selectedEntries]; (void)e; [cur selectAll]; check([[cur selectedEntries] count] == 1 && [[cur browsedPath] isEqualToString: MilanTrashPath], @"merged Trash lists the trashed z.txt"); check(![self openAllowedFor: [cur selectedEntries]], @"open/execute from the Trash is refused"); [self contentOpen: [cur selectedEntries]]; [self putBack: nil]; },
	    ^{ check(exists([root stringByAppendingPathComponent: @"z.txt"]) && !exists([trashHome stringByAppendingPathComponent: @"z.txt"]), @"Put Back restores z.txt to its origin"); [self trashSelection: nil]; [cur selectPath: [root stringByAppendingPathComponent: @"z.txt"]]; [self trashSelection: nil]; },
	    ^{ [self emptyTrashNoConfirm]; },
	    ^{ NSArray *left = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: trashHome error: NULL]; check([left count] == 0, @"Empty Trash leaves the trash empty"); MilanSetTrashHome(nil); },
	    ^{ [self goTo: root]; [self switchToMode: 0]; },
	    ^{ [cur selectAll]; check([[cur selectedEntries] count] >= 3, @"icons: select all"); },
	    ^{ [self switchToMode: 1]; [self goTo: root]; },
	    ^{ [self contentDropPaths: [NSArray arrayWithObject: [root stringByAppendingPathComponent: @"a copy.txt"]] onto: [root stringByAppendingPathComponent: @"sub"] copy: NO]; },
	    ^{ check(exists([root stringByAppendingPathComponent: @"sub/a copy.txt"]) && !exists([root stringByAppendingPathComponent: @"a copy.txt"]), @"drop moves 'a copy.txt' onto folder sub"); [self contentDropPaths: [NSArray arrayWithObject: [root stringByAppendingPathComponent: @"sub/a copy.txt"]] onto: nil copy: YES]; },
	    ^{ check(exists([root stringByAppendingPathComponent: @"a copy.txt"]) && exists([root stringByAppendingPathComponent: @"sub/a copy.txt"]), @"drop with copy onto browsed folder"); },
	    ^{ NSLog(@"SELFTEST done"); },
	    nil];
	for (i = 0; i < [steps count]; i++) {
		void (^b)(void) = [steps objectAtIndex: i];
		[self runLater: b after: (i + 1) * 4.0];
	}
}

/* ---- window ---- */

/* ---- remembered window geometry, per folder ---- */

static NSString *const kFrames = @"MilanWindowFrames", *kFrameOrder = @"MilanWindowFrameOrder";

+ (NSValue *) savedFrameForPath: (NSString *)p
{
	NSString *s = [[[NSUserDefaults standardUserDefaults] dictionaryForKey: kFrames] objectForKey: p];
	NSArray *f = [s componentsSeparatedByString: @" "];
	NSRect r, scr = [[NSScreen mainScreen] frame];
	if ([f count] != 4) return nil;
	r = NSMakeRect([[f objectAtIndex: 0] doubleValue], [[f objectAtIndex: 1] doubleValue],
	               [[f objectAtIndex: 2] doubleValue], [[f objectAtIndex: 3] doubleValue]);
	if (r.size.width < 300 || r.size.height < 200 || !NSIntersectsRect(r, scr)) return nil;	/* off-screen or silly */
	return [NSValue valueWithRect: r];
}

/* saved under the folder the window shows now, so reopening that folder gets the same place and size */
- (void) saveFrame
{
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *m = [[[d dictionaryForKey: kFrames] mutableCopy] autorelease];
	NSMutableArray *order = [[[d arrayForKey: kFrameOrder] mutableCopy] autorelease];
	NSRect r = [window frame];
	if (desktop || !path || [path isEqualToString: MilanTrashPath]) return;
	if (!m) m = [NSMutableDictionary dictionary];
	if (!order) order = [NSMutableArray array];
	{
		/* the window manager's border shifts a reopened window by a pixel or two; only real moves are saved */
		NSValue *old = [MilanWindow savedFrameForPath: path];
		if (old) {
			NSRect o = [old rectValue];
			if (fabs(o.origin.x - r.origin.x) <= 3 && fabs(o.origin.y - r.origin.y) <= 3
			    && fabs(o.size.width - r.size.width) <= 3 && fabs(o.size.height - r.size.height) <= 3) return;
		}
	}
	[m setObject: [NSString stringWithFormat: @"%.0f %.0f %.0f %.0f", r.origin.x, r.origin.y, r.size.width, r.size.height] forKey: path];
	[order removeObject: path];
	[order addObject: path];
	while ([order count] > 150) { [m removeObjectForKey: [order objectAtIndex: 0]]; [order removeObjectAtIndex: 0]; }
	[d setObject: m forKey: kFrames];
	[d setObject: order forKey: kFrameOrder];
}

- (void) startSavingFrames { savesFrame = YES; }

- (void) saveFrameSoon
{
	if (!savesFrame) return;	/* the window manager's own placement just after opening is not the user's */
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(saveFrame) object: nil];
	[self performSelector: @selector(saveFrame) withObject: nil afterDelay: 0.5];
}

- (void) windowDidMove: (NSNotification *)n { [self saveFrameSoon]; }
- (void) windowDidResize: (NSNotification *)n { [self saveFrameSoon]; }

- (BOOL) windowShouldClose: (id)sender { return !desktop; }

- (void) windowWillClose: (NSNotification *)n
{
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(saveFrame) object: nil];
	[self saveFrame];
	[self stopWatching];
	[[NSApp delegate] performSelector: @selector(windowClosed:) withObject: self];
}

@end

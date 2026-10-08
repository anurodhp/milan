#import "MilanWindow.h"
#import "MilanIconView.h"
#import "MilanListView.h"
#import "MilanColumnView.h"
#import "MilanFileOps.h"
#import "MilanInfoPanel.h"
#import "MilanIcons.h"
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dispatch/dispatch.h>

#define BAR_H 40.0
#define STATUS_H 20.0

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

#define TRACE(s) do { if (getenv("MILAN_TRACE")) NSLog(@"milan: %s", s); } while (0)

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
	TRACE("window created");
	[window setReleasedWhenClosed: NO];
	[window setDelegate: self];
	[window setMinSize: NSMakeSize(480, 280)];
	cv = [window contentView];

	/* top panel: navigation, view mode, actions (Lucide glyphs, see tools/make_icons.sh) */
	bar = [[[NSView alloc] initWithFrame: NSMakeRect(0, NSHeight([cv bounds]) - BAR_H, NSWidth([cv bounds]), BAR_H)] autorelease];
	[bar setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
	TRACE("bar created");
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
	TRACE("segmented");
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
	TRACE("action buttons");
	[cv addSubview: bar];
	TRACE("bar added");

	host = [[[NSView alloc] initWithFrame: NSMakeRect(0, STATUS_H, NSWidth([cv bounds]), NSHeight([cv bounds]) - BAR_H - STATUS_H)] autorelease];
	[host setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[cv addSubview: host];
	status = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, NSWidth([cv bounds]), STATUS_H)] autorelease];
	[status setEditable: NO]; [status setBezeled: NO]; [status setDrawsBackground: NO];
	[status setAlignment: NSCenterTextAlignment];
	[status setFont: [NSFont systemFontOfSize: 11]];
	[status setAutoresizingMask: NSViewWidthSizable | NSViewMaxYMargin];
	[cv addSubview: status];

	TRACE("status added");
	views[0] = [[MilanIconView alloc] init];
	TRACE("icon view");
	views[1] = [[MilanListView alloc] init];
	TRACE("list view");
	views[2] = [[MilanColumnView alloc] init];
	{
		int i;
		for (i = 0; i < 3; i++) [views[i] setDelegate: self];
	}
	TRACE("views built");
	[self buildContextMenu];
	TRACE("menu built");
	[self switchToMode: 0];
	TRACE("mode switched");
	[self goTo: p];
	TRACE("went to path");
	[window makeKeyAndOrderFront: nil];
	TRACE("window ordered front");
	return self;
}

- (void) dealloc
{
	int i;
	[self stopWatching];
	for (i = 0; i < 3; i++) { [views[i] setDelegate: nil]; [(id)views[i] release]; }
	[window setDelegate: nil];
	[window release]; [path release]; [history release]; [entries release];
	[clipPaths release]; [ctxMenu release];
	[super dealloc];
}

- (NSWindow *) window { return window; }
- (NSString *) currentPath { return [cur browsedPath] ? [cur browsedPath] : (path ? path : NSHomeDirectory()); }

/* ---- navigation ---- */

- (void) goTo: (NSString *)p
{
	p = [p stringByStandardizingPath];
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
	setEnabledIcon(upBtn, ![path isEqualToString: @"/"]);
	[window setTitle: [path isEqualToString: @"/"] ? @"/" : [path lastPathComponent]];
	[window setRepresentedFilename: path];
	[self load: YES];
	[self watchPath];
}

- (void) goBack: (id)s { if (hIndex > 0) { hIndex--; [self showHistoryEntry]; } }
- (void) goForward: (id)s { if (hIndex + 1 < (NSInteger)[history count]) { hIndex++; [self showHistoryEntry]; } }
- (void) goUp: (id)s { if (![path isEqualToString: @"/"]) [self goTo: [path stringByDeletingLastPathComponent]]; }
- (void) goHome: (id)s { [self goTo: NSHomeDirectory()]; }
- (void) goApplications: (id)s { [self goTo: @"/Applications"]; }
- (void) goRoot: (id)s { [self goTo: @"/"]; }

/* ---- loading ---- */

- (void) load: (BOOL)navigate
{
	unsigned g = ++gen;
	[MilanEntry loadPath: path showHidden: showHidden sort: sortKey ascending: ascending
	          completion: ^(NSArray *e, NSString *err) {
		if (g != gen) return;
		[entries release];
		entries = [(e ? e : [NSArray array]) retain];
		if (navigate) [cur setPath: path entries: entries];
		else [cur reloadEntries: entries];
		if (err) [status setStringValue: err];
		else [self contentSelectionChanged];
	}];
}

- (void) contentLoadPath: (NSString *)p completion: (void (^)(NSArray *))done
{
	[MilanEntry loadPath: p showHidden: showHidden sort: sortKey ascending: ascending
	          completion: ^(NSArray *e, NSString *err) { done(e); }];
}

- (void) contentDropPaths: (NSArray *)paths onto: (NSString *)folder copy: (BOOL)copy
{
	NSString *dest = folder ? folder : [self currentPath];
	MilanOpDone done = ^(NSString *e) { [self report: e]; [self load: NO]; };
	if (copy) [MilanFileOps copyPaths: paths toDir: dest done: done];
	else [MilanFileOps movePaths: paths toDir: dest done: done];
}

- (void) contentSortBy: (MilanSort)key
{
	if (key == sortKey) ascending = !ascending; else { sortKey = key; ascending = YES; }
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
	fd = open([path fileSystemRepresentation], O_EVTONLY);
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

- (void) contentOpen: (NSArray *)sel
{
	MilanEntry *e;
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	if ([sel count] == 1) {
		e = [sel objectAtIndex: 0];
		if (e->isDir && !e->isApp) { [self goTo: e->path]; return; }
	}
	for (e in sel) {
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
	NSArray *t = [NSArray arrayWithObjects: @"Open", @"Get Info", @"Rename…", @"-", @"Cut", @"Copy", @"Paste",
	              @"-", @"Move to Trash", @"New Folder", nil];
	SEL sels[] = { @selector(openSelection:), @selector(getInfo:), @selector(renameSelection:), NULL,
	               @selector(cutFiles:), @selector(copyFiles:), @selector(pasteFiles:), NULL,
	               @selector(trashSelection:), @selector(newFolder:) };
	NSUInteger i;
	ctxMenu = [[NSMenu alloc] initWithTitle: @""];
	for (i = 0; i < [t count]; i++) {
		NSMenuItem *it;
		if (!sels[i]) { [ctxMenu addItem: [NSMenuItem separatorItem]]; continue; }
		it = (NSMenuItem *)[ctxMenu addItemWithTitle: [t objectAtIndex: i] action: sels[i] keyEquivalent: @""];
		[it setTarget: self];
	}
}

- (NSMenu *) contentMenu { return ctxMenu; }

- (BOOL) validateMenuItem: (NSMenuItem *)item
{
	SEL a = [item action];
	BOOL has = [[cur selectedEntries] count] > 0;
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
		[MilanFileOps trashPaths: p done: ^(NSString *e) { [self report: e]; [self load: NO]; }];
}

- (void) newFolder: (id)s
{
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
	NSString *root = @"/tmp/milan-test", *trashed = [NSHomeDirectory() stringByAppendingPathComponent: @".Trash/z.txt"];
	NSArray *steps;
	NSUInteger i;
	[fm removeItemAtPath: root error: NULL];
	[fm removeItemAtPath: trashed error: NULL];
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
	    ^{ check(exists(trashed) && !exists([root stringByAppendingPathComponent: @"z.txt"]), @"trash moves z.txt to ~/.Trash"); [MilanFileOps newFolderIn: root done: ^(NSString *m, NSString *e) { check(m != nil, @"new folder"); }]; },
	    ^{ [self switchToMode: 0]; [cur selectAll]; check([[cur selectedEntries] count] >= 3, @"icons: select all"); },
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

- (void) windowWillClose: (NSNotification *)n
{
	[self stopWatching];
	[[NSApp delegate] performSelector: @selector(windowClosed:) withObject: self];
}

@end

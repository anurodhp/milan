/*
 * milan: a small, fast Finder-style file manager for GNUstep.
 * Defaults: MilanStartPath (default $HOME) or a path as the first argument;
 * MilanViewMode 0|1|2 (icons|list|columns); MilanInfo /a:/b opens info panels;
 * MilanAbout YES shows the About panel.
 */
#import <AppKit/AppKit.h>
#import "MilanWindow.h"
#import "MilanInfoPanel.h"
#import "MilanWallpaper.h"
#import "MilanPrefs.h"
#include <execinfo.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>

/* MILAN_DEBUG=1: print a backtrace on SIGSEGV/SIGBUS (no alt stack here: sigaltstack is missing, so a stack overflow still dies silently). */
static void
crash_handler(int sig)
{
	void *bt[64];
	int n = backtrace(bt, 64);
	write(2, "milan: fatal signal, backtrace:\n", 32);
	backtrace_symbols_fd(bt, n, 2);
	_exit(128 + sig);
}

static void
install_crash_handler(void)
{
	struct sigaction sa;
	sa.sa_handler = crash_handler;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = 0;
	sigaction(SIGSEGV, &sa, NULL);
	sigaction(SIGBUS, &sa, NULL);
}

/* Exceptions raised inside the event loop are reported through an NSAlert that this theme suppresses when the
 * text is empty, which leaves a silently blank window. Log them instead. */
@interface MilanApplication : NSApplication
@end

@implementation MilanApplication
- (void) reportException: (NSException *)e
{
	NSLog(@"MILAN EXCEPTION %@: %@ %@", [e name], [e reason], [e userInfo]);
}
@end

@interface MilanApp : NSObject
{
	NSMutableArray *windows;
}
- (MilanWindow *) active;
- (void) openWindowAtPath: (NSString *)p;
- (void) windowClosed: (MilanWindow *)w;
@end

static NSMenuItem *
add_item(NSMenu *m, NSString *title, SEL action, NSString *key, id target)
{
	NSMenuItem *i = (NSMenuItem *)[m addItemWithTitle: title action: action keyEquivalent: key ? key : @""];
	[i setTarget: target];
	return i;
}

/* Menu actions go to the key window's controller. */
#define FWD(sel) - (void) sel: (id)s { [[self active] sel: s]; }

@implementation MilanApp

- (id) init
{
	self = [super init];
	windows = [[NSMutableArray alloc] init];
	return self;
}

- (MilanWindow *) active
{
	MilanWindow *w;
	for (w in windows) if ([w window] == [NSApp keyWindow]) return w;
	return [windows lastObject];
}

- (void) openWindowAtPath: (NSString *)p
{
	MilanWindow *w = [[MilanWindow alloc] initWithPath: p];
	[windows addObject: w];
	[w release];
}

- (void) runBlock: (void (^)(void))b { b(); }

- (void) later: (NSTimeInterval)t do: (void (^)(void))b
{
	[self performSelector: @selector(runBlock:) withObject: [[b copy] autorelease] afterDelay: t];
}

static void
check(BOOL ok, NSString *what)
{
	NSLog(@"MULTITEST %@: %@", ok ? @"PASS" : @"FAIL", what);
}

/* -MilanMultiTest YES: several browser windows at once, each independent */
- (void) runMultiTest
{
	__block NSArray *snapshot = nil;
	[self openWindowAtPath: @"/usr"];
	[self openWindowAtPath: @"/etc"];
	[self openWindowAtPath: @"/Applications"];
	check([windows count] == 4, @"four windows open (1 launch + 3)");
	{
		NSMutableSet *paths = [NSMutableSet set];
		MilanWindow *w;
		for (w in windows) [paths addObject: [w currentPath]];
		check([paths count] == 4, @"each window shows its own folder");
	}
	[[windows objectAtIndex: 1] setMode: 1];
	[[windows objectAtIndex: 2] setMode: 2];
	[self later: 6 do: ^{
		MilanWindow *w1 = [windows objectAtIndex: 1], *w2 = [windows objectAtIndex: 2];
		snapshot = [[windows valueForKey: @"currentPath"] copy];
		[w1 goTo: @"/usr/lib"];
		check([[w1 currentPath] isEqualToString: @"/usr/lib"] && [[w2 currentPath] isEqualToString: [snapshot objectAtIndex: 2]]
		      && [[[windows objectAtIndex: 0] currentPath] isEqualToString: [snapshot objectAtIndex: 0]],
		      @"navigating one window leaves the others alone");
		[w1 goBack: nil];
		check([[w1 currentPath] isEqualToString: [snapshot objectAtIndex: 1]], @"each window has its own back history");
	}];
	[self later: 10 do: ^{
		NSUInteger n = [windows count];
		[[(MilanWindow *)[windows objectAtIndex: 1] window] performClose: nil];
		[self later: 2 do: ^{
			check([windows count] == n - 1 && [NSApp isRunning], @"closing one window keeps the rest and the app");
			check([[windows objectAtIndex: 0] window] != nil && [[[windows lastObject] window] isVisible], @"remaining windows still visible");
			NSLog(@"MULTITEST done");
			[self runDragBetweenWindowsTest];
		}];
	}];
}

/* a drop in one window of a file that lives in another window's folder, as a drag between them delivers it */
- (void) runDragBetweenWindowsTest
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *a = @"/tmp/milan-dd/a", *b = @"/tmp/milan-dd/b", *f = @"/tmp/milan-dd/a/f.txt";
	MilanWindow *wa, *wb;
	[fm removeItemAtPath: @"/tmp/milan-dd" error: NULL];
	[fm createDirectoryAtPath: a withIntermediateDirectories: YES attributes: nil error: NULL];
	[fm createDirectoryAtPath: b withIntermediateDirectories: YES attributes: nil error: NULL];
	[@"x" writeToFile: f atomically: YES encoding: NSUTF8StringEncoding error: NULL];
	[self openWindowAtPath: a];
	wa = [windows lastObject];
	[self openWindowAtPath: b];
	wb = [windows lastObject];
	[self later: 5 do: ^{
		check([[wa valueForKey: @"entries"] count] == 1 && [[wb valueForKey: @"entries"] count] == 0, @"window A lists f.txt, window B is empty");
		[wb contentDropPaths: [NSArray arrayWithObject: f] onto: nil copy: NO];	/* dropped on B's background */
		[self later: 6 do: ^{
			check([fm fileExistsAtPath: [b stringByAppendingPathComponent: @"f.txt"]] && ![fm fileExistsAtPath: f],
			      @"dropping A's file into B moves it");
			check([[wa valueForKey: @"entries"] count] == 0 && [[wb valueForKey: @"entries"] count] == 1,
			      @"both windows refresh (A empties, B shows f.txt)");
			NSLog(@"MULTITEST drag done");
		}];
	}];
}

- (void) openDesktop
{
	MilanWindow *w = [[MilanWindow alloc] initDesktop];
	[windows addObject: w];
	[w release];
}

- (void) changeBackground: (id)s { [MilanWallpaperPanel show]; }

- (void) newWindow: (id)s { [self openWindowAtPath: [MilanPrefs newWindowPath]]; }
- (void) showPrefs: (id)s { [MilanPrefs show]; }
- (void) windowClosed: (MilanWindow *)w
{
	[[w retain] autorelease];
	[windows removeObject: w];
}

FWD(goBack) FWD(goForward) FWD(goUp) FWD(goHome) FWD(goApplications) FWD(goRoot)
FWD(viewAsIcons) FWD(viewAsList) FWD(viewAsColumns) FWD(toggleHidden)
FWD(openSelection) FWD(getInfo) FWD(copyFiles) FWD(cutFiles) FWD(pasteFiles)
FWD(putBack) FWD(emptyTrash) FWD(goTrash) FWD(trashSelection) FWD(newFolder) FWD(renameSelection) FWD(selectAllItems)

- (BOOL) validateMenuItem: (NSMenuItem *)i
{
	MilanWindow *w = [self active];
	return w ? [w validateMenuItem: i] : [i action] == @selector(newWindow:);
}

- (void) showAbout: (id)sender
{
	/* same as Rome's: the keys GNUstep's info panel reads (GSInfoPanel.m) */
	NSDictionary *opts = [NSDictionary dictionaryWithObjectsAndKeys:
	    @"Milan", @"ApplicationName",
	    @"A small, fast file manager for GNUstep.", @"ApplicationDescription",
	    @"0.4", @"ApplicationRelease",
	    [NSArray arrayWithObject: @"Anurodh Pokharel"], @"Authors",
	    @"Copyright \u00a9 2026 Anurodh Pokharel. MIT licence.", @"Copyright",
	    @"Hexley DarwinOS Mascot Copyright 2000 by Jon Hooper. All Rights Reserved. "
	    @"Toolbar and file icons are from Lucide (lucide.dev), copyright \u00a9 Lucide Contributors, ISC licence.",
	    @"CopyrightDescription",
	    nil];
	[NSApp orderFrontStandardAboutPanelWithOptions: opts];
}

- (void) buildMenus
{
	NSMenu *main = [[NSMenu alloc] initWithTitle: @"Milan"], *m;
	m = [[NSMenu alloc] initWithTitle: @"Milan"];
	add_item(m, @"About Milan", @selector(showAbout:), nil, self);
	add_item(m, @"Preferences\u2026", @selector(showPrefs:), @",", self);
	add_item(m, @"Hide Milan", @selector(hide:), @"h", NSApp);
	add_item(m, @"Quit Milan", @selector(terminate:), @"q", NSApp);
	[main setSubmenu: m forItem: add_item(main, @"Milan", NULL, nil, nil)]; [m release];

	m = [[NSMenu alloc] initWithTitle: @"File"];
	add_item(m, @"New Window", @selector(newWindow:), @"n", self);
	add_item(m, @"New Folder", @selector(newFolder:), @"N", self);
	add_item(m, @"Open", @selector(openSelection:), @"o", self);
	add_item(m, @"Get Info", @selector(getInfo:), @"i", self);
	add_item(m, @"Rename…", @selector(renameSelection:), @"", self);
	add_item(m, @"Move to Trash", @selector(trashSelection:), @"\x7f", self);
	add_item(m, @"Put Back", @selector(putBack:), @"", self);
	add_item(m, @"Empty Trash\u2026", @selector(emptyTrash:), @"", self);
	add_item(m, @"Close Window", @selector(performClose:), @"w", nil);
	[main setSubmenu: m forItem: add_item(main, @"File", NULL, nil, nil)]; [m release];

	m = [[NSMenu alloc] initWithTitle: @"Edit"];
	add_item(m, @"Cut", @selector(cutFiles:), @"x", self);
	add_item(m, @"Copy", @selector(copyFiles:), @"c", self);
	add_item(m, @"Paste", @selector(pasteFiles:), @"v", self);
	add_item(m, @"Select All", @selector(selectAllItems:), @"a", self);
	[main setSubmenu: m forItem: add_item(main, @"Edit", NULL, nil, nil)]; [m release];

	m = [[NSMenu alloc] initWithTitle: @"View"];
	add_item(m, @"as Icons", @selector(viewAsIcons:), @"1", self);
	add_item(m, @"as List", @selector(viewAsList:), @"2", self);
	add_item(m, @"as Columns", @selector(viewAsColumns:), @"3", self);
	add_item(m, @"Show Hidden Files", @selector(toggleHidden:), @"H", self);
	add_item(m, @"Change Desktop Background\u2026", @selector(changeBackground:), @"", self);
	[main setSubmenu: m forItem: add_item(main, @"View", NULL, nil, nil)]; [m release];

	m = [[NSMenu alloc] initWithTitle: @"Go"];
	add_item(m, @"Back", @selector(goBack:), @"[", self);
	add_item(m, @"Forward", @selector(goForward:), @"]", self);
	add_item(m, @"Enclosing Folder", @selector(goUp:), @"", self);
	add_item(m, @"Home", @selector(goHome:), @"", self);
	add_item(m, @"Applications", @selector(goApplications:), @"", self);
	add_item(m, @"Computer", @selector(goRoot:), @"", self);
	add_item(m, @"Trash", @selector(goTrash:), @"", self);
	[main setSubmenu: m forItem: add_item(main, @"Go", NULL, nil, nil)]; [m release];

	[NSApp setMainMenu: main];
	[main release];
}

- (void) applicationDidFinishLaunching: (NSNotification *)n
{
	NSArray *args = [[NSProcessInfo processInfo] arguments];
	NSString *start = [[NSUserDefaults standardUserDefaults] stringForKey: @"MilanStartPath"];
	BOOL dir;
	if ([args count] > 1 && [[NSFileManager defaultManager] fileExistsAtPath: [args objectAtIndex: 1] isDirectory: &dir] && dir)
		start = [args objectAtIndex: 1];
	[self buildMenus];
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"MilanDesktop"]) [self openDesktop];
	if (![[NSUserDefaults standardUserDefaults] objectForKey: @"MilanOpenBrowser"]
	    || [[NSUserDefaults standardUserDefaults] boolForKey: @"MilanOpenBrowser"])
		[self openWindowAtPath: start ? start : NSHomeDirectory()];
	{
		NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
		NSString *info;
		if ([d objectForKey: @"MilanViewMode"]) [[self active] setMode: (int)[d integerForKey: @"MilanViewMode"]];
		if ([d boolForKey: @"MilanAbout"]) [self performSelector: @selector(showAbout:) withObject: nil afterDelay: 1.0];
		if ([d boolForKey: @"MilanMultiTest"]) [self runMultiTest];
		if ([d boolForKey: @"MilanSelfTest"]) [[self active] runSelfTest];
		if ([d boolForKey: @"MilanTestWindow"])
			[self performSelector: @selector(openWindowAtPath:) withObject: @"/etc" afterDelay: 2.0];
		if ((info = [d stringForKey: @"MilanInfo"]))
			for (NSString *f in [info componentsSeparatedByString: @":"])
				[MilanInfoPanel performSelector: @selector(showForPath:) withObject: f afterDelay: 2.0];
	}
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)a { return YES; }

@end

int
main(int argc, const char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	MilanApp *delegate;
	if (getenv("MILAN_DEBUG")) install_crash_handler();
	[MilanApplication sharedApplication];
	delegate = [[MilanApp alloc] init];
	[NSApp setDelegate: delegate];
	[NSApp run];
	[pool release];
	return 0;
}

/*
 * milan: a small, fast Finder-style file manager for GNUstep.
 * Defaults: MilanStartPath (default $HOME), or a path as the first argument.
 */
#import <AppKit/AppKit.h>
#import "MilanWindow.h"

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

- (void) newWindow: (id)s { [self openWindowAtPath: [[self active] currentPath]]; }
- (void) windowClosed: (MilanWindow *)w
{
	[[w retain] autorelease];
	[windows removeObject: w];
}

FWD(goBack) FWD(goForward) FWD(goUp) FWD(goHome) FWD(goApplications) FWD(goRoot)
FWD(viewAsIcons) FWD(viewAsList) FWD(viewAsColumns) FWD(toggleHidden)
FWD(openSelection) FWD(getInfo) FWD(copyFiles) FWD(cutFiles) FWD(pasteFiles)
FWD(trashSelection) FWD(newFolder) FWD(renameSelection) FWD(selectAllItems)

- (BOOL) validateMenuItem: (NSMenuItem *)i
{
	MilanWindow *w = [self active];
	return w ? [w validateMenuItem: i] : [i action] == @selector(newWindow:);
}

- (void) showAbout: (id)sender
{
	NSDictionary *opts = [NSDictionary dictionaryWithObjectsAndKeys:
	    @"Milan", @"ApplicationName",
	    @"A small, fast file manager for GNUstep.", @"ApplicationDescription",
	    @"0.1", @"ApplicationRelease",
	    [NSArray arrayWithObject: @"Anurodh Pokharel"], @"Authors", nil];
	[NSApp orderFrontStandardAboutPanelWithOptions: opts];
}

- (void) buildMenus
{
	NSMenu *main = [[NSMenu alloc] initWithTitle: @"Milan"], *m;
	m = [[NSMenu alloc] initWithTitle: @"Milan"];
	add_item(m, @"About Milan", @selector(showAbout:), nil, self);
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
	[main setSubmenu: m forItem: add_item(main, @"View", NULL, nil, nil)]; [m release];

	m = [[NSMenu alloc] initWithTitle: @"Go"];
	add_item(m, @"Back", @selector(goBack:), @"[", self);
	add_item(m, @"Forward", @selector(goForward:), @"]", self);
	add_item(m, @"Enclosing Folder", @selector(goUp:), @"", self);
	add_item(m, @"Home", @selector(goHome:), @"", self);
	add_item(m, @"Applications", @selector(goApplications:), @"", self);
	add_item(m, @"Computer", @selector(goRoot:), @"", self);
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
	[self openWindowAtPath: start ? start : NSHomeDirectory()];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)a { return YES; }

@end

int
main(int argc, const char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	MilanApp *delegate;
	[NSApplication sharedApplication];
	delegate = [[MilanApp alloc] init];
	[NSApp setDelegate: delegate];
	[NSApp run];
	[pool release];
	return 0;
}

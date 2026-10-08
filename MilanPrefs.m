#import "MilanPrefs.h"

static NSString *const kTarget = @"MilanNewWindowTarget";	/* home | desktop | documents | computer | custom */
static NSString *const kCustom = @"MilanNewWindowPath";

static NSArray *
targets(void)
{
	return [NSArray arrayWithObjects: @"home", @"desktop", @"documents", @"computer", nil];
}

@implementation MilanPrefs

+ (NSString *) newWindowPath
{
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	NSString *t = [d stringForKey: kTarget], *p;
	NSFileManager *fm = [NSFileManager defaultManager];
	if ([t isEqualToString: @"custom"] && (p = [d stringForKey: kCustom]) && [fm fileExistsAtPath: p]) return p;
	if ([t isEqualToString: @"computer"]) return @"/";
	if ([t isEqualToString: @"desktop"] || [t isEqualToString: @"documents"]) {
		p = [NSHomeDirectory() stringByAppendingPathComponent: [t isEqualToString: @"desktop"] ? @"Desktop" : @"Documents"];
		if ([fm fileExistsAtPath: p]) return p;
	}
	return NSHomeDirectory();
}

+ (void) newWindowChanged: (NSSegmentedControl *)sc
{
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	[d setObject: [targets() objectAtIndex: (NSUInteger)[sc selectedSegment]] forKey: kTarget];
	[d synchronize];
}

static NSTextField *
label(NSString *s, NSRect r, BOOL bold)
{
	NSTextField *t = [[[NSTextField alloc] initWithFrame: r] autorelease];
	[t setStringValue: s];
	[t setEditable: NO]; [t setSelectable: NO]; [t setBezeled: NO]; [t setDrawsBackground: NO];
	[t setFont: bold ? [NSFont boldSystemFontOfSize: 12] : [NSFont systemFontOfSize: 12]];
	return t;
}

static NSButton *
checkbox(NSString *title, NSRect r, SEL action, BOOL on)
{
	NSButton *b = [[[NSButton alloc] initWithFrame: r] autorelease];
	[b setButtonType: NSSwitchButton];
	[b setTitle: title];
	[b setState: on ? NSOnState : NSOffState];
	[b setTarget: [MilanPrefs class]];
	[b setAction: action];
	return b;
}

+ (void) desktopChanged: (NSButton *)b
{
	BOOL on = [b state] == NSOnState;
	[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: on ? 1 : 0] forKey: @"MilanDesktop"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[[NSApp delegate] performSelector: @selector(setDesktopEnabled:) withObject: [NSNumber numberWithBool: on]];
}

+ (void) openBrowserChanged: (NSButton *)b
{
	[[NSUserDefaults standardUserDefaults] setObject: [NSNumber numberWithInt: [b state] == NSOnState ? 1 : 0] forKey: @"MilanOpenBrowser"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

static NSWindow *window;

+ (void) show
{
	NSView *v;
	NSSegmentedControl *seg;
	NSArray *names = [NSArray arrayWithObjects: @"Home", @"Desktop", @"Documents", @"Computer", nil];
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	NSString *cur = [d stringForKey: kTarget];
	NSUInteger i, sel = [targets() indexOfObject: cur ? cur : @"home"];
	if (window) { [window makeKeyAndOrderFront: nil]; return; }
	window = [[NSWindow alloc] initWithContentRect: NSMakeRect(300, 360, 460, 200)
	    styleMask: NSTitledWindowMask | NSClosableWindowMask backing: NSBackingStoreBuffered defer: NO];
	[window setReleasedWhenClosed: NO];
	[window setTitle: @"Milan Preferences"];
	v = [window contentView];
	[v addSubview: label(@"New windows open:", NSMakeRect(16, 152, 200, 18), YES)];
	seg = [[[NSSegmentedControl alloc] initWithFrame: NSMakeRect(16, 118, 410, 26)] autorelease];
	[seg setSegmentCount: [names count]];
	for (i = 0; i < [names count]; i++) { [seg setLabel: [names objectAtIndex: i] forSegment: i]; [seg setWidth: 100 forSegment: i]; }
	[seg setSelectedSegment: sel == NSNotFound ? 0 : (NSInteger)sel];
	[seg setTarget: self];
	[seg setAction: @selector(newWindowChanged:)];
	[v addSubview: seg];
	[v addSubview: label(@"The folder File > New Window (Command-N) shows.", NSMakeRect(16, 92, 420, 16), NO)];
	[v addSubview: label(@"Desktop:", NSMakeRect(16, 64, 200, 18), YES)];
	[v addSubview: checkbox(@"Draw the desktop (wallpaper, icons, Trash)", NSMakeRect(16, 38, 420, 20), @selector(desktopChanged:),
	                        [d boolForKey: @"MilanDesktop"])];
	[v addSubview: checkbox(@"Open a window when Milan starts", NSMakeRect(16, 12, 420, 20), @selector(openBrowserChanged:),
	                        [d objectForKey: @"MilanOpenBrowser"] ? [d boolForKey: @"MilanOpenBrowser"] : YES)];
	[window makeKeyAndOrderFront: nil];
	[window display];
}

@end

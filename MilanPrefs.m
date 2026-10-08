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

static NSWindow *window;

+ (void) show
{
	NSView *v;
	NSSegmentedControl *seg;
	NSArray *names = [NSArray arrayWithObjects: @"Home", @"Desktop", @"Documents", @"Computer", nil];
	NSString *cur = [[NSUserDefaults standardUserDefaults] stringForKey: kTarget];
	NSUInteger i, sel = [targets() indexOfObject: cur ? cur : @"home"];
	if (window) { [window makeKeyAndOrderFront: nil]; return; }
	window = [[NSWindow alloc] initWithContentRect: NSMakeRect(300, 380, 460, 130)
	    styleMask: NSTitledWindowMask | NSClosableWindowMask backing: NSBackingStoreBuffered defer: NO];
	[window setReleasedWhenClosed: NO];
	[window setTitle: @"Milan Preferences"];
	v = [window contentView];
	[v addSubview: label(@"New windows open:", NSMakeRect(16, 82, 200, 18), YES)];
	seg = [[[NSSegmentedControl alloc] initWithFrame: NSMakeRect(16, 48, 410, 26)] autorelease];
	[seg setSegmentCount: [names count]];
	for (i = 0; i < [names count]; i++) { [seg setLabel: [names objectAtIndex: i] forSegment: i]; [seg setWidth: 100 forSegment: i]; }
	[seg setSelectedSegment: sel == NSNotFound ? 0 : (NSInteger)sel];
	[seg setTarget: self];
	[seg setAction: @selector(newWindowChanged:)];
	[v addSubview: seg];
	[v addSubview: label(@"The folder File > New Window (Command-N) shows.", NSMakeRect(16, 20, 420, 16), NO)];
	[window makeKeyAndOrderFront: nil];
	[window display];
}

@end

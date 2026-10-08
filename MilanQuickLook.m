#import "MilanQuickLook.h"
#import "MilanIcons.h"
#import "MilanWallpaper.h"
#import "MilanImage.h"

#define MAX_TEXT (48 * 1024)
#define MAX_IMAGE_BYTES (24 * 1024 * 1024)

@interface MilanQLView : NSView
{
	MilanEntry *entry;
	NSImage *image;
	NSString *text;
	id <MilanQuickLookNavigator> nav;
}
- (id) initWithFrame: (NSRect)f navigator: (id <MilanQuickLookNavigator>)n;
- (void) setEntry: (MilanEntry *)e;
@end

static MilanQLView *active;
static NSResponder *previous;

static BOOL
isTextExt(NSString *x)
{
	static NSSet *s;
	if (!s) s = [[NSSet setWithObjects: @"txt", @"md", @"c", @"h", @"m", @"mm", @"cc", @"cpp", @"hpp", @"py", @"rb", @"js", @"json",
	             @"xml", @"html", @"htm", @"css", @"sh", @"conf", @"cfg", @"ini", @"log", @"csv", @"plist", @"yaml", @"yml", @"toml",
	             @"make", @"mk", @"s", @"patch", @"diff", @"rst", @"tex", @"lua", @"pl", @"go", @"rs", @"java", nil] retain];
	return [s containsObject: x];
}

@implementation MilanQLView

- (id) initWithFrame: (NSRect)f navigator: (id <MilanQuickLookNavigator>)n
{
	self = [super initWithFrame: f];
	nav = n;
	return self;
}

- (void) dealloc { [entry release]; [image release]; [text release]; [super dealloc]; }
- (BOOL) isFlipped { return YES; }
- (BOOL) acceptsFirstResponder { return YES; }

- (void) setEntry: (MilanEntry *)e
{
	NSString *x = [[e->name pathExtension] lowercaseString];
	[entry release]; entry = [e retain];
	[image release]; image = nil;
	[text release]; text = nil;
	if (!e->isDir) {
		if (MilanIsPictureExtension(x) && e->size < MAX_IMAGE_BYTES)
			image = [MilanLoadImage(e->path) retain];
		else if (isTextExt(x) || (e->size < MAX_TEXT && !(e->mode & 0111) && ![x length])) {
			NSData *d = [NSData dataWithContentsOfFile: e->path];
			if ([d length] > MAX_TEXT) d = [d subdataWithRange: NSMakeRange(0, MAX_TEXT)];
			text = [[NSString alloc] initWithData: d encoding: NSUTF8StringEncoding];
			if (!text) text = [[NSString alloc] initWithData: d encoding: NSISOLatin1StringEncoding];
		}
	}
	[self setNeedsDisplay: YES];
}

- (void) drawRect: (NSRect)dirty
{
	NSRect b = [self bounds], box = NSInsetRect(b, 36, 56);
	NSDictionary *tt = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont boldSystemFontOfSize: 13], NSFontAttributeName,
	    [NSColor whiteColor], NSForegroundColorAttributeName, nil];
	NSDictionary *st = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 11], NSFontAttributeName,
	    [NSColor colorWithCalibratedWhite: 0.75 alpha: 1], NSForegroundColorAttributeName, nil];
	NSString *title = [entry displayName], *sub;
	NSSize ts = [title sizeWithAttributes: tt];
	[[NSColor colorWithCalibratedWhite: 0.10 alpha: 1] set];
	NSRectFill(b);
	[title drawAtPoint: NSMakePoint(NSMidX(b) - ts.width / 2, 12) withAttributes: tt];
	if (image && [image size].width > 0) {
		NSSize is = [image size];
		CGFloat s = MIN(MIN(box.size.width / is.width, box.size.height / is.height), 1.0);
		NSSize d = NSMakeSize(is.width * s, is.height * s);
		NSRect r = NSMakeRect(NSMidX(box) - d.width / 2, NSMidY(box) - d.height / 2, d.width, d.height);
		[image drawInRect: r fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0 respectFlipped: YES hints: nil];
		sub = [NSString stringWithFormat: @"%.0f × %.0f – %@", is.width, is.height, MilanFormatSize(entry->size)];
	} else if (text) {
		NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
		NSDictionary *ta = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont userFixedPitchFontOfSize: 11], NSFontAttributeName,
		    [NSColor colorWithCalibratedWhite: 0.92 alpha: 1], NSForegroundColorAttributeName, ps, NSParagraphStyleAttributeName, nil];
		[ps setLineBreakMode: NSLineBreakByWordWrapping];
		[text drawInRect: box withAttributes: ta];
		sub = [NSString stringWithFormat: @"%@ – text%@", MilanFormatSize(entry->size), entry->size > MAX_TEXT ? @" (first 48 KB)" : @""];
	} else {
		NSImage *ic = [MilanIcons iconForEntry: entry];
		[ic drawInRect: NSMakeRect(NSMidX(b) - 48, NSMidY(b) - 64, 96, 96) fromRect: NSZeroRect operation: NSCompositeSourceOver
		      fraction: 1.0 respectFlipped: YES hints: nil];
		sub = [NSString stringWithFormat: @"%@ – no preview", [entry kind]];
	}
	{
		NSSize ss = [sub sizeWithAttributes: st];
		[sub drawAtPoint: NSMakePoint(NSMidX(b) - ss.width / 2, 32) withAttributes: st];
	}
	[@"Space or Esc closes   ← → browse" drawAtPoint: NSMakePoint(12, NSMaxY(b) - 20) withAttributes: st];
}

- (void) mouseDown: (NSEvent *)ev { [MilanQuickLook dismiss]; }

- (void) keyDown: (NSEvent *)ev
{
	NSString *k = [ev charactersIgnoringModifiers];
	unichar c = [k length] ? [k characterAtIndex: 0] : 0;
	MilanEntry *e;
	if (c == ' ' || c == 0x1b || c == 'q') { [MilanQuickLook dismiss]; return; }
	if (c == NSLeftArrowFunctionKey || c == NSUpArrowFunctionKey) { if ((e = [nav quickLookStep: -1])) [self setEntry: e]; return; }
	if (c == NSRightArrowFunctionKey || c == NSDownArrowFunctionKey) { if ((e = [nav quickLookStep: 1])) [self setEntry: e]; return; }
}

@end

@implementation MilanQuickLook

+ (BOOL) isActive { return active != nil; }

+ (void) dismiss
{
	NSWindow *w = [active window];
	if (!active) return;
	[active removeFromSuperview];
	active = nil;
	if (previous) [w makeFirstResponder: previous];
	previous = nil;
	[w display];
}

+ (void) showEntry: (MilanEntry *)e over: (NSView *)area navigator: (id <MilanQuickLookNavigator>)nav
{
	NSWindow *w = [area window];
	NSRect r = [[w contentView] convertRect: [area bounds] fromView: area];
	if (active) { [active setEntry: e]; return; }
	if (!e) return;
	active = [[[MilanQLView alloc] initWithFrame: r navigator: nav] autorelease];
	[active setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[active setEntry: e];
	[[w contentView] addSubview: active];
	previous = [w firstResponder];
	[w makeFirstResponder: active];
	[w display];
}

@end

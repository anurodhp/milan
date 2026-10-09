#import "MilanWallpaper.h"
#import "MilanRootPixmap.h"
#import "MilanIcons.h"
#import "MilanImage.h"

NSString *const MilanWallpaperChanged = @"MilanWallpaperChanged";

/* the formats gnustep-gui can read here: PNG, TIFF (libtiff) and JPEG (libjpeg-turbo, build_libjpeg.sh) */
BOOL
MilanIsPictureExtension(NSString *e)
{
	e = [e lowercaseString];
	return [e isEqualToString: @"png"] || [e isEqualToString: @"tif"] || [e isEqualToString: @"tiff"]
	    || [e isEqualToString: @"jpg"] || [e isEqualToString: @"jpeg"];
}

static NSString *const kPath = @"MilanWallpaperPath", *kFill = @"MilanWallpaperFill", *kColor = @"MilanWallpaperColor";

static NSColor *
defaultColor(void)
{
	return [NSColor colorWithCalibratedRed: 0.32 green: 0.31 blue: 0.43 alpha: 1];
}

@implementation MilanWallpaper

+ (MilanWallpaper *) shared
{
	static MilanWallpaper *w;
	if (!w) w = [[MilanWallpaper alloc] init];
	return w;
}

- (id) init
{
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	NSArray *c = [d arrayForKey: kColor];
	NSString *p = [d stringForKey: kPath];
	self = [super init];
	if ([c count] == 3)
		color = [[NSColor colorWithCalibratedRed: [[c objectAtIndex: 0] floatValue] green: [[c objectAtIndex: 1] floatValue]
		                                    blue: [[c objectAtIndex: 2] floatValue] alpha: 1] retain];
	else
		color = [defaultColor() retain];
	fill = [d objectForKey: kFill] ? (MilanFill)[d integerForKey: kFill] : MilanFillFill;
	if (p) imagePath = [p copy];
	else if (![d objectForKey: kColor]) {
		NSString *dp = [[NSBundle mainBundle] pathForResource: @"wp-aurora" ofType: @"png"];	/* the first run's picture */
		if (dp) imagePath = [dp copy];
	}
	return self;
}

- (NSString *) imagePath { return imagePath; }
- (NSColor *) color { return color; }
- (MilanFill) fill { return fill; }

- (void) setImagePath: (NSString *)p fill: (MilanFill)f color: (NSColor *)c
{
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	NSColor *rgb = [c colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
	[imagePath release]; imagePath = [p copy];
	[color release]; color = [c retain];
	fill = f;
	[cache release]; cache = nil;
	if (p) [d setObject: p forKey: kPath]; else [d setObject: @"" forKey: kPath];
	[d setInteger: f forKey: kFill];
	if (rgb)
		[d setObject: [NSArray arrayWithObjects: [NSNumber numberWithFloat: [rgb redComponent]],
		               [NSNumber numberWithFloat: [rgb greenComponent]], [NSNumber numberWithFloat: [rgb blueComponent]], nil]
		      forKey: kColor];
	[d synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName: MilanWallpaperChanged object: self];
}

/* Places the picture on a canvas the size of the desktop once, so redraws are one blit. */
- (NSImage *) canvasOfSize: (NSSize)size
{
	NSImage *pic, *canvas;
	NSSize ps;
	NSRect dst;
	if (cache && NSEqualSizes(cacheSize, size)) return cache;
	[cache release]; cache = nil;
	canvas = [[NSImage alloc] initWithSize: size];
	[canvas lockFocus];
	[color set];
	NSRectFill(NSMakeRect(0, 0, size.width, size.height));
	pic = [imagePath length] ? MilanLoadImage(imagePath) : nil;
	if (pic && [pic size].width > 0 && [pic size].height > 0) {
		CGFloat sx, sy, s;
		ps = [pic size];
		sx = size.width / ps.width; sy = size.height / ps.height;
		switch (fill) {
		case MilanFillStretch: dst = NSMakeRect(0, 0, size.width, size.height); break;
		case MilanFillFit: s = MIN(sx, sy); dst = NSMakeRect((size.width - ps.width * s) / 2, (size.height - ps.height * s) / 2, ps.width * s, ps.height * s); break;
		case MilanFillCenter: dst = NSMakeRect((size.width - ps.width) / 2, (size.height - ps.height) / 2, ps.width, ps.height); break;
		case MilanFillTile: dst = NSZeroRect; break;
		default: s = MAX(sx, sy); dst = NSMakeRect((size.width - ps.width * s) / 2, (size.height - ps.height * s) / 2, ps.width * s, ps.height * s); break;
		}
		if (fill == MilanFillTile) {
			CGFloat x, y;
			for (y = 0; y < size.height; y += ps.height)
				for (x = 0; x < size.width; x += ps.width)
					[pic drawAtPoint: NSMakePoint(x, y) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
		} else
			[pic drawInRect: dst fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
	}
	[canvas unlockFocus];
	cache = canvas;
	cacheSize = size;
	MilanPublishRootPixmap(canvas, size);	/* so translucent bars can blend over the wallpaper */
	return cache;
}

- (void) drawDirty: (NSRect)dirty ofSize: (NSSize)size
{
	NSImage *c = [self canvasOfSize: size];
	[c drawAtPoint: dirty.origin fromRect: dirty operation: NSCompositeCopy fraction: 1.0];
}

+ (NSArray *) availablePictures
{
	NSMutableArray *out = [NSMutableArray array];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *dir = [[NSBundle mainBundle] resourcePath], *n, *pics;
	for (n in [[fm contentsOfDirectoryAtPath: dir error: NULL] sortedArrayUsingSelector: @selector(compare:)])
		if ([n hasPrefix: @"wp-"] && [n hasSuffix: @".png"]) [out addObject: [dir stringByAppendingPathComponent: n]];
	pics = [NSHomeDirectory() stringByAppendingPathComponent: @"Pictures"];
	for (n in [[fm contentsOfDirectoryAtPath: pics error: NULL] sortedArrayUsingSelector: @selector(compare:)]) {
		NSString *e = [[n pathExtension] lowercaseString];
		if (MilanIsPictureExtension(e)) [out addObject: [pics stringByAppendingPathComponent: n]];
	}
	return out;
}

@end

/* ---- the desktop's own view ---- */

@implementation MilanDesktopView

- (id) initWithFrame: (NSRect)f
{
	self = [super initWithFrame: f];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(changed:)
	    name: MilanWallpaperChanged object: nil];
	return self;
}

- (void) dealloc { [[NSNotificationCenter defaultCenter] removeObserver: self]; [super dealloc]; }
- (BOOL) isOpaque { return YES; }
- (void) changed: (NSNotification *)n { [self setNeedsDisplay: YES]; }

- (void) drawRect: (NSRect)dirty
{
	[[MilanWallpaper shared] drawDirty: dirty ofSize: [self bounds].size];
}

/* a click on bare wallpaper clears the icon selection (the grid covers most of the view) */
- (void) mouseDown: (NSEvent *)ev {}

@end

/* ---- the Desktop Background panel ---- */

#define THUMB_W 128.0
#define THUMB_H 82.0
#define THUMB_GAP 12.0

@interface MilanThumbView : NSView
{
	NSArray *pictures;	/* nil entry (index 0) = no picture */
	NSMutableDictionary *thumbs;
}
- (void) reload;
@end

@implementation MilanThumbView

- (id) initWithFrame: (NSRect)f
{
	self = [super initWithFrame: f];
	thumbs = [[NSMutableDictionary alloc] init];
	[self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
	[self reload];
	return self;
}

- (void) dealloc { [pictures release]; [thumbs release]; [super dealloc]; }
- (BOOL) isFlipped { return YES; }

- (NSInteger) perRow { return MAX(1, (NSInteger)((NSWidth([self bounds]) - THUMB_GAP) / (THUMB_W + THUMB_GAP))); }

- (NSRect) rectForIndex: (NSInteger)i
{
	NSInteger per = [self perRow];
	return NSMakeRect(THUMB_GAP + (i % per) * (THUMB_W + THUMB_GAP), THUMB_GAP + (i / per) * (THUMB_H + 24), THUMB_W, THUMB_H);
}

- (void) reload
{
	[pictures release];
	pictures = [[MilanWallpaper availablePictures] retain];
	[self setFrameSize: NSMakeSize(NSWidth([self frame]), THUMB_GAP + (([pictures count] + 1 + [self perRow] - 1) / [self perRow]) * (THUMB_H + 24))];
	[self setNeedsDisplay: YES];
}

- (NSImage *) thumbFor: (NSString *)p
{
	NSImage *t = [thumbs objectForKey: p], *src;
	if (t) return t;
	src = MilanLoadImage(p);
	if (!src) return nil;
	t = [[[NSImage alloc] initWithSize: NSMakeSize(THUMB_W, THUMB_H)] autorelease];
	[t lockFocus];
	[src drawInRect: NSMakeRect(0, 0, THUMB_W, THUMB_H) fromRect: NSZeroRect operation: NSCompositeCopy fraction: 1.0];
	[t unlockFocus];
	[thumbs setObject: t forKey: p];
	return t;
}

- (void) drawRect: (NSRect)dirty
{
	NSInteger i, n = [pictures count] + 1;
	NSString *cur = [[MilanWallpaper shared] imagePath];
	NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 10], NSFontAttributeName,
	    [NSColor controlTextColor], NSForegroundColorAttributeName, nil];
	[[NSColor controlBackgroundColor] set];
	NSRectFill(dirty);
	for (i = 0; i < n; i++) {
		NSRect r = [self rectForIndex: i];
		NSString *p = i == 0 ? nil : [pictures objectAtIndex: i - 1];
		BOOL on = i == 0 ? ![cur length] : [p isEqualToString: cur];
		NSImage *t = p ? [self thumbFor: p] : nil;
		if (on) {
			[[NSColor selectedMenuItemColor] set];
			[[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, -4, -4) xRadius: 5 yRadius: 5] fill];
		}
		if (t) [t drawAtPoint: r.origin fromRect: NSZeroRect operation: NSCompositeCopy fraction: 1.0];
		else {
			[[[MilanWallpaper shared] color] set];
			NSRectFill(r);
		}
		[[NSColor colorWithCalibratedWhite: 0.5 alpha: 1] set];
		NSFrameRect(r);
		[(p ? [[p lastPathComponent] stringByDeletingPathExtension] : @"Solid colour") drawInRect: NSMakeRect(r.origin.x, NSMaxY(r) + 3, r.size.width, 14) withAttributes: a];
	}
}

- (void) mouseDown: (NSEvent *)ev
{
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	NSInteger i, n = [pictures count] + 1;
	MilanWallpaper *w = [MilanWallpaper shared];
	for (i = 0; i < n; i++)
		if (NSPointInRect(p, [self rectForIndex: i])) {
			[w setImagePath: i == 0 ? nil : [pictures objectAtIndex: i - 1] fill: [w fill] color: [w color]];
			[self setNeedsDisplay: YES];
			return;
		}
}

/* dropping picture files here copies them into ~/Pictures and lists them */
- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)info { return NSDragOperationCopy; }

- (BOOL) performDragOperation: (id <NSDraggingInfo>)info
{
	NSArray *paths = [[info draggingPasteboard] propertyListForType: NSFilenamesPboardType];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *pics = [NSHomeDirectory() stringByAppendingPathComponent: @"Pictures"], *p;
	[fm createDirectoryAtPath: pics withIntermediateDirectories: YES attributes: nil error: NULL];
	for (p in paths) {
		NSString *e = [[p pathExtension] lowercaseString];
		if (MilanIsPictureExtension(e))
			[fm copyItemAtPath: p toPath: [pics stringByAppendingPathComponent: [p lastPathComponent]] error: NULL];
	}
	[self reload];
	return YES;
}

@end

@interface MilanSwatchView : NSView
@end

static NSArray *
swatches(void)
{
	return [NSArray arrayWithObjects:
	    [NSColor colorWithCalibratedRed: 0.32 green: 0.31 blue: 0.43 alpha: 1], [NSColor colorWithCalibratedWhite: 0.20 alpha: 1],
	    [NSColor colorWithCalibratedWhite: 0.55 alpha: 1], [NSColor colorWithCalibratedRed: 0.13 green: 0.38 blue: 0.75 alpha: 1],
	    [NSColor colorWithCalibratedRed: 0.12 green: 0.53 blue: 0.42 alpha: 1], [NSColor colorWithCalibratedRed: 0.75 green: 0.28 blue: 0.30 alpha: 1],
	    [NSColor colorWithCalibratedRed: 0.90 green: 0.62 blue: 0.20 alpha: 1], [NSColor colorWithCalibratedRed: 0.45 green: 0.30 blue: 0.65 alpha: 1],
	    nil];
}

@implementation MilanSwatchView
- (BOOL) isFlipped { return YES; }
- (NSRect) rectAt: (NSUInteger)i { return NSMakeRect(8 + i * 36, 4, 28, 22); }
- (void) drawRect: (NSRect)dirty
{
	NSUInteger i;
	NSArray *s = swatches();
	for (i = 0; i < [s count]; i++) {
		[(NSColor *)[s objectAtIndex: i] set];
		[[NSBezierPath bezierPathWithRoundedRect: [self rectAt: i] xRadius: 5 yRadius: 5] fill];
	}
}
- (void) mouseDown: (NSEvent *)ev
{
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	NSArray *s = swatches();
	NSUInteger i;
	for (i = 0; i < [s count]; i++)
		if (NSPointInRect(p, [self rectAt: i])) {
			[[MilanWallpaper shared] setImagePath: nil fill: [[MilanWallpaper shared] fill] color: [s objectAtIndex: i]];
			[[[self window] contentView] setNeedsDisplay: YES];
			return;
		}
}
@end

static NSWindow *panel;

@implementation MilanWallpaperPanel

+ (void) fillChanged: (NSSegmentedControl *)sc
{
	MilanWallpaper *w = [MilanWallpaper shared];
	[w setImagePath: [w imagePath] fill: (MilanFill)[sc selectedSegment] color: [w color]];
}

+ (void) show
{
	NSView *v;
	NSScrollView *sv;
	NSSegmentedControl *seg;
	NSTextField *t;
	const CGFloat W = 640, H = 470;
	NSArray *modes = [NSArray arrayWithObjects: @"Fill", @"Fit", @"Stretch", @"Center", @"Tile", nil];
	NSUInteger i;
	if (panel) { [panel makeKeyAndOrderFront: nil]; return; }
	panel = [[NSWindow alloc] initWithContentRect: NSMakeRect(260, 120, W, H)
	    styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
	    backing: NSBackingStoreBuffered defer: NO];
	[panel setReleasedWhenClosed: NO];
	[panel setTitle: @"Desktop Background"];
	[panel setMinSize: NSMakeSize(420, 320)];
	v = [panel contentView];

	sv = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, 96, W, H - 96)] autorelease];
	[sv setHasVerticalScroller: YES];
	[sv setBorderType: NSNoBorder];
	[sv setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[sv setDocumentView: [[[MilanThumbView alloc] initWithFrame: NSMakeRect(0, 0, W, 300)] autorelease]];
	[v addSubview: sv];

	t = [[[NSTextField alloc] initWithFrame: NSMakeRect(12, 62, 60, 18)] autorelease];
	[t setStringValue: @"Placement:"]; [t setEditable: NO]; [t setSelectable: NO]; [t setBezeled: NO]; [t setDrawsBackground: NO];
	[t setFont: [NSFont systemFontOfSize: 11]]; [t setAutoresizingMask: NSViewMaxYMargin];
	[v addSubview: t];
	seg = [[[NSSegmentedControl alloc] initWithFrame: NSMakeRect(78, 58, 300, 24)] autorelease];
	[seg setSegmentCount: [modes count]];
	for (i = 0; i < [modes count]; i++) { [seg setLabel: [modes objectAtIndex: i] forSegment: i]; [seg setWidth: 58 forSegment: i]; }
	[seg setSelectedSegment: (NSInteger)[[MilanWallpaper shared] fill]];
	[seg setTarget: self]; [seg setAction: @selector(fillChanged:)];
	[seg setAutoresizingMask: NSViewMaxYMargin];
	[v addSubview: seg];

	t = [[[NSTextField alloc] initWithFrame: NSMakeRect(12, 30, 60, 18)] autorelease];
	[t setStringValue: @"Colour:"]; [t setEditable: NO]; [t setSelectable: NO]; [t setBezeled: NO]; [t setDrawsBackground: NO];
	[t setFont: [NSFont systemFontOfSize: 11]]; [t setAutoresizingMask: NSViewMaxYMargin];
	[v addSubview: t];
	{
		MilanSwatchView *sw = [[[MilanSwatchView alloc] initWithFrame: NSMakeRect(70, 24, 300, 30)] autorelease];
		[sw setAutoresizingMask: NSViewMaxYMargin];
		[v addSubview: sw];
	}
	t = [[[NSTextField alloc] initWithFrame: NSMakeRect(12, 4, W - 24, 16)] autorelease];
	[t setStringValue: @"Drop PNG, TIFF or JPEG pictures here to add them (they are copied to ~/Pictures)."];
	[t setEditable: NO]; [t setSelectable: NO]; [t setBezeled: NO]; [t setDrawsBackground: NO];
	[t setFont: [NSFont systemFontOfSize: 10]]; [t setTextColor: [NSColor disabledControlTextColor]];
	[t setAutoresizingMask: NSViewMaxYMargin];
	[v addSubview: t];
	[panel makeKeyAndOrderFront: nil];
	[panel display];
}

@end

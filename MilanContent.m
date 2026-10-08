#import "MilanContent.h"

/* The context menu is drawn by Milan, as an overlay view inside the window it was opened from. GNUstep's own
 * NSMenu pop-up never showed here: under this theme a top-level menu is only shown when a pop-up owns it,
 * and even then (and for any extra borderless window of our own) the new X window was mapped but never
 * painted, while views inside an already-painted window draw fine (docs/notes.md). The items still come from
 * an NSMenu (titles, targets, actions, validation). */

#define ITEM_H 22.0
#define SEP_H 9.0
#define PAD 4.0

/* sits behind the menu, swallows the click that dismisses it */
@interface MilanMenuCatcher : NSView
@end

@interface MilanMenuView : NSView
{
	NSMenu *menu;
	NSInteger hot;
	NSArray *items;
	NSMutableArray *enabled;
}
- (id) initWithMenu: (NSMenu *)m;
- (NSSize) contentSize;
@end

static NSView *catcher, *menuView;
static NSResponder *prevFirst;
static BOOL prevMoved;

@implementation MilanMenuCatcher
- (BOOL) isFlipped { return YES; }
- (void) mouseDown: (NSEvent *)ev { MilanDismissMenu(); }
- (void) rightMouseDown: (NSEvent *)ev { MilanDismissMenu(); }
@end

@implementation MilanMenuView

- (id) initWithMenu: (NSMenu *)m
{
	NSMenuItem *it;
	self = [super initWithFrame: NSZeroRect];
	menu = [m retain];
	hot = -1;
	[menu update];		/* runs validateMenuItem: for each item (autoenabling) */
	{
		/* drop items tagged 910 when disabled, then any separator left leading, trailing or doubled */
		NSMutableArray *keep = [NSMutableArray array];
		for (it in [menu itemArray]) {
			if ([it tag] == 910 && ![it isEnabled]) continue;
			if ([it isSeparatorItem] && ([keep count] == 0 || [[keep lastObject] isSeparatorItem])) continue;
			[keep addObject: it];
		}
		while ([keep count] && [[keep lastObject] isSeparatorItem]) [keep removeLastObject];
		items = [keep retain];
	}
	enabled = [[NSMutableArray alloc] init];
	for (it in items) [enabled addObject: [NSNumber numberWithBool: ![it isSeparatorItem] && [it isEnabled]]];
	return self;
}

- (void) dealloc { [menu release]; [items release]; [enabled release]; [super dealloc]; }
- (BOOL) isFlipped { return YES; }
- (BOOL) acceptsFirstResponder { return YES; }

- (void) keyDown: (NSEvent *)ev
{
	NSString *k = [ev charactersIgnoringModifiers];
	if ([k length] && [k characterAtIndex: 0] == 0x1b) MilanDismissMenu();
}

- (NSSize) contentSize
{
	NSDictionary *a = [NSDictionary dictionaryWithObject: [NSFont systemFontOfSize: 12] forKey: NSFontAttributeName];
	CGFloat w = 120, h = PAD * 2;
	NSMenuItem *it;
	for (it in items) {
		if ([it isSeparatorItem]) { h += SEP_H; continue; }
		w = MAX(w, [[it title] sizeWithAttributes: a].width + 36);
		h += ITEM_H;
	}
	return NSMakeSize(ceil(w), h);
}

- (NSRect) rectForIndex: (NSInteger)i
{
	CGFloat y = PAD;
	NSInteger k;
	for (k = 0; k < i; k++) y += [[items objectAtIndex: k] isSeparatorItem] ? SEP_H : ITEM_H;
	return NSMakeRect(0, y, NSWidth([self bounds]), [[items objectAtIndex: i] isSeparatorItem] ? SEP_H : ITEM_H);
}

- (NSInteger) indexAt: (NSPoint)p
{
	NSInteger i, n = [items count];
	for (i = 0; i < n; i++)
		if (NSPointInRect(p, [self rectForIndex: i])) return i;
	return -1;
}

- (void) drawRect: (NSRect)dirty
{
	NSDictionary *norm = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 12], NSFontAttributeName,
	    [NSColor controlTextColor], NSForegroundColorAttributeName, nil];
	NSDictionary *dis = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 12], NSFontAttributeName,
	    [NSColor disabledControlTextColor], NSForegroundColorAttributeName, nil];
	NSDictionary *sel = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 12], NSFontAttributeName,
	    [NSColor whiteColor], NSForegroundColorAttributeName, nil];
	NSInteger i, n = [items count];
	[[NSColor colorWithCalibratedWhite: 0.97 alpha: 1] set];
	NSRectFill([self bounds]);
	[[NSColor colorWithCalibratedWhite: 0.62 alpha: 1] set];
	NSFrameRect([self bounds]);
	for (i = 0; i < n; i++) {
		NSMenuItem *it = [items objectAtIndex: i];
		NSRect r = [self rectForIndex: i];
		BOOL on = [[enabled objectAtIndex: i] boolValue];
		if ([it isSeparatorItem]) {
			[[NSColor colorWithCalibratedWhite: 0.78 alpha: 1] set];
			NSRectFill(NSMakeRect(8, NSMinY(r) + SEP_H / 2, NSWidth(r) - 16, 1));
			continue;
		}
		if (i == hot && on) {
			[[NSColor colorWithCalibratedRed: 0.20 green: 0.47 blue: 0.90 alpha: 1] set];
			NSRectFill(NSInsetRect(r, 3, 0));
		}
		[[it title] drawAtPoint: NSMakePoint(NSMinX(r) + 14, NSMinY(r) + 4) withAttributes: !on ? dis : (i == hot ? sel : norm)];
	}
}

- (void) mouseMoved: (NSEvent *)ev
{
	NSInteger i = [self indexAt: [self convertPoint: [ev locationInWindow] fromView: nil]];
	if (i != hot) { hot = i; [self setNeedsDisplay: YES]; }
}

- (void) mouseDown: (NSEvent *)ev { [self mouseMoved: ev]; }

- (void) mouseUp: (NSEvent *)ev
{
	NSInteger i = [self indexAt: [self convertPoint: [ev locationInWindow] fromView: nil]];
	NSMenuItem *it;
	if (i < 0 || ![[enabled objectAtIndex: i] boolValue]) return;
	it = [items objectAtIndex: i];
	[it retain];
	MilanDismissMenu();
	[NSApp sendAction: [it action] to: [it target] from: it];
	[it release];
}

- (void) rightMouseUp: (NSEvent *)ev { [self mouseUp: ev]; }

@end

void
MilanDismissMenu(void)
{
	NSWindow *w = [menuView window];
	if (!menuView) return;
	[menuView retain];
	[menuView removeFromSuperview];
	[catcher removeFromSuperview];
	[menuView release];
	menuView = nil;
	[catcher release];
	catcher = nil;
	[w setAcceptsMouseMovedEvents: prevMoved];
	if (prevFirst) [w makeFirstResponder: prevFirst];
	prevFirst = nil;
	[w display];
}

void
MilanPopUpMenu(NSMenu *menu, NSView *view, NSEvent *event)
{
	NSWindow *w = [view window];
	NSView *cv = [w contentView];
	MilanMenuView *mv;
	NSSize sz;
	NSPoint p = [cv convertPoint: [event locationInWindow] fromView: nil];
	NSRect fr;
	BOOL flipped = [cv isFlipped];
	MilanDismissMenu();
	mv = [[MilanMenuView alloc] initWithMenu: menu];
	sz = [mv contentSize];
	/* open down and to the right of the pointer, shifted to stay inside the window */
	fr = NSMakeRect(p.x, flipped ? p.y : p.y - sz.height, sz.width, sz.height);
	if (NSMaxX(fr) > NSMaxX([cv bounds])) fr.origin.x = MAX(0, NSMaxX([cv bounds]) - sz.width);
	if (NSMinY(fr) < NSMinY([cv bounds])) fr.origin.y = NSMinY([cv bounds]);
	if (NSMaxY(fr) > NSMaxY([cv bounds])) fr.origin.y = MAX(NSMinY([cv bounds]), NSMaxY([cv bounds]) - sz.height);
	catcher = [[MilanMenuCatcher alloc] initWithFrame: [cv bounds]];
	[catcher setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[cv addSubview: catcher];
	[mv setFrame: fr];
	[cv addSubview: mv];
	menuView = mv;
	prevFirst = [w firstResponder];
	prevMoved = [w acceptsMouseMovedEvents];
	[w setAcceptsMouseMovedEvents: YES];
	[w makeFirstResponder: mv];
	[w display];
}

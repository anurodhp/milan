#import "MilanIconView.h"
#import "MilanIcons.h"

#define CELL_W 100.0
#define CELL_H 88.0
#define ICON 48.0
#define PAD 12.0

@implementation MilanIconGrid

- (id) initWithFrame: (NSRect)f
{
	self = [super initWithFrame: f];
	sel = [[NSMutableIndexSet alloc] init];
	anchor = -1;
	return self;
}

- (void) dealloc
{
	[entries release]; [path release]; [sel release];
	[super dealloc];
}

- (BOOL) isFlipped { return YES; }
- (BOOL) acceptsFirstResponder { return YES; }

- (void) relayout
{
	NSScrollView *scroll = [self enclosingScrollView];
	NSSize vs, want;
	NSInteger c, rows;
	if (relaying || !scroll) return;
	relaying = YES;
	vs = [scroll contentSize];
	c = (NSInteger)((vs.width - PAD) / CELL_W);
	if (c < 1) c = 1;
	cols = c;
	rows = ([entries count] + c - 1) / c;
	want = NSMakeSize(vs.width, MAX(vs.height, rows * CELL_H + PAD * 2));
	if (!NSEqualSizes(want, [self frame].size)) [self setFrameSize: want];
	[self setNeedsDisplay: YES];
	relaying = NO;
}

- (void) setEntries: (NSArray *)e keepSelection: (BOOL)keep
{
	NSMutableSet *k = [NSMutableSet set];
	NSUInteger i;
	if (keep) {
		MilanEntry *x;
		for (x in [self selectedEntries]) [k addObject: x->path];
	}
	[entries release]; entries = [e retain];
	[sel removeAllIndexes];
	if (!keep) anchor = -1;
	for (i = 0; keep && i < [entries count]; i++)
		if ([k containsObject: ((MilanEntry *)[entries objectAtIndex: i])->path]) [sel addIndex: i];
	[self relayout];
	if (!keep) {
		[[[self enclosingScrollView] contentView] scrollToPoint: NSZeroPoint];
		[[self enclosingScrollView] reflectScrolledClipView: [[self enclosingScrollView] contentView]];
	}
	[delegate contentSelectionChanged];
}

- (NSArray *) selectedEntries
{
	if (!entries || ([sel count] && [sel lastIndex] >= [entries count])) return [NSArray array];
	return [entries objectsAtIndexes: sel];
}

- (void) selectPath: (NSString *)p
{
	NSUInteger i;
	[sel removeAllIndexes];
	for (i = 0; i < [entries count]; i++)
		if ([((MilanEntry *)[entries objectAtIndex: i])->path isEqualToString: p]) {
			[sel addIndex: i];
			anchor = i;
			[self scrollRectToVisible: [self cellRect: i]];
		}
	[self setNeedsDisplay: YES];
	[delegate contentSelectionChanged];
}

- (void) selectAll
{
	[sel removeAllIndexes];
	[sel addIndexesInRange: NSMakeRange(0, [entries count])];
	[self setNeedsDisplay: YES];
	[delegate contentSelectionChanged];
}

- (void) resizeWithOldSuperviewSize: (NSSize)old
{
	[super resizeWithOldSuperviewSize: old];
	[self relayout];
}

- (NSRect) cellRect: (NSInteger)i
{
	return NSMakeRect(PAD + (i % cols) * CELL_W, PAD + (i / cols) * CELL_H, CELL_W, CELL_H);
}

- (NSInteger) indexAtPoint: (NSPoint)p
{
	NSInteger c = (NSInteger)((p.x - PAD) / CELL_W), r = (NSInteger)((p.y - PAD) / CELL_H), i;
	if (p.x < PAD || p.y < PAD || c >= cols) return -1;
	i = r * cols + c;
	return i < (NSInteger)[entries count] ? i : -1;
}

- (void) drawRect: (NSRect)dirty
{
	static NSDictionary *attrs, *selAttrs;
	NSInteger first, last, i, n = [entries count];
	if (!attrs) {
		NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
		[ps setAlignment: NSCenterTextAlignment];
		[ps setLineBreakMode: NSLineBreakByTruncatingMiddle];
		attrs = [[NSDictionary dictionaryWithObjectsAndKeys:
		    [NSFont systemFontOfSize: 11], NSFontAttributeName, ps, NSParagraphStyleAttributeName,
		    [NSColor controlTextColor], NSForegroundColorAttributeName, nil] retain];
		selAttrs = [[NSDictionary dictionaryWithObjectsAndKeys:
		    [NSFont systemFontOfSize: 11], NSFontAttributeName, ps, NSParagraphStyleAttributeName,
		    [NSColor selectedMenuItemTextColor], NSForegroundColorAttributeName, nil] retain];
	}
	[[NSColor controlBackgroundColor] set];
	NSRectFill(dirty);
	if (!n || !cols) return;
	first = (NSInteger)((NSMinY(dirty) - PAD) / CELL_H) * cols;
	last = ((NSInteger)((NSMaxY(dirty) - PAD) / CELL_H) + 1) * cols;
	if (first < 0) first = 0;
	if (last > n) last = n;
	for (i = first; i < last; i++) {
		MilanEntry *e = [entries objectAtIndex: i];
		NSRect c = [self cellRect: i];
		BOOL s = [sel containsIndex: i];
		NSRect ir = NSMakeRect(NSMidX(c) - ICON / 2, c.origin.y + 4, ICON, ICON);
		NSRect tr = NSMakeRect(c.origin.x + 3, c.origin.y + ICON + 8, CELL_W - 6, 28);
		NSImage *img = [MilanIcons iconForEntry: e];
		if (s) {
			[[NSColor selectedMenuItemColor] set];
			NSRectFill(NSMakeRect(tr.origin.x, tr.origin.y, tr.size.width, 15));
			[[[NSColor selectedMenuItemColor] colorWithAlphaComponent: 0.25] set];
			NSRectFillUsingOperation(ir, NSCompositeSourceOver);
		}
		[img drawInRect: ir fromRect: NSZeroRect operation: NSCompositeSourceOver
		     fraction: e->isHidden ? 0.5 : 1.0 respectFlipped: YES hints: nil];
		[e->name drawInRect: tr withAttributes: s ? selAttrs : attrs];
	}
}

- (void) mouseDown: (NSEvent *)ev
{
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	NSInteger i = [self indexAtPoint: p];
	NSUInteger m = [ev modifierFlags];
	[[self window] makeFirstResponder: self];
	if (i < 0) {
		if (!(m & (NSShiftKeyMask | NSCommandKeyMask))) [sel removeAllIndexes];
	} else if (m & NSCommandKeyMask) {
		if ([sel containsIndex: i]) [sel removeIndex: i]; else [sel addIndex: i];
		anchor = i;
	} else if ((m & NSShiftKeyMask) && anchor >= 0) {
		[sel removeAllIndexes];
		[sel addIndexesInRange: NSMakeRange(MIN(anchor, i), labs(i - anchor) + 1)];
	} else {
		if (![sel containsIndex: i]) { [sel removeAllIndexes]; [sel addIndex: i]; }
		anchor = i;
	}
	[self setNeedsDisplay: YES];
	[delegate contentSelectionChanged];
	if (i >= 0 && [ev clickCount] == 2)
		[delegate contentOpen: [self selectedEntries]];
}

- (NSMenu *) menuForEvent: (NSEvent *)ev
{
	NSInteger i = [self indexAtPoint: [self convertPoint: [ev locationInWindow] fromView: nil]];
	if (i >= 0 && ![sel containsIndex: i]) { [sel removeAllIndexes]; [sel addIndex: i]; anchor = i; }
	else if (i < 0) [sel removeAllIndexes];
	[self setNeedsDisplay: YES];
	[delegate contentSelectionChanged];
	return [delegate contentMenu];
}

- (void) moveSelection: (NSInteger)delta extend: (BOOL)ext
{
	NSInteger n = [entries count], cur = anchor < 0 ? (delta > 0 ? -1 : n) : anchor, t = cur + delta;
	if (!n) return;
	if (t < 0) t = 0;
	if (t >= n) t = n - 1;
	if (!ext || anchor < 0) [sel removeAllIndexes];
	if (ext && anchor >= 0) [sel addIndexesInRange: NSMakeRange(MIN(cur, t), labs(t - cur) + 1)];
	else [sel addIndex: t];
	anchor = t;
	[self scrollRectToVisible: [self cellRect: t]];
	[self setNeedsDisplay: YES];
	[delegate contentSelectionChanged];
}

- (void) keyDown: (NSEvent *)ev
{
	NSString *k = [ev charactersIgnoringModifiers];
	unichar c = [k length] ? [k characterAtIndex: 0] : 0;
	BOOL shift = ([ev modifierFlags] & NSShiftKeyMask) != 0;
	switch (c) {
	case NSLeftArrowFunctionKey: [self moveSelection: -1 extend: shift]; break;
	case NSRightArrowFunctionKey: [self moveSelection: 1 extend: shift]; break;
	case NSUpArrowFunctionKey: [self moveSelection: -cols extend: shift]; break;
	case NSDownArrowFunctionKey: [self moveSelection: cols extend: shift]; break;
	case '\r': if ([sel count]) [delegate contentOpen: [self selectedEntries]]; break;
	default: [super keyDown: ev];
	}
}

@end

@implementation MilanIconView

- (id) init
{
	self = [super init];
	grid = [[MilanIconGrid alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)];
	scroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)];
	[scroll setHasVerticalScroller: YES];
	[scroll setAutohidesScrollers: YES];
	[scroll setBorderType: NSNoBorder];
	[scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[scroll setDocumentView: grid];
	[grid setAutoresizingMask: NSViewWidthSizable];
	return self;
}

- (void) dealloc { [grid release]; [scroll release]; [super dealloc]; }
- (NSView *) view { return scroll; }
- (void) setDelegate: (id <MilanContentDelegate>)d { grid->delegate = d; }
- (NSString *) browsedPath { return grid->path; }
- (NSArray *) selectedEntries { return [grid selectedEntries]; }
- (void) selectAll { [grid selectAll]; }
- (void) selectPath: (NSString *)p { [grid selectPath: p]; }

- (void) setPath: (NSString *)p entries: (NSArray *)e
{
	[grid->path release]; grid->path = [p copy];
	[grid setEntries: e keepSelection: NO];
}

- (void) reloadEntries: (NSArray *)e { [grid setEntries: e keepSelection: YES]; }

@end

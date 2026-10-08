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
	[self registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
	return self;
}

- (void) dealloc
{
	[entries release]; [path release]; [sel release]; [typed release];
	[super dealloc];
}

- (BOOL) isFlipped { return YES; }
- (BOOL) acceptsFirstResponder { return YES; }

- (void) setDesktop: (BOOL)d { desktop = d; [self relayout]; }

- (void) relayout
{
	NSScrollView *scroll = [self enclosingScrollView];
	if (desktop) {
		perCol = MAX(1, (NSInteger)((NSHeight([self bounds]) - 2 * PAD) / CELL_H));
		cols = ([entries count] + perCol - 1) / perCol;
		[self setNeedsDisplay: YES];
		return;
	}
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
	if (desktop) {
		NSInteger col = i / MAX(perCol, 1), row = i % MAX(perCol, 1);
		return NSMakeRect(NSWidth([self bounds]) - PAD - (col + 1) * CELL_W, PAD + row * CELL_H, CELL_W, CELL_H);
	}
	return NSMakeRect(PAD + (i % cols) * CELL_W, PAD + (i / cols) * CELL_H, CELL_W, CELL_H);
}

- (NSInteger) indexAtPoint: (NSPoint)p
{
	if (desktop) {
		NSInteger col = (NSInteger)floor((NSWidth([self bounds]) - PAD - p.x) / CELL_W) , row = (NSInteger)floor((p.y - PAD) / CELL_H), i;
		if (p.y < PAD || row >= perCol || NSWidth([self bounds]) - PAD - p.x < -CELL_W + 1) return -1;
		if (p.x > NSWidth([self bounds]) - PAD) return -1;
		i = col * perCol + row;
		return col >= 0 && i >= 0 && i < (NSInteger)[entries count] ? i : -1;
	}
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
	if (!desktop) {
		[[NSColor controlBackgroundColor] set];
		NSRectFill(dirty);
	}
	if (!n || !cols) return;
	if (desktop) {
		first = 0; last = n;
	} else {
		first = (NSInteger)((NSMinY(dirty) - PAD) / CELL_H) * cols;
		last = ((NSInteger)((NSMaxY(dirty) - PAD) / CELL_H) + 1) * cols;
	}
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
			/* rounded highlights, radius 5: the icon tile and the label */
			NSBezierPath *tile = [NSBezierPath bezierPathWithRoundedRect: ir xRadius: 5 yRadius: 5];
			NSBezierPath *label = [NSBezierPath bezierPathWithRoundedRect: NSMakeRect(tr.origin.x, tr.origin.y, tr.size.width, 15)
			                                                      xRadius: 5 yRadius: 5];
			[[[NSColor selectedMenuItemColor] colorWithAlphaComponent: 0.25] set];
			[tile fill];
			[[NSColor selectedMenuItemColor] set];
			[label fill];
		}
		[img drawInRect: ir fromRect: NSZeroRect operation: NSCompositeSourceOver
		     fraction: e->isHidden ? 0.5 : 1.0 respectFlipped: YES hints: nil];
		if (desktop && !s) {
			/* white label with a dark shadow so it reads on any wallpaper */
			static NSDictionary *white, *shadow;
			if (!white) {
				NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
				[ps setAlignment: NSCenterTextAlignment];
				[ps setLineBreakMode: NSLineBreakByTruncatingMiddle];
				white = [[NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 11], NSFontAttributeName,
				    ps, NSParagraphStyleAttributeName, [NSColor whiteColor], NSForegroundColorAttributeName, nil] retain];
				shadow = [[NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 11], NSFontAttributeName,
				    ps, NSParagraphStyleAttributeName, [NSColor blackColor], NSForegroundColorAttributeName, nil] retain];
			}
			[e->name drawInRect: NSOffsetRect(tr, 1, 1) withAttributes: shadow];
			[e->name drawInRect: tr withAttributes: white];
		} else
			[e->name drawInRect: tr withAttributes: s ? selAttrs : attrs];
	}
	if (rubber) {
		[[[NSColor selectedMenuItemColor] colorWithAlphaComponent: 0.2] set];
		NSRectFillUsingOperation(rubberRect, NSCompositeSourceOver);
		[[NSColor selectedMenuItemColor] set];
		NSFrameRect(rubberRect);
	}
}

- (void) mouseDown: (NSEvent *)ev
{
	MilanDismissMenu();
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	NSInteger i = [self indexAtPoint: p];
	NSUInteger m = [ev modifierFlags];
	[[self window] makeFirstResponder: self];
	downPoint = p;
	dragging = rubber = NO;
	pendingDrag = NO;
	if (i < 0) {
		if (!(m & (NSShiftKeyMask | NSCommandKeyMask))) [sel removeAllIndexes];
		rubber = YES;
		baseSel = [sel mutableCopy];
	} else if (m & NSCommandKeyMask) {
		if ([sel containsIndex: i]) [sel removeIndex: i]; else [sel addIndex: i];
		anchor = i;
	} else if ((m & NSShiftKeyMask) && anchor >= 0) {
		[sel removeAllIndexes];
		[sel addIndexesInRange: NSMakeRange(MIN(anchor, i), labs(i - anchor) + 1)];
	} else {
		if (![sel containsIndex: i]) { [sel removeAllIndexes]; [sel addIndex: i]; }
		anchor = i;
		pendingDrag = YES;
	}
	[self setNeedsDisplay: YES];
	[delegate contentSelectionChanged];
	if (i >= 0 && [ev clickCount] == 2) {
		pendingDrag = NO;
		[delegate contentOpen: [self selectedEntries]];
	}
}

- (NSRect) rubberRect: (NSPoint)p
{
	return NSMakeRect(MIN(downPoint.x, p.x), MIN(downPoint.y, p.y), fabs(p.x - downPoint.x), fabs(p.y - downPoint.y));
}

- (void) mouseDragged: (NSEvent *)ev
{
	NSPoint p = [self convertPoint: [ev locationInWindow] fromView: nil];
	if (rubber) {
		NSInteger i, n = [entries count];
		NSRect r;
		[self autoscroll: ev];
		rubberRect = [self rubberRect: p];
		r = rubberRect;
		[sel removeAllIndexes];
		[sel addIndexes: baseSel];
		for (i = 0; i < n; i++)
			if (NSIntersectsRect(r, [self cellRect: i])) [sel addIndex: i];
		[self setNeedsDisplay: YES];
		[delegate contentSelectionChanged];
	} else if (pendingDrag && !dragging && (fabs(p.x - downPoint.x) > 4 || fabs(p.y - downPoint.y) > 4)) {
		NSMutableArray *paths = [NSMutableArray array];
		NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];
		MilanEntry *e;
		NSImage *icon;
		dragging = YES;
		for (e in [self selectedEntries]) [paths addObject: e->path];
		[pb declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] owner: self];
		[pb setPropertyList: paths forType: NSFilenamesPboardType];
		icon = [MilanIcons iconForEntry: [[self selectedEntries] objectAtIndex: 0]];
		[self dragImage: icon at: NSMakePoint(p.x - 24, p.y + 24) offset: NSZeroSize event: ev
		     pasteboard: pb source: self slideBack: YES];
	}
}

- (void) mouseUp: (NSEvent *)ev
{
	if (rubber) { rubber = NO; [baseSel release]; baseSel = nil; [self setNeedsDisplay: YES]; }
	dragging = pendingDrag = NO;
}

- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL)local
{
	return NSDragOperationMove | NSDragOperationCopy;
}

/* drop target: a folder cell, else the folder being browsed */
- (NSString *) dropTargetAt: (id <NSDraggingInfo>)info
{
	NSInteger i = [self indexAtPoint: [self convertPoint: [info draggingLocation] fromView: nil]];
	MilanEntry *e = i >= 0 ? [entries objectAtIndex: i] : nil;
	return e && e->isDir && !e->isApp ? e->path : nil;
}

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)info { return [self draggingUpdated: info]; }

- (NSDragOperation) draggingUpdated: (id <NSDraggingInfo>)info
{
	return ([info draggingSourceOperationMask] & NSDragOperationCopy) && ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask)
	    ? NSDragOperationCopy : NSDragOperationMove;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)info
{
	NSArray *paths = [[info draggingPasteboard] propertyListForType: NSFilenamesPboardType];
	BOOL copy = ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0;
	if (![paths count]) return NO;
	[delegate contentDropPaths: paths onto: [self dropTargetAt: info] copy: copy];
	return YES;
}

- (void) rightMouseDown: (NSEvent *)ev
{
	NSMenu *m = [self menuForEvent: ev];
	if (m) MilanPopUpMenu(m, self, ev);
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

- (void) typeSelect: (NSString *)ch
{
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	NSUInteger i;
	if (!typed || now - typedAt > 1.0) { [typed release]; typed = [ch mutableCopy]; }
	else [typed appendString: ch];
	typedAt = now;
	for (i = 0; i < [entries count]; i++)
		if ([((MilanEntry *)[entries objectAtIndex: i])->name rangeOfString: typed options: NSCaseInsensitiveSearch | NSAnchoredSearch].location != NSNotFound) {
			[sel removeAllIndexes]; [sel addIndex: i]; anchor = i;
			[self scrollRectToVisible: [self cellRect: i]];
			[self setNeedsDisplay: YES];
			[delegate contentSelectionChanged];
			return;
		}
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
	default:
		if (c >= 0x20 && c < 0xf700 && !([ev modifierFlags] & NSCommandKeyMask)) [self typeSelect: k];
		else [super keyDown: ev];
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

/* the desktop: the grid on its own (no scroll view), transparent over the wallpaper */
- (id) initForDesktop
{
	self = [super init];
	grid = [[MilanIconGrid alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)];
	[grid setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[grid setDesktop: YES];
	return self;
}

- (void) dealloc { [grid release]; [scroll release]; [super dealloc]; }
- (NSView *) view { return scroll ? (NSView *)scroll : (NSView *)grid; }
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

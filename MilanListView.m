#import "MilanListView.h"
#import "MilanIcons.h"

@implementation MilanTable

- (void) setMenuDelegate: (id <MilanContentDelegate>)d { menuDelegate = d; }

- (NSMenu *) menuForEvent: (NSEvent *)ev
{
	NSInteger row = [self rowAtPoint: [self convertPoint: [ev locationInWindow] fromView: nil]];
	if (row >= 0 && ![self isRowSelected: row])
		[self selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
	else if (row < 0)
		[self deselectAll: nil];
	return [menuDelegate contentMenu];
}

- (void) rightMouseDown: (NSEvent *)ev
{
	NSMenu *m = [self menuForEvent: ev];
	if (m) MilanPopUpMenu(m, self, ev);
}

- (void) mouseDown: (NSEvent *)ev
{
	MilanDismissMenu();
	[super mouseDown: ev];
}

- (void) keyDown: (NSEvent *)ev
{
	NSString *k = [ev charactersIgnoringModifiers];
	if ([k length] && [k characterAtIndex: 0] == '\r' && [self selectedRow] >= 0)
		[self sendAction: [self doubleAction] to: [self target]];
	else
		[super keyDown: ev];
}

@end

@implementation MilanListView

- (id) init
{
	NSTableColumn *c;
	NSArray *ids = [NSArray arrayWithObjects: @"icon", @"name", @"date", @"size", @"kind", nil];
	NSArray *titles = [NSArray arrayWithObjects: @"", @"Name", @"Date Modified", @"Size", @"Kind", nil];
	CGFloat widths[] = { 22, 260, 140, 80, 110 };
	NSUInteger i;
	self = [super init];
	table = [[MilanTable alloc] initWithFrame: NSMakeRect(0, 0, 600, 400)];
	for (i = 0; i < 5; i++) {
		c = [[[NSTableColumn alloc] initWithIdentifier: [ids objectAtIndex: i]] autorelease];
		[[c headerCell] setStringValue: [titles objectAtIndex: i]];
		[c setWidth: widths[i]];
		[c setMinWidth: i == 0 ? 22 : 40];
		if (i == 0) {
			[c setMaxWidth: 22];
			[c setDataCell: [[[NSImageCell alloc] init] autorelease]];
			[c setResizingMask: NSTableColumnNoResizing];
		} else {
			NSTextFieldCell *tc = [[[NSTextFieldCell alloc] initTextCell: @""] autorelease];
			[tc setFont: [NSFont systemFontOfSize: 12]];
			[tc setLineBreakMode: NSLineBreakByTruncatingTail];
			if (i == 3) [tc setAlignment: NSRightTextAlignment];
			if (i >= 2) [tc setTextColor: [NSColor disabledControlTextColor]];
			[c setDataCell: tc];
		}
		[table addTableColumn: c];
	}
	[table setRowHeight: 20];
	[table setAllowsMultipleSelection: YES];
	[table setAllowsColumnReordering: NO];
	[table setUsesAlternatingRowBackgroundColors: YES];
	[table setIntercellSpacing: NSMakeSize(0, 0)];
	[table setDataSource: self];
	[table setDelegate: self];
	[table setTarget: self];
	[table setDoubleAction: @selector(openSelected:)];
	[table registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
	[table setDraggingSourceOperationMask: NSDragOperationMove | NSDragOperationCopy forLocal: YES];
	scroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 600, 400)];
	[scroll setHasVerticalScroller: YES];
	[scroll setBorderType: NSNoBorder];
	[scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[scroll setDocumentView: table];
	return self;
}

- (void) dealloc
{
	[table setDataSource: nil]; [table setDelegate: nil];
	[scroll release]; [table release]; [entries release]; [path release];
	[super dealloc];
}

- (NSView *) view { return scroll; }
- (void) setDelegate: (id <MilanContentDelegate>)d { delegate = d; [table setMenuDelegate: d]; }
- (NSString *) browsedPath { return path; }

- (void) setPath: (NSString *)p entries: (NSArray *)e
{
	[path release]; path = [p copy];
	[entries release]; entries = [e retain];
	[table reloadData];
	[table deselectAll: nil];
	[table scrollRowToVisible: 0];
}

- (void) reloadEntries: (NSArray *)e
{
	NSMutableSet *keep = [NSMutableSet set];
	NSMutableIndexSet *idx = [NSMutableIndexSet indexSet];
	MilanEntry *x;
	NSUInteger i;
	for (x in [self selectedEntries]) [keep addObject: x->path];
	[entries release]; entries = [e retain];
	for (i = 0; i < [entries count]; i++)
		if ([keep containsObject: ((MilanEntry *)[entries objectAtIndex: i])->path]) [idx addIndex: i];
	[table reloadData];
	[table selectRowIndexes: idx byExtendingSelection: NO];
}

- (NSArray *) selectedEntries
{
	NSIndexSet *s = [table selectedRowIndexes];
	if (!entries || ![s count] || [s lastIndex] >= [entries count]) return [NSArray array];
	return [entries objectsAtIndexes: s];
}

- (void) selectAll { [table selectAll: nil]; }

- (void) selectPath: (NSString *)p
{
	NSUInteger i;
	for (i = 0; i < [entries count]; i++)
		if ([((MilanEntry *)[entries objectAtIndex: i])->path isEqualToString: p]) {
			[table selectRowIndexes: [NSIndexSet indexSetWithIndex: i] byExtendingSelection: NO];
			[table scrollRowToVisible: i];
		}
}

- (void) setSortKey: (MilanSort)key ascending: (BOOL)asc
{
	NSArray *ids = [NSArray arrayWithObjects: @"name", @"size", @"date", @"kind", nil];
	NSString *id_ = [ids objectAtIndex: key];
	NSTableColumn *c;
	for (c in [table tableColumns])
		[table setIndicatorImage: nil inTableColumn: c];
	[table setIndicatorImage: [NSImage imageNamed: asc ? @"NSAscendingSortIndicator" : @"NSDescendingSortIndicator"]
	           inTableColumn: [table tableColumnWithIdentifier: id_]];
}

- (void) openSelected: (id)sender
{
	NSArray *s = [self selectedEntries];
	if ([s count]) [delegate contentOpen: s];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *)t { return [entries count]; }

- (BOOL) tableView: (NSTableView *)t writeRowsWithIndexes: (NSIndexSet *)rows toPasteboard: (NSPasteboard *)pb
{
	NSMutableArray *paths = [NSMutableArray array];
	[[entries objectsAtIndexes: rows] enumerateObjectsUsingBlock: ^(id e, NSUInteger i, BOOL *stop) { [paths addObject: ((MilanEntry *)e)->path]; }];
	[pb declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] owner: nil];
	[pb setPropertyList: paths forType: NSFilenamesPboardType];
	return YES;
}

- (NSDragOperation) tableView: (NSTableView *)t validateDrop: (id <NSDraggingInfo>)info
          proposedRow: (NSInteger)row proposedDropOperation: (NSTableViewDropOperation)op
{
	MilanEntry *e = row >= 0 && row < (NSInteger)[entries count] ? [entries objectAtIndex: row] : nil;
	if (e && e->isDir && !e->isApp && op == NSTableViewDropOn) return NSDragOperationMove;
	[t setDropRow: -1 dropOperation: NSTableViewDropOn];	/* the folder being browsed */
	return NSDragOperationMove;
}

- (BOOL) tableView: (NSTableView *)t acceptDrop: (id <NSDraggingInfo>)info row: (NSInteger)row
     dropOperation: (NSTableViewDropOperation)op
{
	NSArray *paths = [[info draggingPasteboard] propertyListForType: NSFilenamesPboardType];
	MilanEntry *e = row >= 0 && row < (NSInteger)[entries count] ? [entries objectAtIndex: row] : nil;
	if (![paths count]) return NO;
	[delegate contentDropPaths: paths onto: (e && e->isDir && !e->isApp) ? e->path : nil
	                      copy: ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0];
	return YES;
}

- (id) tableView: (NSTableView *)t objectValueForTableColumn: (NSTableColumn *)c row: (NSInteger)r
{
	MilanEntry *e = [entries objectAtIndex: r];
	NSString *i = [c identifier];
	if ([i isEqualToString: @"icon"]) return [MilanIcons iconForEntry: e];
	if ([i isEqualToString: @"name"]) return e->name;
	if ([i isEqualToString: @"date"]) return [e dateString];
	if ([i isEqualToString: @"size"]) return [e sizeString];
	return [e kind];
}

- (void) tableViewSelectionDidChange: (NSNotification *)n { [delegate contentSelectionChanged]; }

- (void) tableView: (NSTableView *)t didClickTableColumn: (NSTableColumn *)c
{
	NSString *i = [c identifier];
	if ([i isEqualToString: @"name"]) [delegate contentSortBy: MilanSortName];
	else if ([i isEqualToString: @"date"]) [delegate contentSortBy: MilanSortDate];
	else if ([i isEqualToString: @"size"]) [delegate contentSortBy: MilanSortSize];
	else if ([i isEqualToString: @"kind"]) [delegate contentSortBy: MilanSortKind];
}

@end

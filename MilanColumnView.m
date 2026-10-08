#import "MilanColumnView.h"
#import "MilanListView.h"
#import "MilanIcons.h"

#define COL_W 220.0

/* One column: a table of entries, or (entries nil) a preview of one file. */
@interface MilanColumn : NSObject <NSTableViewDataSource, NSTableViewDelegate>
{
@public
	NSString *path;
	NSArray *entries;
	NSScrollView *scroll;
	MilanTable *table;
	MilanColumnView *owner;
}
- (id) initWithPath: (NSString *)p entries: (NSArray *)e owner: (MilanColumnView *)o;
- (NSArray *) selectedEntries;
@end

@implementation MilanColumn

- (id) initWithPath: (NSString *)p entries: (NSArray *)e owner: (MilanColumnView *)o
{
	NSTableColumn *c;
	self = [super init];
	path = [p copy]; entries = [e retain]; owner = o;
	table = [[MilanTable alloc] initWithFrame: NSMakeRect(0, 0, COL_W, 100)];
	c = [[[NSTableColumn alloc] initWithIdentifier: @"icon"] autorelease];
	[c setWidth: 22]; [c setDataCell: [[[NSImageCell alloc] init] autorelease]];
	[table addTableColumn: c];
	c = [[[NSTableColumn alloc] initWithIdentifier: @"name"] autorelease];
	[c setWidth: COL_W - 22 - 18 - 17];
	{
		NSTextFieldCell *tc = [[[NSTextFieldCell alloc] initTextCell: @""] autorelease];
		[tc setFont: [NSFont systemFontOfSize: 12]];
		[tc setLineBreakMode: NSLineBreakByTruncatingMiddle];
		[c setDataCell: tc];
	}
	[table addTableColumn: c];
	c = [[[NSTableColumn alloc] initWithIdentifier: @"arrow"] autorelease];
	[c setWidth: 18];
	{
		NSTextFieldCell *tc = [[[NSTextFieldCell alloc] initTextCell: @""] autorelease];
		[tc setAlignment: NSCenterTextAlignment];
		[c setDataCell: tc];
	}
	[table addTableColumn: c];
	[table setHeaderView: nil];
	[table setRowHeight: 20];
	[table setIntercellSpacing: NSMakeSize(0, 0)];
	[table setAllowsMultipleSelection: YES];
	[table setDataSource: self];
	[table setDelegate: self];
	[table setTarget: self];
	[table setDoubleAction: @selector(openSelected:)];
	[table registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
	[table setDraggingSourceOperationMask: NSDragOperationMove | NSDragOperationCopy forLocal: YES];
	[table setMenuDelegate: (id)o];
	scroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, COL_W, 100)];
	[scroll setHasVerticalScroller: YES];
	[scroll setAutohidesScrollers: YES];
	[scroll setBorderType: NSNoBorder];
	[scroll setDocumentView: table];
	return self;
}

- (void) dealloc
{
	[table setDataSource: nil]; [table setDelegate: nil];
	[path release]; [entries release]; [scroll release]; [table release];
	[super dealloc];
}

- (NSArray *) selectedEntries
{
	NSIndexSet *s = [table selectedRowIndexes];
	if (![s count] || [s lastIndex] >= [entries count]) return [NSArray array];
	return [entries objectsAtIndexes: s];
}

- (void) openSelected: (id)sender { [owner column: self open: [self selectedEntries]]; }
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
	[t setDropRow: -1 dropOperation: NSTableViewDropOn];	/* this column's folder */
	return NSDragOperationMove;
}

- (BOOL) tableView: (NSTableView *)t acceptDrop: (id <NSDraggingInfo>)info row: (NSInteger)row
     dropOperation: (NSTableViewDropOperation)op
{
	NSArray *paths = [[info draggingPasteboard] propertyListForType: NSFilenamesPboardType];
	MilanEntry *e = row >= 0 && row < (NSInteger)[entries count] ? [entries objectAtIndex: row] : nil;
	if (![paths count]) return NO;
	[[owner contentDelegate] contentDropPaths: paths onto: (e && e->isDir && !e->isApp) ? e->path : path
	                                     copy: ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0];
	return YES;
}

- (id) tableView: (NSTableView *)t objectValueForTableColumn: (NSTableColumn *)c row: (NSInteger)r
{
	MilanEntry *e = [entries objectAtIndex: r];
	NSString *i = [c identifier];
	if ([i isEqualToString: @"icon"]) return [MilanIcons iconForEntry: e];
	if ([i isEqualToString: @"name"]) return e->name;
	return e->isDir && !e->isApp ? @"›" : @"";
}

- (void) tableView: (NSTableView *)t willDisplayCell: (id)cell forTableColumn: (NSTableColumn *)c row: (NSInteger)r
{
	if ([cell isKindOfClass: [NSTextFieldCell class]])
		[cell setTextColor: [t isRowSelected: r] ? [NSColor whiteColor] : [NSColor controlTextColor]];
}

- (void) tableViewSelectionDidChange: (NSNotification *)n
{
	[owner column: self selectionChanged: [self selectedEntries]];
}

@end

@implementation MilanColumnView

- (id) init
{
	self = [super init];
	columns = [[NSMutableArray alloc] init];
	doc = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, COL_W, 100)];
	scroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 600, 400)];
	[scroll setHasHorizontalScroller: YES];
	[scroll setBorderType: NSNoBorder];
	[scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[scroll setDocumentView: doc];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(relayout)
	    name: NSViewFrameDidChangeNotification object: [scroll contentView]];
	[[scroll contentView] setPostsFrameChangedNotifications: YES];
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[columns release]; [doc release]; [scroll release];
	[super dealloc];
}

- (NSView *) view { return scroll; }
- (void) setDelegate: (id <MilanContentDelegate>)d { delegate = d; }
- (NSMenu *) menu { return [delegate contentMenu]; }
- (id <MilanContentDelegate>) contentDelegate { return delegate; }
- (NSString *) browsedPath { return [columns count] ? ((MilanColumn *)[columns lastObject])->path : nil; }

/* Menu delegate protocol surface for the columns' tables. */
- (NSMenu *) contentMenu { return [delegate contentMenu]; }

- (void) relayout
{
	NSSize vs, want;
	NSUInteger i;
	if (relaying) return;
	relaying = YES;
	vs = [scroll contentSize];
	want = NSMakeSize(MAX(vs.width, [columns count] * COL_W), vs.height);
	if (!NSEqualSizes(want, [doc frame].size)) [doc setFrameSize: want];
	for (i = 0; i < [columns count]; i++)
		[((MilanColumn *)[columns objectAtIndex: i])->scroll setFrame: NSMakeRect(i * COL_W, 0, COL_W, vs.height)];
	relaying = NO;
}

- (void) truncateTo: (NSUInteger)n
{
	while ([columns count] > n) {
		MilanColumn *c = [columns lastObject];
		[c->scroll removeFromSuperview];
		[columns removeLastObject];
	}
}

- (void) appendColumnPath: (NSString *)p entries: (NSArray *)e
{
	MilanColumn *c = [[MilanColumn alloc] initWithPath: p entries: e owner: self];
	[columns addObject: c];
	[doc addSubview: c->scroll];
	[c release];
	[self relayout];
	[[scroll contentView] scrollToPoint: NSMakePoint(MAX(0, [columns count] * COL_W - [scroll contentSize].width), 0)];
	[scroll reflectScrolledClipView: [scroll contentView]];
}

- (void) setPath: (NSString *)p entries: (NSArray *)e
{
	gen++;
	[self truncateTo: 0];
	[self appendColumnPath: p entries: e];
	[delegate contentSelectionChanged];
}

- (void) reloadEntries: (NSArray *)e
{
	MilanColumn *c = [columns count] ? [columns objectAtIndex: 0] : nil;
	NSArray *keep;
	if (!c) return;
	keep = [c selectedEntries];
	[c->entries release]; c->entries = [e retain];
	[c->table reloadData];
	if ([keep count]) {
		MilanEntry *x = [keep objectAtIndex: 0];
		NSUInteger i;
		for (i = 0; i < [e count]; i++)
			if ([((MilanEntry *)[e objectAtIndex: i])->path isEqualToString: x->path]) {
				NSTableView *t = c->table;
				/* restoring the row would re-trigger the load; the deeper columns are already current */
				[t selectRowIndexes: [NSIndexSet indexSetWithIndex: i] byExtendingSelection: NO];
				break;
			}
	}
}

- (NSArray *) selectedEntries
{
	NSInteger i;
	for (i = [columns count] - 1; i >= 0; i--) {
		NSArray *s = [(MilanColumn *)[columns objectAtIndex: i] selectedEntries];
		if ([s count]) return s;
	}
	return [NSArray array];
}

- (void) selectAll
{
	if ([columns count]) [((MilanColumn *)[columns lastObject])->table selectAll: nil];
}

- (void) selectPath: (NSString *)p
{
	MilanColumn *c = [columns count] ? [columns lastObject] : nil;
	NSUInteger i;
	for (i = 0; c && i < [c->entries count]; i++)
		if ([((MilanEntry *)[c->entries objectAtIndex: i])->path isEqualToString: p])
			[c->table selectRowIndexes: [NSIndexSet indexSetWithIndex: i] byExtendingSelection: NO];
}

- (void) column: (MilanColumn *)c selectionChanged: (NSArray *)sel
{
	NSUInteger idx = [columns indexOfObjectIdenticalTo: c];
	MilanEntry *e = [sel count] == 1 ? [sel objectAtIndex: 0] : nil;
	if (idx == NSNotFound) return;
	[self truncateTo: idx + 1];
	gen++;
	if (e && e->isDir && !e->isApp) {
		unsigned g = gen;
		NSString *p = [e->path copy];
		[delegate contentLoadPath: p completion: ^(NSArray *ents) {
			if (g == gen && ents) [self appendColumnPath: p entries: ents];
		}];
		[p release];
	}
	[delegate contentSelectionChanged];
}

- (void) column: (MilanColumn *)c open: (NSArray *)sel
{
	if ([sel count]) [delegate contentOpen: sel];
}

@end

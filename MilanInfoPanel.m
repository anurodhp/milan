#import "MilanInfoPanel.h"
#import "MilanIcons.h"
#include <dirent.h>
#include <sys/stat.h>
#include <pwd.h>
#include <grp.h>
#include <limits.h>
#include <stdio.h>
#include <dispatch/dispatch.h>

/* Recursive size of a tree, without following symlinks. */
static unsigned long long
tree_size(const char *path, volatile BOOL *cancel, unsigned long long *items)
{
	struct stat st;
	unsigned long long total = 0;
	if (lstat(path, &st) != 0) return 0;
	total = (unsigned long long)st.st_size;
	if (S_ISDIR(st.st_mode)) {
		DIR *d = opendir(path);
		struct dirent *de;
		char buf[PATH_MAX];
		if (!d) return total;
		while (!*cancel && (de = readdir(d))) {
			if (de->d_name[0] == '.' && (de->d_name[1] == 0 || (de->d_name[1] == '.' && de->d_name[2] == 0)))
				continue;
			snprintf(buf, sizeof buf, "%s/%s", path, de->d_name);
			(*items)++;
			total += tree_size(buf, cancel, items);
		}
		closedir(d);
	}
	return total;
}

static NSMutableDictionary *open_panels;	/* path -> MilanInfoPanel */

@implementation MilanInfoPanel

+ (void) showForPath: (NSString *)path
{
	MilanInfoPanel *p;
	MilanEntry *e = [MilanEntry entryForPath: path];
	if (!e) { NSBeep(); return; }
	if (!open_panels) open_panels = [[NSMutableDictionary alloc] init];
	if ((p = [open_panels objectForKey: path])) {
		[p->panel makeKeyAndOrderFront: nil];
		return;
	}
	p = [[MilanInfoPanel alloc] initWithEntry: e];
	[open_panels setObject: p forKey: path];
	[p release];
}

static NSTextField *
label(NSString *s, NSRect r, BOOL bold, NSTextAlignment al)
{
	NSTextField *t = [[[NSTextField alloc] initWithFrame: r] autorelease];
	[t setStringValue: s ? s : @""];
	[t setEditable: NO];
	[t setSelectable: YES];
	[t setBezeled: NO];
	[t setDrawsBackground: NO];
	[t setAlignment: al];
	[t setFont: bold ? [NSFont boldSystemFontOfSize: 11] : [NSFont systemFontOfSize: 11]];
	[[t cell] setLineBreakMode: NSLineBreakByTruncatingMiddle];
	return t;
}

- (id) initWithEntry: (MilanEntry *)e
{
	struct passwd *pw;
	struct group *gr;
	NSString *link = nil;
	NSMutableArray *rows = [NSMutableArray array];
	const CGFloat W = 340, rowH = 20, top = 90;
	NSUInteger i, n;
	NSView *v;
	static int cascade;

	self = [super init];
	entry = [e retain];
	pw = getpwuid(e->uid);
	gr = getgrgid(e->gid);
	if (e->isLink)
		link = [[NSFileManager defaultManager] pathContentOfSymbolicLinkAtPath: e->path];

	[rows addObject: [NSArray arrayWithObjects: @"Kind:", [e kind], nil]];
	[rows addObject: [NSArray arrayWithObjects: @"Size:", e->isDir ? @"Calculating…" :
	                  [NSString stringWithFormat: @"%@ (%llu bytes)", MilanFormatSize(e->size), e->size], nil]];
	[rows addObject: [NSArray arrayWithObjects: @"Where:", [e->path stringByDeletingLastPathComponent], nil]];
	if (link) [rows addObject: [NSArray arrayWithObjects: @"Links to:", link, nil]];
	[rows addObject: [NSArray arrayWithObjects: @"Modified:", MilanFormatDate(e->mtime), nil]];
	[rows addObject: [NSArray arrayWithObjects: @"Changed:", MilanFormatDate(e->ctime_), nil]];
	[rows addObject: [NSArray arrayWithObjects: @"Permissions:", MilanFormatMode(e->mode), nil]];
	[rows addObject: [NSArray arrayWithObjects: @"Owner:",
	                  [NSString stringWithFormat: @"%@ : %@", pw ? [NSString stringWithUTF8String: pw->pw_name] : [NSString stringWithFormat: @"%u", (unsigned)e->uid], gr ? [NSString stringWithUTF8String: gr->gr_name] : [NSString stringWithFormat: @"%u", (unsigned)e->gid]], nil]];

	n = [rows count];
	panel = (NSPanel *)[[NSWindow alloc] initWithContentRect: NSMakeRect(200 + cascade * 24, 400 - cascade * 24, W, top + n * rowH + 36)
	                                   styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
	                                     backing: NSBackingStoreBuffered defer: NO];
	cascade = (cascade + 1) % 10;
	[panel setReleasedWhenClosed: NO];
	[panel setTitle: [NSString stringWithFormat: @"%@ Info", e->name]];
	[panel setDelegate: self];
	v = [panel contentView];
	{
		CGFloat H = top + n * rowH + 36;
		NSImageView *iv = [[[NSImageView alloc] initWithFrame: NSMakeRect(16, H - 72, 56, 56)] autorelease];
		[iv setImage: [MilanIcons iconForEntry: e]];
		[iv setImageScaling: NSImageScaleProportionallyUpOrDown];
		[v addSubview: iv];
		{
			NSTextField *nm = label(e->name, NSMakeRect(82, H - 48, W - 98, 18), YES, NSLeftTextAlignment);
			[nm setSelectable: NO];
			[v addSubview: nm];
		}
		{
			NSTextField *kd = label([e kind], NSMakeRect(82, H - 66, W - 98, 16), NO, NSLeftTextAlignment);
			[kd setSelectable: NO];
			[v addSubview: kd];
		}
		for (i = 0; i < n; i++) {
			NSArray *r = [rows objectAtIndex: i];
			CGFloat y = H - top - (i + 1) * rowH + 4;
			NSTextField *val;
			[v addSubview: label([r objectAtIndex: 0], NSMakeRect(12, y, 84, 16), YES, NSRightTextAlignment)];
			val = label([r objectAtIndex: 1], NSMakeRect(104, y, W - 116, 16), NO, NSLeftTextAlignment);
			[v addSubview: val];
			if (i == 1) sizeField = val;
		}
	}
	[panel makeKeyAndOrderFront: nil];
	[panel display];

	if (e->isDir) {
		NSString *path = [e->path copy];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			unsigned long long items = 0, total;
			NSString *s;
			total = tree_size([path fileSystemRepresentation], &cancelled, &items);
			if (!cancelled) {
				s = [[NSString stringWithFormat: @"%@ (%llu bytes), %llu items", MilanFormatSize(total), total, items] retain];
				MilanRunOnMain(^{
					if (!cancelled) [sizeField setStringValue: s];
					[s release];
				});
			}
			[path release];
			[pool release];
		});
	}
	return self;
}

- (void) windowWillClose: (NSNotification *)n
{
	cancelled = YES;
	[panel setDelegate: nil];
	[open_panels removeObjectForKey: entry->path];	/* releases self */
}

- (void) dealloc
{
	[panel release]; [entry release];
	[super dealloc];
}

@end

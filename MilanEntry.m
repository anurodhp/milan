#import "MilanEntry.h"
#import "MilanTrash.h"
#include <dirent.h>
#include <errno.h>
#include <sys/stat.h>
#include <string.h>
#include <stdio.h>
#include <limits.h>
#include <dispatch/dispatch.h>

NSString *
MilanFormatSize(unsigned long long b)
{
	static const char *u[] = { "bytes", "KB", "MB", "GB", "TB" };
	double v = (double)b;
	int i = 0;
	if (b < 1000)
		return [NSString stringWithFormat: @"%llu bytes", b];
	while (v >= 1000 && i < 4) { v /= 1000; i++; }
	return [NSString stringWithFormat: @"%.1f %s", v, u[i]];
}

NSString *
MilanFormatDate(time_t t)
{
	char buf[32];
	struct tm tm;
	localtime_r(&t, &tm);
	strftime(buf, sizeof buf, "%Y-%m-%d %H:%M", &tm);
	return [NSString stringWithUTF8String: buf];
}

NSString *
MilanFormatMode(mode_t m)
{
	char s[11] = "----------";
	const char *rwx = "rwxrwxrwx";
	int i;
	if (S_ISDIR(m)) s[0] = 'd'; else if (S_ISLNK(m)) s[0] = 'l';
	for (i = 0; i < 9; i++)
		if (m & (0400 >> i)) s[i + 1] = rwx[i];
	return [NSString stringWithFormat: @"%s (%03o)", s, (unsigned)(m & 0777)];
}

@interface MilanBlockBox : NSObject
{
	void (^blk)(void);
}
- (id) initWithBlock: (void (^)(void))b;
- (void) fire;
@end

@implementation MilanBlockBox
- (id) initWithBlock: (void (^)(void))b { self = [super init]; blk = [b copy]; return self; }
- (void) fire { blk(); }
- (void) dealloc { [blk release]; [super dealloc]; }
@end

void
MilanRunOnMain(void (^block)(void))
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	MilanBlockBox *b = [[MilanBlockBox alloc] initWithBlock: block];
	[b performSelectorOnMainThread: @selector(fire) withObject: nil waitUntilDone: NO];
	[b release];
	[pool release];
}

@implementation MilanEntry

- (void) dealloc
{
	[name release]; [path release]; [kind release]; [dateString release]; [sizeString release];
	[super dealloc];
}

- (NSString *) kind
{
	if (!kind) {
		NSString *e = [name pathExtension];
		if (isApp) kind = @"Application";
		else if (isDir) kind = @"Folder";
		else if ([e length]) kind = [[e uppercaseString] stringByAppendingString: @" file"];
		else kind = @"Document";
		[kind retain];
	}
	return kind;
}

- (NSString *) dateString
{
	if (!dateString) dateString = [MilanFormatDate(mtime) retain];
	return dateString;
}

- (NSString *) sizeString
{
	if (!sizeString)
		sizeString = [(isDir ? @"--" : MilanFormatSize(size)) retain];
	return sizeString;
}

static MilanEntry *
make_entry(const char *dir, const char *cname, NSString *dirPath)
{
	char full[PATH_MAX];
	struct stat st;
	MilanEntry *e;
	snprintf(full, sizeof full, "%s/%s", dir, cname);
	if (lstat(full, &st) != 0)
		return nil;
	e = [[[MilanEntry alloc] init] autorelease];
	e->name = [[NSString alloc] initWithUTF8String: cname];
	if (!e->name) e->name = [[NSString alloc] initWithCString: cname encoding: NSISOLatin1StringEncoding];
	e->path = [[dirPath stringByAppendingPathComponent: e->name] retain];
	e->isHidden = cname[0] == '.';
	if (S_ISLNK(st.st_mode)) {
		struct stat t;
		e->isLink = YES;
		if (stat(full, &t) == 0) { e->isDir = S_ISDIR(t.st_mode); }
	} else
		e->isDir = S_ISDIR(st.st_mode);
	e->size = (unsigned long long)st.st_size;
	e->mtime = st.st_mtime;
	e->ctime_ = st.st_ctime;
	e->mode = st.st_mode;
	e->uid = st.st_uid;
	e->gid = st.st_gid;
	{
		size_t n = strlen(cname);
		e->isApp = e->isDir && n > 4 && strcasecmp(cname + n - 4, ".app") == 0;
	}
	return e;
}

+ (MilanEntry *) entryForPath: (NSString *)p
{
	NSString *dir = [p stringByDeletingLastPathComponent];
	return make_entry([dir fileSystemRepresentation],
	                  [[p lastPathComponent] fileSystemRepresentation], dir);
}

+ (void) sort: (NSMutableArray *)a key: (MilanSort)key ascending: (BOOL)asc
{
	[a sortUsingComparator: ^NSComparisonResult(MilanEntry *x, MilanEntry *y) {
		NSComparisonResult r = NSOrderedSame;
		switch (key) {
		case MilanSortSize:
			r = x->size < y->size ? NSOrderedAscending : x->size > y->size ? NSOrderedDescending : NSOrderedSame;
			break;
		case MilanSortDate:
			r = x->mtime < y->mtime ? NSOrderedAscending : x->mtime > y->mtime ? NSOrderedDescending : NSOrderedSame;
			break;
		case MilanSortKind:
			r = [[x kind] compare: [y kind]];
			break;
		default: break;
		}
		if (r == NSOrderedSame)
			r = [x->name compare: y->name options: NSCaseInsensitiveSearch | NSNumericSearch];
		return asc ? r : (NSComparisonResult)-r;
	}];
}

+ (void) loadPath: (NSString *)path showHidden: (BOOL)hidden sort: (MilanSort)key
        ascending: (BOOL)asc completion: (void (^)(NSArray *, NSString *))done
{
	NSString *p = [path copy];
	void (^cb)(NSArray *, NSString *) = [done copy];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSMutableArray *out = nil;
		NSString *err = nil;
		const char *dir = [p fileSystemRepresentation];
		DIR *d = [p isEqualToString: MilanTrashPath] ? NULL : opendir(dir);
		if ([p isEqualToString: MilanTrashPath]) {
			/* the merged Trash: every trash directory, minus the Put Back sidecars */
			NSString *td;
			out = [NSMutableArray arrayWithCapacity: 64];
			for (td in [MilanTrash trashDirectories]) {
				DIR *t = opendir([td fileSystemRepresentation]);
				struct dirent *de;
				if (!t) continue;
				while ((de = readdir(t))) {
					MilanEntry *e;
					if (de->d_name[0] == '.' && (de->d_name[1] == 0 || (de->d_name[1] == '.' && de->d_name[2] == 0)))
						continue;
					if (strcmp(de->d_name, [MilanTrashOriginsName UTF8String]) == 0 || strcmp(de->d_name, ".DS_Store") == 0)
						continue;
					if (!hidden && de->d_name[0] == '.') continue;
					if ((e = make_entry([td fileSystemRepresentation], de->d_name, td))) [out addObject: e];
				}
				closedir(t);
			}
			[self sort: out key: key ascending: asc];
		} else if (!d) {
			err = [NSString stringWithUTF8String: strerror(errno)];
		} else {
			struct dirent *de;
			out = [NSMutableArray arrayWithCapacity: 256];
			while ((de = readdir(d))) {
				MilanEntry *e;
				if (de->d_name[0] == '.' &&
				    (de->d_name[1] == 0 || (de->d_name[1] == '.' && de->d_name[2] == 0)))
					continue;
				if (!hidden && de->d_name[0] == '.')
					continue;
				if ((e = make_entry(dir, de->d_name, p)))
					[out addObject: e];
			}
			closedir(d);
			[self sort: out key: key ascending: asc];
		}
		[out retain]; [err retain];
		[pool release];
		MilanRunOnMain(^{
			cb(out, err);
			[out release]; [err release]; [p release]; [cb release];
		});
	});
}

@end

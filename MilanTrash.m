#import "MilanTrash.h"
#include <sys/stat.h>
#include <sys/mount.h>
#include <unistd.h>
#include <stdlib.h>

NSString *const MilanTrashPath = @"\001trash";
NSString *const MilanTrashOriginsName = @".milan-origins";

static NSString *homeOverride;

void
MilanSetTrashHome(NSString *dir)
{
	[homeOverride release];
	homeOverride = [dir copy];
}

static NSString *
homeTrash(void)
{
	NSString *d = homeOverride ? homeOverride : [[NSUserDefaults standardUserDefaults] stringForKey: @"MilanTrashDir"];	/* tests */
	return [d length] ? d : [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"];
}

static NSString *
volumeTrash(NSString *mount)
{
	return [[mount stringByAppendingPathComponent: @".Trashes"] stringByAppendingPathComponent:
	        [NSString stringWithFormat: @"%u", (unsigned)getuid()]];
}

BOOL
MilanPathInTrash(NSString *p)
{
	NSString *h = homeTrash();
	if ([p isEqualToString: MilanTrashPath]) return YES;
	if ([p isEqualToString: h] || [p hasPrefix: [h stringByAppendingString: @"/"]]) return YES;
	return [p rangeOfString: @"/.Trashes/"].location != NSNotFound;
}

/* The mount point of the volume holding `path` (walk up until the device changes). */
static NSString *
volumeRoot(NSString *path)
{
	struct stat st, up;
	NSString *cur = path, *parent;
	if (lstat([path fileSystemRepresentation], &st) != 0) return @"/";
	for (;;) {
		parent = [cur stringByDeletingLastPathComponent];
		if ([parent length] == 0 || [parent isEqualToString: cur]) return @"/";
		if (lstat([parent fileSystemRepresentation], &up) != 0 || up.st_dev != st.st_dev) return cur;
		cur = parent;
	}
}

static dev_t
deviceOf(NSString *p)
{
	struct stat st;
	return lstat([p fileSystemRepresentation], &st) == 0 ? st.st_dev : (dev_t)-1;
}

static NSString *
trashFor(NSString *path)
{
	NSString *home = NSHomeDirectory();
	NSString *root;
	if (deviceOf(path) == deviceOf(home)) return homeTrash();
	root = volumeRoot(path);
	return [root isEqualToString: @"/"] ? homeTrash() : volumeTrash(root);
}

static NSMutableDictionary *
readOrigins(NSString *trashDir)
{
	NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile: [trashDir stringByAppendingPathComponent: MilanTrashOriginsName]];
	return d ? [[d mutableCopy] autorelease] : [NSMutableDictionary dictionary];
}

static void
writeOrigins(NSString *trashDir, NSDictionary *d)
{
	NSString *f = [trashDir stringByAppendingPathComponent: MilanTrashOriginsName];
	if ([d count]) [d writeToFile: f atomically: YES];
	else [[NSFileManager defaultManager] removeItemAtPath: f error: NULL];
}

/* a name not taken in the trash: "name", then "name HH-MM-SS.ext", then a counter */
static NSString *
trashName(NSFileManager *fm, NSString *dir, NSString *name)
{
	NSString *ext = [name pathExtension], *base = [name stringByDeletingPathExtension], *n = name;
	time_t t = time(NULL);
	struct tm tm;
	char buf[16];
	int i = 2;
	localtime_r(&t, &tm);
	strftime(buf, sizeof buf, "%H-%M-%S", &tm);
	while ([[fm attributesOfItemAtPath: [dir stringByAppendingPathComponent: n] error: NULL] count]) {
		n = [NSString stringWithFormat: i == 2 ? @"%@ %s" : @"%@ %s %d", base, buf, i];
		if ([ext length]) n = [n stringByAppendingPathExtension: ext];
		i++;
	}
	return n;
}

@implementation MilanTrash

+ (NSArray *) trashDirectories
{
	NSMutableArray *out = [NSMutableArray array];
	NSFileManager *fm = [NSFileManager defaultManager];
	struct statfs *fs = NULL;
	int n = getfsstat(NULL, 0, MNT_NOWAIT), i;
	BOOL dir;
	[out addObject: homeTrash()];
	if (n > 0 && (fs = calloc((size_t)n, sizeof *fs)))
		n = getfsstat(fs, (int)(n * sizeof *fs), MNT_NOWAIT);
	else
		n = 0;
	for (i = 0; i < n; i++) {
		NSString *t = volumeTrash([NSString stringWithUTF8String: fs[i].f_mntonname]);
		if (![t hasPrefix: @"//"] && [fm fileExistsAtPath: t isDirectory: &dir] && dir && ![out containsObject: t])
			[out addObject: t];
	}
	free(fs);
	return out;
}

+ (void) trashPaths: (NSArray *)paths done: (MilanOpDone)done
{
	paths = [paths copy];
	MilanOpsRun(^(NSFileManager *fm, NSString **err) {
		NSString *p;
		for (p in paths) {
			NSError *e = nil;
			NSString *tdir, *name;
			NSMutableDictionary *origins;
			if (MilanPathInTrash(p)) continue;	/* already there */
			tdir = trashFor(p);
			if (![fm createDirectoryAtPath: tdir withIntermediateDirectories: YES
			                    attributes: [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 0700] forKey: NSFilePosixPermissions]
			                         error: &e]) {
				*err = [NSString stringWithFormat: @"No Trash on that volume: %@", [e localizedDescription]];
				break;
			}
			name = trashName(fm, tdir, [p lastPathComponent]);
			if (![fm moveItemAtPath: p toPath: [tdir stringByAppendingPathComponent: name] error: &e]) {
				*err = [NSString stringWithFormat: @"Could not trash %@: %@", [p lastPathComponent], [e localizedDescription]];
				break;
			}
			origins = readOrigins(tdir);
			[origins setObject: p forKey: name];
			writeOrigins(tdir, origins);
		}
	}, ^(NSString *err) { if (done) done(err); [paths release]; });
}

+ (void) putBackPaths: (NSArray *)paths done: (MilanOpDone)done
{
	paths = [paths copy];
	MilanOpsRun(^(NSFileManager *fm, NSString **err) {
		NSString *p;
		for (p in paths) {
			NSError *e = nil;
			NSString *tdir = [p stringByDeletingLastPathComponent], *name = [p lastPathComponent], *orig, *dest;
			NSMutableDictionary *origins;
			if (!MilanPathInTrash(p) || ![[tdir lastPathComponent] length]) continue;
			origins = readOrigins(tdir);
			orig = [origins objectForKey: name];
			if (!orig) {
				*err = [NSString stringWithFormat: @"Put Back: no original location recorded for %@", name];
				continue;
			}
			[fm createDirectoryAtPath: [orig stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes: nil error: NULL];
			dest = MilanUniquePath(fm, [orig stringByDeletingLastPathComponent], [orig lastPathComponent]);
			if (![fm moveItemAtPath: p toPath: dest error: &e]) {
				*err = [NSString stringWithFormat: @"Put Back %@: %@", name, [e localizedDescription]];
				continue;
			}
			[origins removeObjectForKey: name];
			writeOrigins(tdir, origins);
		}
	}, ^(NSString *err) { if (done) done(err); [paths release]; });
}

+ (BOOL) hasItems { return MilanTrashHasItems(); }

+ (void) deletePaths: (NSArray *)paths done: (MilanOpDone)done
{
	paths = [paths copy];
	MilanOpsRun(^(NSFileManager *fm, NSString **err) {
		NSString *p;
		for (p in paths) {
			NSError *e = nil;
			NSString *tdir = [p stringByDeletingLastPathComponent];
			NSMutableDictionary *origins;
			if (!MilanPathInTrash(p) || [p isEqualToString: MilanTrashPath]) continue;
			if (![fm removeItemAtPath: p error: &e] && !*err)
				*err = [NSString stringWithFormat: @"Could not delete %@: %@", [p lastPathComponent], [e localizedDescription]];
			origins = readOrigins(tdir);
			[origins removeObjectForKey: [p lastPathComponent]];
			writeOrigins(tdir, origins);
		}
	}, ^(NSString *err) { if (done) done(err); [paths release]; });
}

+ (void) emptyDone: (MilanOpDone)done
{
	MilanOpsRun(^(NSFileManager *fm, NSString **err) {
		NSString *dir, *item;
		for (dir in [MilanTrash trashDirectories])
			for (item in [fm contentsOfDirectoryAtPath: dir error: NULL]) {
				NSError *e = nil;
				if (![fm removeItemAtPath: [dir stringByAppendingPathComponent: item] error: &e] && !*err)
					*err = [NSString stringWithFormat: @"Could not delete %@: %@", item, [e localizedDescription]];
			}
	}, done);
}

@end

/* Whether any Trash has something in it; cached for half a second so drawing stays cheap. */
BOOL
MilanTrashHasItems(void)
{
	static NSTimeInterval at;
	static BOOL full;
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now - at > 0.5) {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *d, *n;
		full = NO;
		for (d in [MilanTrash trashDirectories])
			for (n in [fm contentsOfDirectoryAtPath: d error: NULL])
				if (![n isEqualToString: MilanTrashOriginsName] && ![n isEqualToString: @".DS_Store"] && ![n isEqualToString: @".gwdir"]) full = YES;
		at = now;
	}
	return full;
}

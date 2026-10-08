#import "MilanFileOps.h"
#import "MilanEntry.h"
#include <dispatch/dispatch.h>

static dispatch_queue_t
opsQueue(void)
{
	static dispatch_queue_t q;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ q = dispatch_queue_create("milan.fileops", DISPATCH_QUEUE_SERIAL); });
	return q;
}

/* "name", "name copy", "name copy 2", ... that does not exist in dir. */
static NSString *
uniquePath(NSFileManager *fm, NSString *dir, NSString *name)
{
	NSString *p = [dir stringByAppendingPathComponent: name];
	NSString *ext = [name pathExtension], *base = [name stringByDeletingPathExtension];
	int i = 1;
	while ([fm fileExistsAtPath: p] || [[fm attributesOfItemAtPath: p error: NULL] count]) {
		NSString *n = i == 1 ? [base stringByAppendingString: @" copy"]
		                     : [NSString stringWithFormat: @"%@ copy %d", base, i];
		if ([ext length]) n = [n stringByAppendingPathExtension: ext];
		p = [dir stringByAppendingPathComponent: n];
		i++;
	}
	return p;
}

static void
run(void (^work)(NSFileManager *fm, NSString **err), MilanOpDone done)
{
	void (^w)(NSFileManager *, NSString **) = [work copy];
	MilanOpDone d = [done copy];
	dispatch_async(opsQueue(), ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSString *err = nil;
		w([NSFileManager defaultManager], &err);
		[err retain];
		[pool release];
		MilanRunOnMain(^{
			if (d) d(err);
			[err release]; [w release]; [d release];
		});
	});
}

@implementation MilanFileOps

+ (void) copyPaths: (NSArray *)paths toDir: (NSString *)dir done: (MilanOpDone)done
{
	paths = [paths copy]; dir = [dir copy];
	run(^(NSFileManager *fm, NSString **err) {
		NSString *p;
		for (p in paths) {
			NSError *e = nil;
			NSString *dst = uniquePath(fm, dir, [p lastPathComponent]);
			if (![fm copyItemAtPath: p toPath: dst error: &e]) {
				*err = [NSString stringWithFormat: @"Could not copy %@: %@", [p lastPathComponent],
				        [e localizedDescription]];
				break;
			}
		}
	}, ^(NSString *err) { if (done) done(err); [paths release]; [dir release]; });
}

+ (void) movePaths: (NSArray *)paths toDir: (NSString *)dir done: (MilanOpDone)done
{
	paths = [paths copy]; dir = [dir copy];
	run(^(NSFileManager *fm, NSString **err) {
		NSString *p;
		for (p in paths) {
			NSError *e = nil;
			if ([[p stringByDeletingLastPathComponent] isEqualToString: dir])
				continue;
			if (![fm moveItemAtPath: p toPath: uniquePath(fm, dir, [p lastPathComponent]) error: &e]) {
				*err = [NSString stringWithFormat: @"Could not move %@: %@", [p lastPathComponent],
				        [e localizedDescription]];
				break;
			}
		}
	}, ^(NSString *err) { if (done) done(err); [paths release]; [dir release]; });
}

+ (void) trashPaths: (NSArray *)paths done: (MilanOpDone)done
{
	NSString *trash = [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"];
	[[NSFileManager defaultManager] createDirectoryAtPath: trash withIntermediateDirectories: YES
	                                           attributes: nil error: NULL];
	[self movePaths: paths toDir: trash done: done];
}

+ (void) newFolderIn: (NSString *)dir done: (void (^)(NSString *, NSString *))done
{
	__block NSString *made = nil;
	dir = [dir copy];
	run(^(NSFileManager *fm, NSString **err) {
		NSError *e = nil;
		NSString *p = uniquePath(fm, dir, @"untitled folder");
		if ([fm createDirectoryAtPath: p withIntermediateDirectories: NO attributes: nil error: &e])
			made = [p retain];
		else
			*err = [e localizedDescription];
	}, ^(NSString *err) { done(made, err); [made release]; [dir release]; });
}

+ (void) renamePath: (NSString *)path to: (NSString *)newName done: (MilanOpDone)done
{
	path = [path copy]; newName = [newName copy];
	run(^(NSFileManager *fm, NSString **err) {
		NSError *e = nil;
		NSString *dst = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent: newName];
		if ([fm fileExistsAtPath: dst])
			*err = @"An item with that name already exists.";
		else if (![fm moveItemAtPath: path toPath: dst error: &e])
			*err = [e localizedDescription];
	}, ^(NSString *err) { if (done) done(err); [path release]; [newName release]; });
}

@end

/* MilanEntry: one directory entry, stat'ed once on a background queue. */
#import <Foundation/Foundation.h>
#include <sys/types.h>

typedef enum { MilanSortName, MilanSortSize, MilanSortDate, MilanSortKind } MilanSort;

@interface MilanEntry : NSObject
{
@public
	NSString *name, *path;
	unsigned long long size;
	time_t mtime, ctime_;
	mode_t mode;
	uid_t uid;
	gid_t gid;
	BOOL isDir, isLink, isApp, isHidden;
	NSString *kind, *dateString, *sizeString;	/* lazy */
}
- (NSString *) kind;
- (NSString *) dateString;
- (NSString *) sizeString;

/* Reads `path` on a global queue, sorts, and calls `done` on the main queue
 * (entries nil and error set on failure). */
+ (void) loadPath: (NSString *)path showHidden: (BOOL)hidden sort: (MilanSort)key
        ascending: (BOOL)asc completion: (void (^)(NSArray *entries, NSString *error))done;
+ (void) sort: (NSMutableArray *)entries key: (MilanSort)key ascending: (BOOL)asc;
/* Stats one path synchronously (nil if it does not exist). */
+ (MilanEntry *) entryForPath: (NSString *)path;
@end

/* Runs a block on the main thread. Use this, not dispatch_async(main queue), from background work:
 * GNUstep's run loop is not woken reliably by main-queue blocks, so completions arrive late. */
void MilanRunOnMain(void (^block)(void));

NSString *MilanFormatSize(unsigned long long bytes);
NSString *MilanFormatDate(time_t t);
NSString *MilanFormatMode(mode_t mode);

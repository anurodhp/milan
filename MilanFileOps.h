/* MilanFileOps: file operations on a serial GCD queue; completions run on the main queue. */
#import <Foundation/Foundation.h>

typedef void (^MilanOpDone)(NSString *error);

@interface MilanFileOps : NSObject
+ (void) copyPaths: (NSArray *)paths toDir: (NSString *)dir done: (MilanOpDone)done;
+ (void) movePaths: (NSArray *)paths toDir: (NSString *)dir done: (MilanOpDone)done;
+ (void) newFolderIn: (NSString *)dir done: (void (^)(NSString *createdPath, NSString *error))done;
+ (void) renamePath: (NSString *)path to: (NSString *)newName done: (MilanOpDone)done;
@end

/* Runs `work` on the serial file-operation queue, then `done(error)` on the main thread. */
void MilanOpsRun(void (^work)(NSFileManager *fm, NSString **err), MilanOpDone done);
/* dir/name, or dir/"name copy", "name copy 2", ... if that exists. */
NSString *MilanUniquePath(NSFileManager *fm, NSString *dir, NSString *name);

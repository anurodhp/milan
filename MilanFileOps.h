/* MilanFileOps: file operations on a serial GCD queue; completions run on the main queue. */
#import <Foundation/Foundation.h>

typedef void (^MilanOpDone)(NSString *error);

@interface MilanFileOps : NSObject
+ (void) copyPaths: (NSArray *)paths toDir: (NSString *)dir done: (MilanOpDone)done;
+ (void) movePaths: (NSArray *)paths toDir: (NSString *)dir done: (MilanOpDone)done;
+ (void) trashPaths: (NSArray *)paths done: (MilanOpDone)done;
+ (void) newFolderIn: (NSString *)dir done: (void (^)(NSString *createdPath, NSString *error))done;
+ (void) renamePath: (NSString *)path to: (NSString *)newName done: (MilanOpDone)done;
@end

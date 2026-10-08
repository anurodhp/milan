/* MilanLauncher: starts applications and opens documents without the workspace manager.
 * NSWorkspace -launchApplication:/-openFile: hand the request to GWorkspace (GNUstep's default workspace
 * application), which is what Milan replaces; it launched GWorkspace and showed "Application seems to have hung".
 * Handlers come from the apps themselves: NSTypes in Info-gnustep.plist (NSUnixExtensions, NSRole). */
#import <Foundation/Foundation.h>

@interface MilanLauncher : NSObject
/* Starts the app bundle, optionally asking it to open a file. NO and *err set on failure. */
+ (BOOL) launchApplication: (NSString *)appPath openFile: (NSString *)file error: (NSString **)err;
/* Opens a document with its default application (the user's choice, else the first app that declares it). */
+ (BOOL) openFile: (NSString *)path error: (NSString **)err;
/* App bundle paths that declare the file's extension, default first. */
+ (NSArray *) applicationsForFile: (NSString *)path;
+ (NSString *) defaultApplicationForFile: (NSString *)path;
+ (void) setDefaultApplication: (NSString *)appPath forExtension: (NSString *)ext;
+ (NSString *) displayNameForApplication: (NSString *)appPath;
@end

/* MilanPrefs: the Preferences window and the settings it edits (all in NSUserDefaults). */
#import <AppKit/AppKit.h>

@interface MilanPrefs : NSObject
+ (void) show;
/* The folder File > New Window opens: Home (default), Desktop, Documents, Computer, or the path in
 * MilanNewWindowPath. */
+ (NSString *) newWindowPath;
@end

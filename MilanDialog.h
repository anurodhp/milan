/* MilanDialog: confirmation and text-entry dialogs drawn as overlays on a window's content area (no modal panels:
 * Eau shows NSAlerts "non-modally", i.e. without waiting for an answer, which is unsafe for "Empty the Trash?"). */
#import <AppKit/AppKit.h>

typedef void (^MilanDialogDone)(BOOL ok, NSString *text);

@interface MilanDialog : NSObject
/* textDefault nil: a plain confirmation; otherwise a text field pre-filled with it. Esc cancels, Return accepts. */
+ (void) showOver: (NSView *)area title: (NSString *)title message: (NSString *)message
      textDefault: (NSString *)textDefault okTitle: (NSString *)ok completion: (MilanDialogDone)done;
+ (BOOL) isActive;
@end

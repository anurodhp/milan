/* MilanIcons: icon lookup. File-type icons are Lucide glyphs rendered by tools/make_icons.sh
 * (icons/ft-*.tiff in the app's Resources), picked by folder/app/extension and cached; no NSWorkspace
 * round trip per file. Main thread only. */
#import <AppKit/AppKit.h>
#import "MilanEntry.h"

@interface MilanIcons : NSObject
+ (NSImage *) iconForEntry: (MilanEntry *)e;
/* Thumbnails of PNG/TIFF/JPEG files: cached, decoded in the background (JPEG) or one at a time on the main thread
 * (PNG/TIFF), and announced with MilanThumbnailReady so views redraw. nil until the thumbnail exists. */
+ (NSImage *) thumbnailForEntry: (MilanEntry *)e;
extern NSString *const MilanThumbnailReady;

/* A named Resources image ("tb-back-normal", "ft-folder"), cached; nil if missing. */
+ (NSImage *) imageNamed: (NSString *)name;
@end

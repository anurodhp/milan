/* MilanWallpaper: the desktop background (a colour, optionally an image placed by a fill mode), the view
 * that draws it, and the "Desktop Background" panel (right-click the desktop > Change Background). */
#import <AppKit/AppKit.h>

extern NSString *const MilanWallpaperChanged;
BOOL MilanIsPictureExtension(NSString *ext);	/* png tif tiff jpg jpeg */

typedef enum { MilanFillFill, MilanFillFit, MilanFillStretch, MilanFillCenter, MilanFillTile } MilanFill;

@interface MilanWallpaper : NSObject
{
	NSString *imagePath;
	NSColor *color;
	MilanFill fill;
	NSImage *cache;		/* the picture already placed on a canvas of cacheSize */
	NSSize cacheSize;
}
+ (MilanWallpaper *) shared;
- (NSString *) imagePath;	/* nil: a plain colour */
- (NSColor *) color;
- (MilanFill) fill;
- (void) setImagePath: (NSString *)p fill: (MilanFill)f color: (NSColor *)c;	/* saves and notifies */
/* Draws the part `dirty` of a canvas of size `size`. */
- (void) drawDirty: (NSRect)dirty ofSize: (NSSize)size;
/* The wallpapers shipped in Resources plus PNG/TIFF files in ~/Pictures. */
+ (NSArray *) availablePictures;
@end

/* Draws the wallpaper; the desktop icons are a subview. */
@interface MilanDesktopView : NSView
@end

@interface MilanWallpaperPanel : NSObject
+ (void) show;
@end

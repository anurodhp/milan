/* MilanImage: loads a picture from a file. PNG and TIFF go through NSImage (gnustep-gui: libpng, libtiff); JPEG is
 * decoded here with libjpeg-turbo (libjpeg.62.dylib, tools/userland_staging/build_libjpeg.sh) so it works with the
 * system's gnustep-gui, which is built without JPEG. Big JPEGs are decoded at 1/2, 1/4 or 1/8 size (libjpeg's DCT
 * scaling) so a camera photo does not cost tens of megabytes on a Pi. */
#import <AppKit/AppKit.h>

NSImage *MilanLoadImage(NSString *path);	/* nil if unreadable */

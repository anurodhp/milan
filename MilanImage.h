/* MilanImage: loads a picture from a file. PNG and TIFF go through NSImage (gnustep-gui: libpng, libtiff); JPEG is
 * decoded here with libjpeg-turbo (libjpeg.62.dylib, tools/userland_staging/build_libjpeg.sh) so it works with the
 * system's gnustep-gui, which is built without JPEG. Big JPEGs are decoded at 1/2, 1/4 or 1/8 size (libjpeg's DCT
 * scaling) so a camera photo does not cost tens of megabytes on a Pi. */
#import <AppKit/AppKit.h>

NSImage *MilanLoadImage(NSString *path);	/* nil if unreadable */

/* Decodes a JPEG at a reduced size (the largest 1/2, 1/4, 1/8 DCT scale that keeps both sides >= maxDim) into a malloc'd
 * RGB buffer (3 bytes per pixel); caller frees. NULL on failure. Safe to call from a background thread. */
unsigned char *MilanJPEGPixels(NSString *path, int maxDim, int *width, int *height);

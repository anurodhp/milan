/* MilanRootPixmap: publishes the desktop wallpaper as the root window's background pixmap property
 * (_XROOTPMAP_ID / ESETROOT_PMAP_ID, the convention Eterm, xcompmgr, panels and Naples use for pseudo-transparency).
 * There is no compositing manager on this stack, so translucent bars (Naples) blend over this pixmap instead.
 * The pixmap belongs to a private X connection that stays open for the life of the process. */
#import <AppKit/AppKit.h>

void MilanPublishRootPixmap(NSImage *canvas, NSSize size);	/* size must be the screen size; any other size is ignored */

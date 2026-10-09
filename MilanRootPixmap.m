#import "MilanRootPixmap.h"
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <stdlib.h>

static int
ignoreXError(Display *d, XErrorEvent *e)
{
	return 0;
}

void
MilanPublishRootPixmap(NSImage *canvas, NSSize size)
{
	static Display *dpy;
	static Pixmap pix;
	NSBitmapImageRep *rep;
	NSData *tiff;
	int w = (int)size.width, h = (int)size.height, x, y, spp, bpr, depth, screen;
	const unsigned char *src;
	unsigned char *dst;
	XImage *img;
	GC gc;
	Window root;
	Atom prop;
	if (!canvas || w <= 0 || h <= 0) return;
	if (!dpy) {
		XSetErrorHandler(ignoreXError);
		if (!(dpy = XOpenDisplay(NULL))) return;
	}
	if (w != DisplayWidth(dpy, DefaultScreen(dpy)) || h != DisplayHeight(dpy, DefaultScreen(dpy))) return;
	screen = DefaultScreen(dpy);
	depth = DefaultDepth(dpy, screen);
	if (depth != 24 && depth != 32) return;
	/* pixels top-down, via TIFF so the row order does not depend on how the canvas was drawn */
	tiff = [canvas TIFFRepresentation];
	rep = tiff ? [NSBitmapImageRep imageRepWithData: tiff] : nil;
	if (!rep || [rep pixelsWide] != w || [rep pixelsHigh] != h || [rep bitsPerSample] != 8) return;
	spp = (int)[rep samplesPerPixel];
	bpr = (int)[rep bytesPerRow];
	if (spp < 3 || ![rep bitmapData]) return;
	dst = malloc((size_t)w * h * 4);
	if (!dst) return;
	for (y = 0; y < h; y++) {
		src = [rep bitmapData] + (size_t)y * bpr;
		for (x = 0; x < w; x++, src += spp) {
			unsigned char *d = dst + ((size_t)y * w + x) * 4;
			d[0] = src[2]; d[1] = src[1]; d[2] = src[0]; d[3] = 0;	/* little-endian 0x00RRGGBB */
		}
	}
	root = RootWindow(dpy, screen);
	if (pix) XFreePixmap(dpy, pix);
	pix = XCreatePixmap(dpy, root, w, h, depth);
	img = XCreateImage(dpy, DefaultVisual(dpy, screen), depth, ZPixmap, 0, (char *)dst, w, h, 32, w * 4);
	if (!img) { free(dst); return; }
	gc = XCreateGC(dpy, pix, 0, NULL);
	XPutImage(dpy, pix, gc, img, 0, 0, 0, 0, w, h);
	XFreeGC(dpy, gc);
	XDestroyImage(img);	/* frees dst */
	prop = XInternAtom(dpy, "_XROOTPMAP_ID", False);
	XChangeProperty(dpy, root, prop, XA_PIXMAP, 32, PropModeReplace, (unsigned char *)&pix, 1);
	prop = XInternAtom(dpy, "ESETROOT_PMAP_ID", False);
	XChangeProperty(dpy, root, prop, XA_PIXMAP, 32, PropModeReplace, (unsigned char *)&pix, 1);
	XFlush(dpy);
}

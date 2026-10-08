/* svg2png: rasterise an SVG to a transparent PNG with AppKit's own SVG support (macOS host tool).
 * Usage: svg2png in.svg out.png pixels */
#import <AppKit/AppKit.h>
int
main(int argc, char **argv)
{
	@autoreleasepool {
		NSImage *img;
		NSBitmapImageRep *rep;
		int px;
		if (argc != 4) return 2;
		px = atoi(argv[3]);
		img = [[NSImage alloc] initWithContentsOfFile: [NSString stringWithUTF8String: argv[1]]];
		if (!img) { fprintf(stderr, "cannot load %s\n", argv[1]); return 1; }
		rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: px pixelsHigh: px
		    bitsPerSample: 8 samplesPerPixel: 4 hasAlpha: YES isPlanar: NO
		    colorSpaceName: NSDeviceRGBColorSpace bytesPerRow: 0 bitsPerPixel: 32];
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext: [NSGraphicsContext graphicsContextWithBitmapImageRep: rep]];
		[[NSColor clearColor] set];
		NSRectFill(NSMakeRect(0, 0, px, px));
		[img drawInRect: NSMakeRect(0, 0, px, px) fromRect: NSZeroRect operation: NSCompositingOperationSourceOver fraction: 1.0];
		[NSGraphicsContext restoreGraphicsState];
		[[rep representationUsingType: NSBitmapImageFileTypePNG properties: @{}] writeToFile: [NSString stringWithUTF8String: argv[2]] atomically: YES];
	}
	return 0;
}

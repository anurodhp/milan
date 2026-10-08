#import "MilanIcons.h"
#import "MilanTrash.h"
#import "MilanImage.h"
#import "MilanWallpaper.h"
#include <dispatch/dispatch.h>

static NSDictionary *
extensionKinds(void)
{
	static NSDictionary *d;
	if (!d) {
		NSMutableDictionary *m = [NSMutableDictionary dictionary];
		struct { const char *kind, *exts; } t[] = {
			{ "text", "txt md rtf log csv tsv pdf doc docx odt tex rst nfo" },
			{ "code", "c h m mm cc cpp hpp cxx py rb js ts json xml html htm css sh bash zsh pl lua swift go rs java s asm plist yaml yml toml make mk cmake" },
			{ "image", "png jpg jpeg gif tif tiff bmp svg ico xpm webp heic icns" },
			{ "audio", "mp3 wav flac ogg aac m4a aiff opus" },
			{ "video", "mp4 mkv avi mov webm m4v mpg mpeg" },
			{ "archive", "zip tar gz tgz bz2 xz 7z rar dmg iso pkg deb" },
			{ "config", "conf cfg ini rc db dylib so a o macho" },
			{ "exec", "command tool" },
		};
		unsigned i;
		for (i = 0; i < sizeof t / sizeof t[0]; i++) {
			NSString *e, *kind = [NSString stringWithUTF8String: t[i].kind];
			for (e in [[NSString stringWithUTF8String: t[i].exts] componentsSeparatedByString: @" "])
				[m setObject: kind forKey: e];
		}
		d = [m retain];
	}
	return d;
}

NSString *const MilanThumbnailReady = @"MilanThumbnailReady";

#define THUMB 96
#define THUMB_CACHE_MAX 600

static NSMutableDictionary *thumbCache;		/* path -> NSImage (or NSNull while pending / unreadable) */
static NSMutableArray *thumbOrder;		/* LRU order of cache keys */
static NSMutableArray *pngQueue;		/* paths waiting for a main-thread decode */
static BOOL thumbPumpScheduled;

/* a THUMBxTHUMB canvas with the picture aspect-fit and a hairline frame */
static NSImage *
thumbFromImage(NSImage *src)
{
	NSSize s = [src size];
	CGFloat k, w, h;
	NSImage *t;
	if (s.width <= 0 || s.height <= 0) return nil;
	k = MIN((THUMB - 4) / s.width, (THUMB - 4) / s.height);
	w = floor(s.width * k); h = floor(s.height * k);
	t = [[[NSImage alloc] initWithSize: NSMakeSize(THUMB, THUMB)] autorelease];
	[t lockFocus];
	[[NSColor colorWithCalibratedWhite: 1 alpha: 1] set];
	NSRectFill(NSMakeRect((THUMB - w) / 2 - 1, (THUMB - h) / 2 - 1, w + 2, h + 2));
	[src drawInRect: NSMakeRect((THUMB - w) / 2, (THUMB - h) / 2, w, h) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
	[[NSColor colorWithCalibratedWhite: 0.55 alpha: 1] set];
	NSFrameRect(NSMakeRect((THUMB - w) / 2 - 1, (THUMB - h) / 2 - 1, w + 2, h + 2));
	[t unlockFocus];
	return t;
}

static void
thumbStore(NSString *path, NSImage *img)
{
	[thumbCache setObject: img ? (id)img : (id)[NSNull null] forKey: path];
	[thumbOrder removeObject: path];
	[thumbOrder addObject: path];
	while ([thumbOrder count] > THUMB_CACHE_MAX) { [thumbCache removeObjectForKey: [thumbOrder objectAtIndex: 0]]; [thumbOrder removeObjectAtIndex: 0]; }
	[[NSNotificationCenter defaultCenter] postNotificationName: MilanThumbnailReady object: nil];
}

@interface MilanThumbPump : NSObject
+ (void) pump;
@end

@implementation MilanThumbPump
/* one PNG/TIFF per turn of the run loop so scrolling and clicks stay responsive */
+ (void) pump
{
	NSString *p;
	thumbPumpScheduled = NO;
	if (![pngQueue count]) return;
	p = [[pngQueue objectAtIndex: 0] retain];
	[pngQueue removeObjectAtIndex: 0];
	{
		NSImage *src = MilanLoadImage(p);
		thumbStore(p, src ? thumbFromImage(src) : nil);
	}
	[p release];
	if ([pngQueue count]) { thumbPumpScheduled = YES; [self performSelector: @selector(pump) withObject: nil afterDelay: 0.03]; }
}
@end

@implementation MilanIcons

+ (NSImage *) thumbnailForEntry: (MilanEntry *)e
{
	id c;
	NSString *x;
	if (e->isDir || e->size > 24 * 1024 * 1024) return nil;
	x = [[e->name pathExtension] lowercaseString];
	if (!MilanIsPictureExtension(x)) return nil;
	if (!thumbCache) { thumbCache = [[NSMutableDictionary alloc] init]; thumbOrder = [[NSMutableArray alloc] init]; pngQueue = [[NSMutableArray alloc] init]; }
	if ((c = [thumbCache objectForKey: e->path])) return c == [NSNull null] ? nil : c;
	[thumbCache setObject: [NSNull null] forKey: e->path];	/* pending */
	if ([x isEqualToString: @"jpg"] || [x isEqualToString: @"jpeg"]) {
		NSString *p = [e->path copy];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			int w = 0, h = 0;
			unsigned char *px = MilanJPEGPixels(p, THUMB, &w, &h);
			MilanRunOnMain(^{
				NSImage *t = nil;
				if (px) {
					NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL pixelsWide: w pixelsHigh: h
					    bitsPerSample: 8 samplesPerPixel: 3 hasAlpha: NO isPlanar: NO colorSpaceName: NSDeviceRGBColorSpace
					    bytesPerRow: w * 3 bitsPerPixel: 24] autorelease];
					NSImage *img = [[[NSImage alloc] initWithSize: NSMakeSize(w, h)] autorelease];
					memcpy([rep bitmapData], px, (size_t)w * h * 3);
					[img addRepresentation: rep];
					t = thumbFromImage(img);
					free(px);
				}
				thumbStore(p, t);
				[p release];
			});
		});
	} else {
		[pngQueue addObject: e->path];
		if (!thumbPumpScheduled) { thumbPumpScheduled = YES; [MilanThumbPump performSelector: @selector(pump) withObject: nil afterDelay: 0.05]; }
	}
	return nil;
}

+ (NSImage *) imageNamed: (NSString *)name
{
	static NSMutableDictionary *cache;
	id img;
	if (!cache) cache = [[NSMutableDictionary alloc] init];
	if ((img = [cache objectForKey: name]))
		return img == [NSNull null] ? nil : img;
	{
		NSString *p = [[NSBundle mainBundle] pathForResource: name ofType: @"tiff"];
		img = p ? [[[NSImage alloc] initWithContentsOfFile: p] autorelease] : nil;
	}
	[cache setObject: img ? img : (id)[NSNull null] forKey: name];
	return img;
}

+ (NSImage *) iconForEntry: (MilanEntry *)e
{
	NSString *kind;
	NSImage *img;
	if ([e->path isEqualToString: MilanTrashPath]) {
		/* the Eau theme's own recycler images, as the sidebar and GWorkspace's dock use */
		img = [NSImage imageNamed: MilanTrashHasItems() ? @"common_RecyclerFull" : @"common_RecyclerEmpty"];
		if (img) return img;
		return [self imageNamed: @"ft-trash"];
	}
	if (e->isVolume) return [self imageNamed: @"ft-disk"];
	if (!e->isDir && (img = [self thumbnailForEntry: e])) return img;
	if (e->isApp) {
		static NSMutableDictionary *appIcons;
		id cached;
		if (!appIcons) appIcons = [[NSMutableDictionary alloc] init];
		if ((cached = [appIcons objectForKey: e->path]))
			return cached == [NSNull null] ? [self imageNamed: @"ft-app"] : cached;
		{
			NSBundle *b = [NSBundle bundleWithPath: e->path];
			NSDictionary *info = [b infoDictionary];
			NSString *f = [info objectForKey: @"NSIcon"], *p = nil;
			NSImage *ai = nil;
			if (!f) f = [info objectForKey: @"CFBundleIconFile"];
			if ([f length]) p = [b pathForResource: [f stringByDeletingPathExtension] ofType: [[f pathExtension] length] ? [f pathExtension] : nil];
			if (p) ai = [[[NSImage alloc] initWithContentsOfFile: p] autorelease];
			[appIcons setObject: ai ? (id)ai : (id)[NSNull null] forKey: e->path];
			if (ai) return ai;
		}
		kind = @"app";
	} else if (e->isDir) {
		kind = @"folder";
	} else {
		kind = [extensionKinds() objectForKey: [[e->name pathExtension] lowercaseString]];
		if (!kind) kind = (e->mode & 0111) ? @"exec" : @"file";
	}
	img = [self imageNamed: [@"ft-" stringByAppendingString: kind]];
	return img ? img : [self imageNamed: @"ft-file"];
}

@end

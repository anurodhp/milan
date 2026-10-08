#import "MilanIcons.h"

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

@implementation MilanIcons

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
	if (e->isApp) kind = @"app";
	else if (e->isDir) kind = @"folder";
	else {
		kind = [extensionKinds() objectForKey: [[e->name pathExtension] lowercaseString]];
		if (!kind) kind = (e->mode & 0111) ? @"exec" : @"file";
	}
	img = [self imageNamed: [@"ft-" stringByAppendingString: kind]];
	return img ? img : [self imageNamed: @"ft-file"];
}

@end

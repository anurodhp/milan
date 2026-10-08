#import "MilanIcons.h"

@implementation MilanIcons

+ (NSImage *) iconForEntry: (MilanEntry *)e
{
	static NSMutableDictionary *cache;
	NSString *key;
	NSImage *img;
	if (!cache) cache = [[NSMutableDictionary alloc] init];
	if (e->isApp) key = e->path;
	else if (e->isDir) key = @"\001dir";
	else {
		key = [e->name pathExtension];
		key = [key length] ? [key lowercaseString] : @"\001file";
	}
	if ((img = [cache objectForKey: key]))
		return img;
	{
		NSWorkspace *ws = [NSWorkspace sharedWorkspace];
		if (e->isApp) img = [ws iconForFile: e->path];
		else if (e->isDir) img = [ws iconForFile: e->path];
		else if ([key isEqualToString: @"\001file"]) img = [ws iconForFileType: @""];
		else img = [ws iconForFileType: key];
	}
	if (img) [cache setObject: img forKey: key];
	return img;
}

@end

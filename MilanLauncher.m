#import "MilanLauncher.h"

static NSString *const kHandlers = @"MilanFileHandlers";	/* { extension: app path } chosen by the user */

static NSMutableDictionary *registry;	/* extension -> [app paths], editors first */
static NSMutableArray *running;		/* NSTasks we started (kept so they are reaped) */

static NSArray *
appDirectories(void)
{
	return [NSArray arrayWithObjects: @"/Applications", [NSHomeDirectory() stringByAppendingPathComponent: @"Applications"],
	        @"/usr/GNUstep/System/Applications", @"/usr/GNUstep/Local/Applications", nil];
}

static NSDictionary *
infoFor(NSString *app)
{
	NSString *p = [app stringByAppendingPathComponent: @"Resources/Info-gnustep.plist"];
	NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile: p];
	if (!d) d = [[NSBundle bundleWithPath: app] infoDictionary];
	return d;
}

static void
scan(void)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *dir, *n;
	NSMutableDictionary *editors = [NSMutableDictionary dictionary], *viewers = [NSMutableDictionary dictionary];
	NSMutableSet *seen = [NSMutableSet set];
	registry = [[NSMutableDictionary alloc] init];
	for (dir in appDirectories())
		for (n in [[fm contentsOfDirectoryAtPath: dir error: NULL] sortedArrayUsingSelector: @selector(compare:)]) {
			NSString *app, *e;
			NSDictionary *t, *info;
			if (![n hasSuffix: @".app"]) continue;
			app = [dir stringByAppendingPathComponent: n];
			if ([seen containsObject: [app stringByResolvingSymlinksInPath]]) continue;	/* the same bundle reached twice */
			[seen addObject: [app stringByResolvingSymlinksInPath]];
			info = infoFor(app);
			for (t in [info objectForKey: @"NSTypes"]) {
				NSString *role = [t objectForKey: @"NSRole"];
				NSMutableDictionary *into = [role isEqualToString: @"Viewer"] ? viewers : editors;
				for (e in [t objectForKey: @"NSUnixExtensions"]) {
					NSMutableArray *a = [into objectForKey: [e lowercaseString]];
					if (!a) { a = [NSMutableArray array]; [into setObject: a forKey: [e lowercaseString]]; }
					if (![a containsObject: app]) [a addObject: app];
				}
			}
		}
	for (NSString *e in [editors allKeys]) [registry setObject: [[[editors objectForKey: e] mutableCopy] autorelease] forKey: e];
	for (NSString *e in [viewers allKeys]) {
		NSMutableArray *a = [registry objectForKey: e];
		NSString *app;
		if (!a) { a = [NSMutableArray array]; [registry setObject: a forKey: e]; }
		for (app in [viewers objectForKey: e]) if (![a containsObject: app]) [a addObject: app];
	}
}

@implementation MilanLauncher

+ (NSString *) displayNameForApplication: (NSString *)appPath
{
	NSString *n = [[infoFor(appPath) objectForKey: @"ApplicationName"] description];
	return [n length] ? n : [[appPath lastPathComponent] stringByDeletingPathExtension];
}

+ (NSArray *) applicationsForFile: (NSString *)path
{
	NSString *e = [[path pathExtension] lowercaseString], *user;
	NSMutableArray *a;
	if (!registry) scan();
	a = [[[registry objectForKey: e] mutableCopy] autorelease];
	if (!a) return [NSArray array];
	user = [[[NSUserDefaults standardUserDefaults] dictionaryForKey: kHandlers] objectForKey: e];
	if (user && [a containsObject: user]) { [a removeObject: user]; [a insertObject: user atIndex: 0]; }
	return a;
}

+ (NSString *) defaultApplicationForFile: (NSString *)path
{
	return [[self applicationsForFile: path] firstObject];
}

+ (void) setDefaultApplication: (NSString *)appPath forExtension: (NSString *)ext
{
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *m = [[[d dictionaryForKey: kHandlers] mutableCopy] autorelease];
	if (!m) m = [NSMutableDictionary dictionary];
	[m setObject: appPath forKey: [ext lowercaseString]];
	[d setObject: m forKey: kHandlers];
	[d synchronize];
}

+ (BOOL) launchApplication: (NSString *)appPath openFile: (NSString *)file error: (NSString **)err
{
	NSBundle *b = [NSBundle bundleWithPath: appPath];
	NSString *exe = [b executablePath];
	NSTask *t;
	if (![exe length] || ![[NSFileManager defaultManager] isExecutableFileAtPath: exe])
		exe = [appPath stringByAppendingPathComponent: [[appPath lastPathComponent] stringByDeletingPathExtension]];
	if (![[NSFileManager defaultManager] isExecutableFileAtPath: exe]) {
		if (err) *err = [NSString stringWithFormat: @"%@ cannot be started: no executable.", [[appPath lastPathComponent] stringByDeletingPathExtension]];
		return NO;
	}
	t = [[[NSTask alloc] init] autorelease];
	[t setLaunchPath: exe];
	if (file) [t setArguments: [NSArray arrayWithObjects: @"-NSOpen", file, nil]];
	[t setCurrentDirectoryPath: file ? [file stringByDeletingLastPathComponent] : NSHomeDirectory()];
	[t setStandardOutput: [NSFileHandle fileHandleWithNullDevice]];
	[t setStandardError: [NSFileHandle fileHandleWithNullDevice]];
	NS_DURING
		[t launch];
	NS_HANDLER
		if (err) *err = [NSString stringWithFormat: @"%@ could not be started.", [[appPath lastPathComponent] stringByDeletingPathExtension]];
		return NO;
	NS_ENDHANDLER
	if (!running) running = [[NSMutableArray alloc] init];
	[running addObject: t];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(taskEnded:)
	    name: NSTaskDidTerminateNotification object: t];
	return YES;
}

+ (void) taskEnded: (NSNotification *)n
{
	[[NSNotificationCenter defaultCenter] removeObserver: self name: NSTaskDidTerminateNotification object: [n object]];
	[running removeObject: [n object]];
}

+ (BOOL) openFile: (NSString *)path error: (NSString **)err
{
	NSString *app = [self defaultApplicationForFile: path];
	if (!app) {
		if (err) *err = [NSString stringWithFormat: @"No application is registered to open %@ files.",
		                 [[path pathExtension] length] ? [@"." stringByAppendingString: [path pathExtension]] : @"these"];
		return NO;
	}
	return [self launchApplication: app openFile: path error: err];
}

@end

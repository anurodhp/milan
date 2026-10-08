#import "MilanText.h"

static BOOL
isRTL(unichar c)
{
	return (c >= 0x0590 && c <= 0x08FF) || (c >= 0xFB1D && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF);
}

static NSFont *
fallbackFor(NSFont *base)
{
	static NSMutableDictionary *cache;
	NSNumber *key = [NSNumber numberWithDouble: [base pointSize]];
	NSFont *f;
	if (!cache) cache = [[NSMutableDictionary alloc] init];
	if ((f = [cache objectForKey: key])) return f;
	f = [NSFont fontWithName: @"DejaVuSans" size: [base pointSize]];
	if (!f) f = [NSFont fontWithName: @"DejaVu Sans" size: [base pointSize]];
	if (f) [cache setObject: f forKey: key];
	return f;
}

NSAttributedString *
MilanDisplayString(NSString *s, NSDictionary *attrs)
{
	NSFont *base = [attrs objectForKey: NSFontAttributeName];
	NSCharacterSet *have, *fbSet;
	NSFont *fb;
	NSUInteger i, n = [s length], start = 0;
	NSMutableAttributedString *out;
	BOOL any = NO;
	if (!base || n == 0) return [[[NSAttributedString alloc] initWithString: s ? s : @"" attributes: attrs] autorelease];
	have = [base coveredCharacterSet];
	for (i = 0; i < n; i++) {
		unichar c = [s characterAtIndex: i];
		if (c >= 0x80 && have && ![have characterIsMember: c]) { any = YES; break; }
	}
	if (!any) return [[[NSAttributedString alloc] initWithString: s attributes: attrs] autorelease];
	fb = fallbackFor(base);
	fbSet = [fb coveredCharacterSet];
	out = [[[NSMutableAttributedString alloc] init] autorelease];
	/* split into runs: ordinary / fallback-font; RTL runs are reversed */
	while (start < n) {
		unichar c = [s characterAtIndex: start];
		BOOL needs = c >= 0x80 && have && ![have characterIsMember: c];
		BOOL rtl = needs && isRTL(c);
		NSUInteger end = start + 1;
		NSString *run;
		NSMutableDictionary *a = [[attrs mutableCopy] autorelease];
		while (end < n) {
			unichar d = [s characterAtIndex: end];
			BOOL dn = d >= 0x80 && have && ![have characterIsMember: d];
			BOOL space = d == ' ' && needs;		/* a space between two fallback words stays in the run */
			if (dn != needs && !space) break;
			if (needs && dn && isRTL(d) != rtl) break;
			end++;
		}
		run = [s substringWithRange: NSMakeRange(start, end - start)];
		if (rtl) {
			NSUInteger k, rn = [run length];
			unichar *buf = malloc(rn * sizeof(unichar));
			for (k = 0; k < rn; k++) buf[k] = [run characterAtIndex: rn - 1 - k];
			run = [NSString stringWithCharacters: buf length: rn];
			free(buf);
		}
		if (needs && fb) [a setObject: fb forKey: NSFontAttributeName];
		(void)fbSet;
		[out appendAttributedString: [[[NSAttributedString alloc] initWithString: run attributes: a] autorelease]];
		start = end;
	}
	return out;
}

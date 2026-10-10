#import "MilanText.h"

static BOOL
isRTL(unichar c)
{
	return (c >= 0x0590 && c <= 0x08FF) || (c >= 0xFB1D && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF);
}

static BOOL
isHangul(unichar c)
{
	return (c >= 0x1100 && c <= 0x11FF) || (c >= 0x3130 && c <= 0x318F) || (c >= 0xA960 && c <= 0xA97F) || (c >= 0xAC00 && c <= 0xD7FF);
}

static BOOL
isKana(unichar c)
{
	return (c >= 0x3040 && c <= 0x30FF) || (c >= 0x31F0 && c <= 0x31FF) || (c >= 0xFF66 && c <= 0xFF9F);
}

/* Han, kana, Hangul, CJK punctuation and full-width forms: set in Noto Sans CJK even where DejaVu has a glyph (its few CJK
 * symbols would mix two designs in one name) */
static BOOL
isCJK(unichar c)
{
	return isHangul(c) || isKana(c) || (c >= 0x2E80 && c <= 0x2FDF) || (c >= 0x3000 && c <= 0x303F) || (c >= 0x3190 && c <= 0x31EF)
	    || (c >= 0x3200 && c <= 0x4DBF) || (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0xF900 && c <= 0xFAFF) || (c >= 0xFE30 && c <= 0xFE4F)
	    || (c >= 0xFF00 && c <= 0xFFEF);
}

/* marks that belong to the character before them, whatever font that one is in */
static BOOL
isAttached(unichar c)
{
	return (c >= 0x0300 && c <= 0x036F) || c == 0x200C || c == 0x200D || (c >= 0xFE00 && c <= 0xFE0F) || (c >= 0xDC00 && c <= 0xDFFF);
}

/* The first of `names` that the font system has AND that really covers `probe`: for a name it does not know, GNUstep's
 * fontconfig enumerator can hand back the closest match (Inter), which would silently draw "?" again. */
static NSFont *
fontFor(NSArray *names, unichar probe, CGFloat size)
{
	NSString *n;
	for (n in names) {
		NSFont *f = [NSFont fontWithName: n size: size];
		if (f && [[f coveredCharacterSet] characterIsMember: probe]) return f;
	}
	return nil;
}

enum { FBDejaVu, FBCJKsc, FBCJKjp, FBCJKkr, FBUnifont, FBCount };

/* The fallbacks the image ships (iokit build_fonts.sh): DejaVu Sans for Hebrew, Arabic and other alphabets; Noto Sans
 * CJK (one face per region, the same Han characters are drawn differently in China, Japan and Korea); GNU Unifont, which
 * covers nearly all of the BMP, as the last resort. Looked up once per size; missing ones are NSNull. */
static NSFont *
fallback(int which, CGFloat size)
{
	static NSMutableDictionary *cache;
	NSString *key = [NSString stringWithFormat: @"%d/%g", which, size];
	id f;
	if (!cache) cache = [[NSMutableDictionary alloc] init];
	if ((f = [cache objectForKey: key])) return f == [NSNull null] ? nil : f;
	switch (which) {
	case FBDejaVu: f = fontFor([NSArray arrayWithObjects: @"DejaVuSans", @"DejaVu Sans", nil], 0x05D0, size); break;
	case FBCJKsc: f = fontFor([NSArray arrayWithObjects: @"NotoSansCJKsc-Regular", @"Noto Sans CJK SC", nil], 0x4E2D, size); break;
	case FBCJKjp: f = fontFor([NSArray arrayWithObjects: @"NotoSansCJKjp-Regular", @"Noto Sans CJK JP", nil], 0x3042, size); break;
	case FBCJKkr: f = fontFor([NSArray arrayWithObjects: @"NotoSansCJKkr-Regular", @"Noto Sans CJK KR", nil], 0xAC00, size); break;
	default: f = fontFor([NSArray arrayWithObjects: @"Unifont", @"unifont", nil], 0x4E2D, size); break;
	}
	if (!f && which != FBCJKsc && which >= FBCJKjp && which <= FBCJKkr) f = fallback(FBCJKsc, size);	/* any CJK face beats "?" */
	[cache setObject: f ? f : (id)[NSNull null] forKey: key];
	return f;
}

/* the font for c: nil = the base font */
static NSFont *
fontForChar(unichar c, NSCharacterSet *have, int cjkFace, CGFloat size)
{
	NSFont *f;
	int i;
	if (c < 0x80 || !have || [have characterIsMember: c]) return nil;
	if (isCJK(c) && (f = fallback(cjkFace, size)) && [[f coveredCharacterSet] characterIsMember: c]) return f;
	for (i = 0; i < FBCount; i++)
		if ((f = fallback(i, size)) && [[f coveredCharacterSet] characterIsMember: c]) return f;
	return nil;	/* no font has it: the base font's "?" */
}

NSAttributedString *
MilanDisplayString(NSString *s, NSDictionary *attrs)
{
	NSFont *base = [attrs objectForKey: NSFontAttributeName];
	NSCharacterSet *have;
	NSUInteger i, n = [s length], start = 0;
	NSMutableAttributedString *out;
	CGFloat size;
	int cjkFace = FBCJKsc;
	BOOL any = NO;
	if (!base || n == 0) return [[[NSAttributedString alloc] initWithString: s ? s : @"" attributes: attrs] autorelease];
	have = [base coveredCharacterSet];
	for (i = 0; i < n; i++) {
		unichar c = [s characterAtIndex: i];
		if (c >= 0x80 && have && ![have characterIsMember: c]) any = YES;
		if (isKana(c)) cjkFace = FBCJKjp;	/* kana anywhere: the name is Japanese, its Han too */
		else if (isHangul(c) && cjkFace == FBCJKsc) cjkFace = FBCJKkr;
	}
	if (!any) return [[[NSAttributedString alloc] initWithString: s attributes: attrs] autorelease];
	size = [base pointSize];
	out = [[[NSMutableAttributedString alloc] init] autorelease];
	/* split into runs of one font each; right-to-left runs are reversed */
	while (start < n) {
		unichar c = [s characterAtIndex: start];
		NSFont *f = fontForChar(c, have, cjkFace, size);
		BOOL rtl = f && isRTL(c);
		NSUInteger end = start + 1;
		NSString *run;
		NSMutableDictionary *a = [[attrs mutableCopy] autorelease];
		while (end < n) {
			unichar d = [s characterAtIndex: end];
			NSFont *g;
			if (isAttached(d)) { end++; continue; }
			if (d == ' ' && f) { end++; continue; }	/* a space between two fallback words stays in the run */
			g = fontForChar(d, have, cjkFace, size);
			if (g != f) break;
			if (f && isRTL(d) != rtl) break;
			end++;
		}
		/* trailing spaces go back to the base font: they separate runs, they do not belong to the fallback word */
		while (f && end > start + 1 && [s characterAtIndex: end - 1] == ' ') end--;
		run = [s substringWithRange: NSMakeRange(start, end - start)];
		if (rtl) {
			NSUInteger k, rn = [run length];
			unichar *buf = malloc(rn * sizeof(unichar));
			for (k = 0; k < rn; k++) buf[k] = [run characterAtIndex: rn - 1 - k];
			run = [NSString stringWithCharacters: buf length: rn];
			free(buf);
		}
		if (f) [a setObject: f forKey: NSFontAttributeName];
		[out appendAttributedString: [[[NSAttributedString alloc] initWithString: run attributes: a] autorelease]];
		start = end;
	}
	return out;
}

NSAttributedString *
MilanFittedDisplayString(NSString *s, NSDictionary *attrs, CGFloat width)
{
	NSAttributedString *a = MilanDisplayString(s, attrs);
	NSMutableArray *cuts;	/* start of every composed character, so a cut never splits a pair or a mark */
	NSUInteger i, n, lo, hi;
	if ([a size].width <= width || [s length] < 3) return a;
	cuts = [NSMutableArray array];
	for (i = 0; i < [s length]; i = NSMaxRange([s rangeOfComposedCharacterSequenceAtIndex: i]))
		[cuts addObject: [NSNumber numberWithUnsignedInteger: i]];
	[cuts addObject: [NSNumber numberWithUnsignedInteger: [s length]]];
	n = [cuts count] - 1;
	/* the most characters k that fit as head (k - k/2) + "…" + tail (k/2) */
	lo = 0; hi = n - 1;
	a = MilanDisplayString(@"…", attrs);
	while (lo < hi) {
		NSUInteger k = (lo + hi + 1) / 2, h = k - k / 2;
		NSString *t = [NSString stringWithFormat: @"%@…%@", [s substringToIndex: [[cuts objectAtIndex: h] unsignedIntegerValue]],
		               [s substringFromIndex: [[cuts objectAtIndex: n - k / 2] unsignedIntegerValue]]];
		NSAttributedString *c = MilanDisplayString(t, attrs);
		if ([c size].width <= width) { lo = k; a = c; } else hi = k - 1;
	}
	return a;
}

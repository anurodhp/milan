#import "MilanEntry.h"
#include <stdlib.h>
#include <string.h>

/* Canonical composition (NFC) for the BMP, plus Hangul. GNUstep base here has no ICU, so
 * -precomposedStringWithCanonicalMapping is "not implemented". Algorithm: UAX #15, "Canonical Composition". */
#include "MilanNFC_tables.h"

static int
cccOf(unichar c)
{
	size_t lo = 0, hi = sizeof nfcClasses / sizeof nfcClasses[0];
	while (lo < hi) {
		size_t mid = (lo + hi) / 2;
		if (nfcClasses[mid][0] == c) return nfcClasses[mid][1];
		if (nfcClasses[mid][0] < c) lo = mid + 1; else hi = mid;
	}
	return 0;
}

static int
compose2(unichar a, unichar b)
{
	size_t lo = 0, hi = sizeof nfcPairs / sizeof nfcPairs[0];
	if (a >= 0x1100 && a <= 0x1112 && b >= 0x1161 && b <= 0x1175)		/* L + V */
		return 0xAC00 + ((a - 0x1100) * 21 + (b - 0x1161)) * 28;
	if (a >= 0xAC00 && a <= 0xD7A3 && (a - 0xAC00) % 28 == 0 && b >= 0x11A8 && b <= 0x11C2)	/* LV + T */
		return a + (b - 0x11A7);
	while (lo < hi) {
		size_t mid = (lo + hi) / 2;
		if (nfcPairs[mid][0] == a && nfcPairs[mid][1] == b) return nfcPairs[mid][2];
		if (nfcPairs[mid][0] < a || (nfcPairs[mid][0] == a && nfcPairs[mid][1] < b)) lo = mid + 1; else hi = mid;
	}
	return -1;
}

NSString *
MilanNFC(NSString *s)
{
	NSUInteger n = [s length], i, comp = 0, starter = 0;
	unichar *buf;
	int lastClass = 0;
	BOOL any = NO, haveStarter = NO;
	if (n < 2) return s;
	for (i = 0; i < n; i++) if ([s characterAtIndex: i] >= 0x300) { any = YES; break; }
	if (!any) return s;		/* plain ASCII/Latin-1: already composed */
	buf = malloc(n * sizeof(unichar));
	for (i = 0; i < n; i++) {
		unichar ch = [s characterAtIndex: i];
		int cls = cccOf(ch), c;
		if (haveStarter && (c = compose2(buf[starter], ch)) >= 0 && (lastClass < cls || lastClass == 0)) {
			buf[starter] = (unichar)c;		/* composed into the starter; lastClass unchanged */
			continue;
		}
		if (cls == 0) { starter = comp; haveStarter = YES; }
		lastClass = cls;
		buf[comp++] = ch;
	}
	s = [NSString stringWithCharacters: buf length: comp];
	free(buf);
	return s;
}

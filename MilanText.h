/* MilanText: display strings with per-character font fallback. The UI font (Inter) has no Hebrew, Arabic or CJK
 * glyphs and GNUstep draws a "?" for a missing glyph; DejaVu Sans (already on the image) has Hebrew and Arabic, so runs
 * of characters the UI font lacks are set in DejaVu. Hebrew/Arabic runs are reversed into visual order (a simple
 * right-to-left rule, no full bidi algorithm). Arabic is NOT shaped (no contextual forms), so it shows as isolated letters. */
#import <AppKit/AppKit.h>

/* `attrs` are applied to the whole string (font, color, paragraph style); only the font changes per run. */
NSAttributedString *MilanDisplayString(NSString *s, NSDictionary *attrs);

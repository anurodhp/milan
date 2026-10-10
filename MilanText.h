/* MilanText: display strings with per-character font fallback. The UI font (Inter) has no Hebrew, Arabic or CJK
 * glyphs, and GNUstep's cairo backend draws a "?" for a missing glyph instead of asking fontconfig for another font, so
 * runs of characters the UI font lacks are set in a fallback the image ships: DejaVu Sans (Hebrew, Arabic, other
 * alphabets), Noto Sans CJK (Chinese, Japanese, Korean; the regional face follows the name: kana -> JP, Hangul -> KR,
 * else SC) and GNU Unifont as the last resort.
 * Hebrew/Arabic runs are reversed into visual order (a simple right-to-left rule, no full bidi algorithm). Arabic is NOT
 * shaped (no contextual forms), so it shows as isolated letters. Characters outside the BMP (emoji) cannot be helped
 * here: gnustep-gui's NSGlyphGenerator passes the code point to -glyphForCharacter: as a 16-bit unichar. */
#import <AppKit/AppKit.h>

/* `attrs` are applied to the whole string (font, color, paragraph style); only the font changes per run. */
NSAttributedString *MilanDisplayString(NSString *s, NSDictionary *attrs);
/* The same, shortened in the middle with "…" to fit `width` (GNUstep's drawInRect: ignores NSLineBreakByTruncatingMiddle). */
NSAttributedString *MilanFittedDisplayString(NSString *s, NSDictionary *attrs, CGFloat width);

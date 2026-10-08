#import "MilanDialog.h"

@interface MilanDialogView : NSView <NSTextFieldDelegate>
{
	NSString *title, *message;
	NSTextField *field;
	NSButton *okButton, *cancelButton;
	MilanDialogDone done;
	NSResponder *previous;
	NSRect box;
}
- (id) initWithFrame: (NSRect)f title: (NSString *)t message: (NSString *)m textDefault: (NSString *)td
             okTitle: (NSString *)ok completion: (MilanDialogDone)d;
@end

static MilanDialogView *active;

@implementation MilanDialogView

- (id) initWithFrame: (NSRect)f title: (NSString *)t message: (NSString *)m textDefault: (NSString *)td
             okTitle: (NSString *)ok completion: (MilanDialogDone)d
{
	CGFloat h = td ? 150 : 130;
	self = [super initWithFrame: f];
	title = [t copy]; message = [m copy]; done = [d copy];
	box = NSMakeRect(floor(NSMidX(f) - 190), floor(NSMidY(f) - h / 2), 380, h);
	[self setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	cancelButton = [[[NSButton alloc] initWithFrame: NSMakeRect(NSMaxX(box) - 190, box.origin.y + 14, 84, 26)] autorelease];
	[cancelButton setTitle: @"Cancel"];
	okButton = [[[NSButton alloc] initWithFrame: NSMakeRect(NSMaxX(box) - 100, box.origin.y + 14, 84, 26)] autorelease];
	[okButton setTitle: ok];
	{
		NSButton *b;
		for (b in [NSArray arrayWithObjects: cancelButton, okButton, nil]) {
			[b setBezelStyle: NSRoundedBezelStyle];
			[b setTarget: self];
			[self addSubview: b];
		}
	}
	[cancelButton setAction: @selector(cancel:)];
	[okButton setAction: @selector(accept:)];
	if (td) {
		field = [[[NSTextField alloc] initWithFrame: NSMakeRect(box.origin.x + 18, box.origin.y + 56, box.size.width - 36, 24)] autorelease];
		[field setStringValue: td];
		[field setDelegate: self];
		[self addSubview: field];
	}
	return self;
}

- (void) dealloc { [title release]; [message release]; [done release]; [super dealloc]; }
- (BOOL) isFlipped { return NO; }
- (BOOL) acceptsFirstResponder { return YES; }
- (void) mouseDown: (NSEvent *)ev {}	/* swallow clicks outside the box */

- (void) drawRect: (NSRect)dirty
{
	NSDictionary *tt = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont boldSystemFontOfSize: 13], NSFontAttributeName,
	    [NSColor controlTextColor], NSForegroundColorAttributeName, nil];
	NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
	NSDictionary *mt;
	[ps setLineBreakMode: NSLineBreakByWordWrapping];
	mt = [NSDictionary dictionaryWithObjectsAndKeys: [NSFont systemFontOfSize: 11], NSFontAttributeName,
	    [NSColor controlTextColor], NSForegroundColorAttributeName, ps, NSParagraphStyleAttributeName, nil];
	[[NSColor colorWithCalibratedWhite: 0 alpha: 0.35] set];
	NSRectFillUsingOperation([self bounds], NSCompositeSourceOver);
	[[NSColor colorWithCalibratedWhite: 0.95 alpha: 1] set];
	[[NSBezierPath bezierPathWithRoundedRect: box xRadius: 10 yRadius: 10] fill];
	[[NSColor colorWithCalibratedWhite: 0.6 alpha: 1] set];
	[[NSBezierPath bezierPathWithRoundedRect: box xRadius: 10 yRadius: 10] stroke];
	[title drawAtPoint: NSMakePoint(box.origin.x + 18, NSMaxY(box) - 30) withAttributes: tt];
	[message drawInRect: NSMakeRect(box.origin.x + 18, NSMaxY(box) - (field ? 56 : 90) - (field ? 0 : 0), box.size.width - 36, field ? 22 : 54)
	     withAttributes: mt];
}

- (void) finish: (BOOL)ok
{
	MilanDialogDone d = [done retain];
	NSString *t = field ? [[[field stringValue] copy] autorelease] : nil;
	NSWindow *w = [self window];
	[self removeFromSuperview];
	active = nil;
	if (previous) [w makeFirstResponder: previous];
	[w display];
	if (d) d(ok, t);
	[d release];
}

- (void) accept: (id)s { [self finish: YES]; }
- (void) cancel: (id)s { [self finish: NO]; }

- (void) keyDown: (NSEvent *)ev
{
	NSString *k = [ev charactersIgnoringModifiers];
	unichar c = [k length] ? [k characterAtIndex: 0] : 0;
	if (c == '\r' || c == '\n' || c == 3 || c == 0x03) [self accept: nil];
	else if (c == 0x1b) [self cancel: nil];
}

/* Return / Esc inside the text field */
- (BOOL) control: (NSControl *)control textView: (NSTextView *)tv doCommandBySelector: (SEL)cmd
{
	if (cmd == @selector(insertNewline:)) { [self accept: nil]; return YES; }
	if (cmd == @selector(cancelOperation:)) { [self cancel: nil]; return YES; }
	return NO;
}

- (void) present
{
	NSWindow *w = [self window];
	previous = [w firstResponder];
	if (field) {
		NSString *v = [field stringValue];
		NSRange dot = [v rangeOfString: @"." options: NSBackwardsSearch];
		[w makeFirstResponder: field];
		[field selectText: nil];
		/* a file name: select the name without its extension, as Finder does */
		if (dot.location != NSNotFound && dot.location > 0 && [field currentEditor])
			[(NSTextView *)[field currentEditor] setSelectedRange: NSMakeRange(0, dot.location)];
	}
	else [w makeFirstResponder: self];
	[w display];
}

@end

@implementation MilanDialog

+ (BOOL) isActive { return active != nil; }

+ (void) showOver: (NSView *)area title: (NSString *)title message: (NSString *)message
      textDefault: (NSString *)td okTitle: (NSString *)ok completion: (MilanDialogDone)done
{
	NSWindow *w = [area window];
	NSRect r = [[w contentView] convertRect: [area bounds] fromView: area];
	MilanDialogView *v;
	if (active) return;
	v = [[[MilanDialogView alloc] initWithFrame: r title: title message: message textDefault: td okTitle: ok completion: done] autorelease];
	[[w contentView] addSubview: v];
	active = v;
	[v present];
}

@end

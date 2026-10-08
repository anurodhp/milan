# Platform notes (found the hard way)

- **Screenshots can mislead.** `xwd -root` returned blank for some windows (menu bar, browser window bodies, the
  panels below) that `xwd -id <window>` showed fully painted. Several "blank window" conclusions below may be capture
  artifacts; the context-menu overlay and these notes were written before that was known. Check on the real display.
- **New X windows of our own painted blank (in root captures)** on this stack (Eau + Window Maker, Pi): a context-menu NSMenu pop-up
  (mapped, never painted), a custom borderless NSWindow, GNUstep's standard About NSPanel. Views inside an
  already-painted window draw fine. So pop-ups are overlay views (`MilanContent.m`), not windows. Titled NSWindows
  (the info panels) do paint.
- GNUstep's `-popUpContextMenu:` also never mapped a window: `NSMenuPanel -orderFrontRegardless` returns early for
  a top-level menu under `NSWindows95InterfaceStyle` unless a pop-up owns it (`NSMenu.m`).
- Background work reaches the UI with `MilanRunOnMain()`; `dispatch_after` on the main queue does not wake the run loop.
- A document view must not be the object that owns its scroll view (infinite recursion in `isFlipped`).
- `xwd -root` on the Pi is 24 bits per pixel with 4-byte rows; decode it as BGR, not BGRA.
- `xinject` (tools/userland_staging) drives the real X server via XTEST: click, drag, key, `windows` dumps the X window tree.
- **Never drag a window's resize grip (or any WM-managed resize) with `xinject`.** Window Maker takes `XGrabServer`
  for the whole resize; XTEST requests from other clients are then not serviced, so the button release never arrives and
  every X client, including xinject, hangs. Recovery: `kill -USR1 <wmaker pid>` (restarts the WM in place and releases
  the grab; it re-runs the autostart script, so an extra Terminal.app appears). Moving by the title bar is fine.
- `-[NSUserDefaults setBool: NO forKey:]` hangs the action it is called from in this GNUstep base (setBool:YES is fine); store `[NSNumber numberWithInt:]` with `setObject:forKey:` and read with `boolForKey:`.

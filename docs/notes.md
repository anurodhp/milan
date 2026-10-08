# Platform notes (found the hard way)

- **New X windows of our own painted blank** on this stack (Eau + Window Maker, Pi): a context-menu NSMenu pop-up
  (mapped, never painted), a custom borderless NSWindow, GNUstep's standard About NSPanel. Views inside an
  already-painted window draw fine. So pop-ups are overlay views (`MilanContent.m`), not windows. Titled NSWindows
  (the info panels) do paint.
- GNUstep's `-popUpContextMenu:` also never mapped a window: `NSMenuPanel -orderFrontRegardless` returns early for
  a top-level menu under `NSWindows95InterfaceStyle` unless a pop-up owns it (`NSMenu.m`).
- Background work reaches the UI with `MilanRunOnMain()`; `dispatch_after` on the main queue does not wake the run loop.
- A document view must not be the object that owns its scroll view (infinite recursion in `isFlipped`).
- `xwd -root` on the Pi is 24 bits per pixel with 4-byte rows; decode it as BGR, not BGRA.
- `xinject` (tools/userland_staging) drives the real X server via XTEST: click, drag, key, `windows` dumps the X window tree.

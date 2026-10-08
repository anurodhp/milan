# Plan: Milan draws the desktop

## Decision
Milan owns the desktop: one full-screen, opaque, borderless window at `NSDesktopWindowLevel` that draws
the wallpaper and the icons of `~/Desktop`. Not a transparent window over the window manager's wallpaper.

Why not transparent-over-WM: there is no compositing manager on the Pi (the X server has Composite, but
nothing uses it), so per-pixel transparency does not exist. The only no-compositor alternative is an
XShape mask: 1-bit edges (jagged label text), re-shaping on every icon move or selection change, and raw
Xlib calls because GNUstep has no shape API. Drawing the wallpaper ourselves is simpler and renders better.

## What the stack already gives us (checked)
- gnustep-back maps `NSDesktopWindowLevel` to `_NET_WM_WINDOW_TYPE_DESKTOP` and `WIN_LAYER_DESKTOP`
  (`XGServerWindow.m` ~3438/3483).
- Our Window Maker (`third_party/wmaker`, `src/wmspec.c` `handleWindowType`) gives a desktop-type window: no
  titlebar/border/resize/move, on all workspaces, hidden from the window list and switcher, layer =
  `WMDesktopLevel` (lowest). So the WM side of the plan needs no changes.
- Xorg on the Pi has SHAPE, XTEST, RANDR, Composite, DAMAGE; `libXtst`/`libXrandr` are built in the staging tree.

## Milestones
1. **Spike (half a day).** `-MilanDesktop YES`: a full-screen `NSWindow` at `NSDesktopWindowLevel`,
   `NSBorderlessWindowMask`, filled with a colour. Verify on the Pi: sits below everything, no decoration,
   visible on every workspace, does not appear in the window list, other windows and the dock stay on top,
   size matches the real screen (`NSScreen` frame, 1280x720).
2. **Wallpaper.** Draw an image scaled once to the screen size and cached (`MilanWallpaper`); default
   `MilanWallpaper` path preference, solid-colour fallback. Redraw only on screen-size change (RANDR).
3. **Desktop icons.** Reuse `MilanIconGrid` over `~/Desktop` with a transparent background and light label
   text (a `desktop` drawing mode), kqueue live refresh as in the browser windows. Drag/drop, rubber band,
   open and Get Info all come from the existing grid. Icon positions persisted per item (a plist in
   `~/Library/Preferences`, falling back to the auto grid, filling from the top right like Finder).
4. **System items.** Trash (Eau recycler icon, Empty/Full) and mounted volumes (`getfsstat`) on the desktop.
5. **Desktop menu.** Right-click on the background: New Folder, Get Info, Change Background, Clean Up, plus
   the WM's own root menu entries if wanted (the WM never sees the click once we cover the root).
   Milan's own app menu stays while the desktop has focus.
6. **Make it the session's desktop.** Start it from the xdm Xsession / WM autostart; `wmsetbg` stays as the
   fallback wallpaper when Milan is not running. Decide whether Milan runs as one process (desktop + browser
   windows) or `Milan -MilanDesktop` as a separate instance (simplest: one process, desktop window created
   at launch when `MilanDesktop` is set).

## Risks / unknowns
- Screen size: resolved. The display is 1280x720; the earlier "960 wide" was a screenshot-decoder bug (xwd root is
  24 bits per pixel, 4-byte rows padded). Still size the desktop from `NSScreen`, not a constant.
- Windows created right after launch painted late/blank in several tests (see `TODO.md` notes). The desktop
  window is created at launch, so check it paints; if not, force `display` after the first run-loop turn.
- Clicks on empty desktop must not steal focus from the app the user was in (use `acceptsFirstMouse` and
  `canBecomeKeyWindow` deliberately).
- Memory: a 1280x720x4 wallpaper pixmap is 3.7 MB; fine, but keep only the scaled copy.

## Testing
- The Pi has XTEST, so build a tiny `xinject` tool (libXtst: move, click, drag, key) in `tools/` and drive
  real mouse and keyboard input from the host over ssh. That also closes the "never exercised by a real
  click" list in `TODO.md` (context menu, rename sheet, drag between windows, rubber band, type-to-select).
- Self-test hooks like `-MilanSelfTest` for the desktop: icon list matches `~/Desktop`, drop onto the desktop
  moves into `~/Desktop`, wallpaper redraws on a screen-size change.

## Order
`xinject` first (it unblocks testing everything, including the desktop), then milestones 1 to 6 in order.

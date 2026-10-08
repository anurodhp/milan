# Milan TODO

## Device testing (Pi, never exercised by a real click)
- Rubber-band, type-to-select and drag-and-drop with a real mouse/keyboard (only the drop handler is self-tested).
- App launch by double-click (`launchApplication:`).
- Sort indicator arrows in list headers (code in place, not visually checked).
- Right-click context menu with real mouse events.
- Rename sheet (modal panel).
- List-view column-header sorting.
- Two or more info panels open at once.

## Features
- Real mouse-drag test of drag and drop (all three views have it now).
- Sidebar: user-editable favorites.
- Consider `NSToolbar` (GNUstep has it) now that icons exist.
- Desktop drawing (future iteration).

## Cleanup
- Commit `tools/userland_staging/build_milan.sh` in the iokit repo (untracked there).

## Notes
- Background work must reach the UI via `MilanRunOnMain()`, not `dispatch_async(main queue)` or
  `dispatch_after` (GNUstep's run loop is not woken by main-queue blocks).
- A document view must not be the object that owns its scroll view (recursed in `isFlipped`).
- Self test: `Milan -MilanSelfTest YES`; other launch defaults: `MilanViewMode`, `MilanInfo`, `MilanOrigin`.

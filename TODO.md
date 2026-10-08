# Milan TODO

## Device testing (Pi, never exercised by a real click)
- Rubber-band, type-to-select and drag-and-drop with a real mouse/keyboard (only the drop handler is self-tested).
- App launch by double-click (`launchApplication:`).
- Sort indicator arrows in list headers (code in place, not visually checked).
- Trash sidebar icon (Eau RecyclerEmpty/Full), Put Back and Empty Trash with real clicks.
- Right-click context menu with real mouse events.
- Rename sheet (modal panel).
- List-view column-header sorting.
- Two or more info panels open at once.
- A real mouse drag from one window to another (the drop is self-tested with `-MilanMultiTest YES`).

## Features
- Preference for which folder a new blank window opens in (File > New Window). For now it always opens the user's home folder.
- Launching: verify double-click on an `.app` starts it (`launchApplication:`), and that double-click on a document opens it
  in its handler (`NSWorkspace openFile:`). GNUstep does have file handlers: apps declare `NSTypes` (extensions, `NSRole`,
  `NSIcon`) in their Info plist, and NSWorkspace keeps per-extension choices in `~/GNUstep/Library/Services/.GNUstepExtPrefs`
  (`getBestAppInRole:forExtension:` / `setBestApp:inRole:forExtension:`). Add: "Open With" submenu, "Always open with",
  and a Get Info row showing the default app for the file's extension.
- Quick Look: Space bar previews the selected image (and later text) in a floating preview window; Space or Esc closes it;
  arrow keys move to the next/previous image; scale to fit, decode off the main thread.
- Remember window position and size per folder: restore them when a folder is opened again (keyed by path, in the preferences; new folders keep the cascade default).
- Trash: test per-volume trash (`<mount>/.Trashes/<uid>`) on a second volume; Delete Immediately; Empty Trash shortcut.
- Trash: the merged view only watches the home trash for live refresh.
- Real mouse-drag test of drag and drop (all three views have it now).
- Sidebar: user-editable favorites.
- Consider `NSToolbar` (GNUstep has it) now that icons exist.
- Desktop drawing: see `docs/desktop-plan.md`. Build `xinject` (XTEST) first to test with real input.

## Notes
- Background work must reach the UI via `MilanRunOnMain()`, not `dispatch_async(main queue)` or
  `dispatch_after` (GNUstep's run loop is not woken by main-queue blocks).
- A document view must not be the object that owns its scroll view (recursed in `isFlipped`).
- Multi-window test: `Milan -MilanMultiTest YES`.
- Self test: `Milan -MilanSelfTest YES`; other launch defaults: `MilanViewMode`, `MilanInfo`, `MilanOrigin`.

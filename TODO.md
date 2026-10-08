# Milan TODO

## Verify by eye on the Pi
- With the desktop running (`Milan -MilanDesktop YES`), my root screenshots (`xwd -root`) showed the desktop window's
  wallpaper and icons but **the browser window body and the menu bar looked blank**, while capturing those windows by id
  (`xwd -id`) showed them fully painted. I could not tell which is true on the real display; please check that the
  browser windows and the menu bar are visible above the desktop. If not, the desktop window's stacking or its 32-bit visual is the suspect.

## Device testing (Pi)
Verified with real input (xinject): sidebar clicks, rubber band, menu-bar menus, context menus (icons, list, desktop, Trash),
Get Info, Open With and double-click launching (documents and apps), Quick Look, list-header sorting, all in-window dialogs
(Empty Trash, Rename, Delete Immediately), drag to the Trash, drag between two windows, drag icons on the desktop, desktop
Preferences toggle, wallpaper chooser, type-to-select, sidebar favorites, image thumbnails. Not yet exercised with real input:
- Put Back and Empty Trash through the Trash window's context menu; two info panels open together;
  the sort indicator arrows' look; drag and drop inside the columns view.

## Features
- Unicode (validated on the Pi with `/tmp/uni`): the UI font is Inter (covers Latin, Greek, Cyrillic). Names are shown NFC
  (accents compose; `MilanNFC.m` and the libs-base fork). Hebrew and Arabic fall back to DejaVu Sans per run (`MilanText.m`),
  Hebrew is reversed into visual order and reads correctly; Arabic has no contextual shaping so it shows as isolated letters
  (needs HarfBuzz). **Still `?`: CJK, Korean, emoji**: no font on the image has them, and GNUstep draws "?" for a missing glyph.
  Needs a font decision (OFL: Noto Sans CJK subset, Noto Emoji monochrome, or GNU Unifont as a last resort). The fallback is used in
  the icon, list and column views; window titles, the info panel and Quick Look titles still use the plain string. Also unchecked:
  ZWJ emoji sequences, a full bidi algorithm for mixed LTR/RTL names, sorting order across scripts.

- JPEG: Milan decodes .jpg/.jpeg itself (`MilanImage.m`, libjpeg-turbo, big files at 1/2-1/8 size), so Quick Look, wallpapers and
  Set as Desktop Picture accept them with the system gnustep-gui as it is. `libjpeg.62.dylib` must be in `/usr/X11/lib` on the
  image (the iokit PR "libjpeg-turbo + JPEG in gnustep-gui" builds it; the Pi has it from a manual copy). Rebuilding gnustep-gui
  with JPEG works in staging but loading it in place of the system gui gave a GDNC error here (not investigated); JPEG in
  `NSImage` for other apps needs that gui deployed. Image thumbnails (PNG/TIFF/JPEG) show as file icons (`MilanThumbnailReady`). Still to do: NEON SIMD in libjpeg.

- Launching: done with `MilanLauncher` (own launcher; NSWorkspace hands everything to GWorkspace). Apps started by Milan are not started twice
  ("X is already running"); activating a running app (raise its window) and apps started elsewhere still need a DO or X check; "Always open with" for apps that do not declare the type; opening several selected files in one app instance;
  `Recycler.app` needs GWorkspace running, so it is not launched usefully from Milan.
- Info panel: the "Kind:" label of the first row did not draw in one capture (value did); check on the real screen.

- Quick Look: images (PNG, TIFF, JPEG; small ones scaled up to 3x), text, and folders (item count). Still to do: PDF, zoom,
  archives, decoding large images off the main thread.

- Trash: test per-volume trash (`<mount>/.Trashes/<uid>`) on a second volume; Delete Immediately; Empty Trash shortcut.
- Trash: the merged view only watches the home trash for live refresh.
- Sidebar: favorites are editable (drag a folder below the rows to add, right-click > Remove from Sidebar); still to do: reorder by dragging, eject for volumes, a Volumes section.
- Consider `NSToolbar` (GNUstep has it) now that icons exist.
- Desktop (see `docs/desktop-plan.md`): wallpaper, icons, Trash and volumes, right-click menu and the Change Background
  panel are built and driven with real input via `xinject`. Still to do:
  - (done) icon positions are remembered and icons can be dragged to a new cell (`MilanDesktopSlots` default).
  - session start-up: launch `Milan -MilanDesktop YES -MilanOpenBrowser NO` from the Window Maker autostart, and a
    preference instead of launch arguments (`MilanDesktop`, `MilanDesktopPath`, `MilanOpenBrowser`);
  - Change Background: "Add Picture..." is covered by dropping files on the panel, putting them in ~/Pictures and "Set as Desktop Picture" in the file menu; an open panel is not planned.
  - (done, untested: needs a display-mode change) the desktop window follows screen-size changes and the wallpaper canvas is rebuilt for the new size.

## Notes
- Background work must reach the UI via `MilanRunOnMain()`, not `dispatch_async(main queue)` or
  `dispatch_after` (GNUstep's run loop is not woken by main-queue blocks).
- A document view must not be the object that owns its scroll view (recursed in `isFlipped`).
- Multi-window test: `Milan -MilanMultiTest YES`.
- Self test: `Milan -MilanSelfTest YES`; other launch defaults: `MilanViewMode`, `MilanInfo`, `MilanOrigin`.
- Note: this GNUstep base lacks newer API: `+[NSData dataWithContentsOfFile:options:error:]` aborts the process (calling an
  unimplemented class method), and `-precomposedStringWithCanonicalMapping` needs ICU. Both are being added in the libs-base fork
  (branch `nsdata-options-nfc-no-icu`); until the rebuilt libgnustep-base is deployed, Milan uses `+[NSData dataWithContentsOfFile:]`
  and its own `MilanNFC`.
- Test hygiene: a stale root `gdnc` (left by NSWorkspace launching GWorkspace) makes every Milan start fail with "unable to
  contact GDNC server" / "Broken pipe"; `kill` it and it restarts on demand.

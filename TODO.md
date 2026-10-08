# Milan TODO

## Verify by eye on the Pi
- With the desktop running (`Milan -MilanDesktop YES`), my root screenshots (`xwd -root`) showed the desktop window's
  wallpaper and icons but **the browser window body and the menu bar looked blank**, while capturing those windows by id
  (`xwd -id`) showed them fully painted. I could not tell which is true on the real display; please check that the
  browser windows and the menu bar are visible above the desktop. If not, the desktop window's stacking or its 32-bit visual is the suspect.

## Device testing (Pi)
- In-window dialogs (`MilanDialog`): all verified with real input: Empty Trash (Cancel/Esc/Return/click), Rename (name without extension pre-selected),
  Delete Immediately in the Trash view. Only send xinject keystrokes after clicking Milan's title bar, or they land in whichever app has focus.
- Done with real input via xinject: sidebar click, rubber band, menu-bar menus, context menu and Get Info, desktop menu,
  Change Background panel (live wallpaper change, persisted), double-click a desktop folder, drag a file onto the Trash.
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
- Unicode: validated on the Pi (`/tmp/uni`: accents, Greek, Cyrillic, Hebrew, Arabic, CJK, Korean, emoji, ZWJ, combining).
  The UI font is Inter (`NSFont = "Inter-Regular"` in `GlobalDefaults.plist`; 6 faces from `build_fonts.sh`), a modern font that
  covers Latin, Greek and Cyrillic. Accents drew detached only because names come back decomposed (NFD) and GNUstep does no
  shaping; fixed by showing names precomposed (`MilanNFC.m`, now also in the libs-base fork as NSString canonical mapping).
  Still `?`: **Hebrew, Arabic, CJK, Korean, emoji**, because Inter has none of them and GNUstep text drawing has no per-character
  font fallback. DejaVu Sans (already on the image) covers Hebrew and Arabic, so a fallback in Milan's drawing would fix Hebrew
  without new fonts (also needs right-to-left ordering); Arabic additionally needs contextual shaping (HarfBuzz); CJK/Korean/emoji
  need new fonts (OFL: Noto Sans CJK subset, Noto Emoji monochrome, or GNU Unifont as a last resort). Also unchecked: emoji ZWJ
  sequences, rename/new-folder with non-ASCII, sorting order across scripts.

- JPEG: Milan decodes .jpg/.jpeg itself (`MilanImage.m`, libjpeg-turbo, big files at 1/2-1/8 size), so Quick Look, wallpapers and
  Set as Desktop Picture accept them with the system gnustep-gui as it is. `libjpeg.62.dylib` must be in `/usr/X11/lib` on the
  image (the iokit PR "libjpeg-turbo + JPEG in gnustep-gui" builds it; the Pi has it from a manual copy). Rebuilding gnustep-gui
  with JPEG works in staging but loading it in place of the system gui gave a GDNC error here (not investigated); JPEG in
  `NSImage` for other apps needs that gui deployed. Still to do: NEON SIMD in libjpeg, JPEG thumbnails in the icon view.

- Launching: done with `MilanLauncher` (own launcher; NSWorkspace hands everything to GWorkspace). Still to do: starting an
  app that is already running should activate it instead of starting a second copy (needs a running-process or DO
  check); "Always open with" for apps that do not declare the type; opening several selected files in one app instance;
  `Recycler.app` needs GWorkspace running, so it is not launched usefully from Milan.
- Info panel: the "Kind:" label of the first row did not draw in one capture (value did); check on the real screen.

- Quick Look: done for PNG/TIFF images and text (Space to open/close, arrows to step, Esc/click to close). Still to do:
  JPEG (needs libjpeg), PDF, scaling up small images, zoom, a titlebar-less "full window" mode, preview of folders (item
  count) and archives, decoding large images off the main thread.

- Trash: test per-volume trash (`<mount>/.Trashes/<uid>`) on a second volume; Delete Immediately; Empty Trash shortcut.
- Trash: the merged view only watches the home trash for live refresh.
- Real mouse-drag test of drag and drop (all three views have it now).
- Sidebar: user-editable favorites.
- Consider `NSToolbar` (GNUstep has it) now that icons exist.
- Desktop (see `docs/desktop-plan.md`): wallpaper, icons, Trash and volumes, right-click menu and the Change Background
  panel are built and driven with real input via `xinject`. Still to do:
  - remember icon positions on the desktop (today they always flow from the top right, by name) and let icons be dragged around;
  - session start-up: launch `Milan -MilanDesktop YES -MilanOpenBrowser NO` from the Window Maker autostart, and a
    preference instead of launch arguments (`MilanDesktop`, `MilanDesktopPath`, `MilanOpenBrowser`);
  - Change Background: "Add Picture..." via an open panel (today: drop PNG/TIFF files on the panel, or put them in ~/Pictures);
    JPEG needs libjpeg in GNUstep-gui;
  - the wallpaper canvas is built at the first draw (one decode and scale of a 1280x720 PNG); rebuild on screen-size change (RANDR).

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

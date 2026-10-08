# Milan TODO

## Verify by eye on the Pi
- With the desktop running (`Milan -MilanDesktop YES`), my root screenshots (`xwd -root`) showed the desktop window's
  wallpaper and icons but **the browser window body and the menu bar looked blank**, while capturing those windows by id
  (`xwd -id`) showed them fully painted. I could not tell which is true on the real display; please check that the
  browser windows and the menu bar are visible above the desktop. If not, the desktop window's stacking or its 32-bit visual is the suspect.

## Device testing (Pi)
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
- JPEG support. GNUstep-gui is built `--disable-jpeg` (`build_gnustep_gui.sh`) and nothing builds libjpeg, so `NSImage`
  cannot read .jpg/.jpeg: wallpapers, thumbnails and Quick Look are PNG/TIFF only today. Plan: add `build_libjpeg.sh` in the
  iokit staging tree (libjpeg-turbo: BSD/IJG/zlib licensed, plain C, optional NEON), drop `--disable-jpeg` and rebuild
  gnustep-gui, optionally rebuild libtiff with JPEG on; then allow .jpg/.jpeg in the wallpaper panel (`MilanWallpaper.m`,
  `isPicture()` in `MilanWindow.m`), `~/Pictures` scanning and the icon kind table. Also on the list in
  `docs/webkit-browser-feasibility.md` (libjpeg-turbo, libwebp missing).
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

# Rules for working on wmodern

## Every app must show up in the app launcher

The launcher (`Super+Space`, rofi `drun`) lists only `.desktop` files. An app that has none is invisible to the user.

* Every graphical app that wmodern installs, or that a wmodern module builds or sets up (GNUstep `.app` bundles,
  dockapps with a window, Python/GTK tools, anything the user is meant to open), installs
  `~/.local/share/applications/NAME.desktop` with `Name`, `Comment`, an absolute `Exec`, `Terminal`, `Categories` and
  `Keywords`. Its uninstall removes the file again, and re-running the installer must not change it.
* Apps the **user** installs later must show up there too, whichever way they were installed: apt, Flatpak, Snap, web
  apps (`webapp`), TUIs (`omarchy`), `getapp`. When a module installs through a mechanism that puts its entries
  somewhere the launcher does not look (Flatpak's export directories, Snap's), the module makes the launcher see them
  (see `modules/flatpak`: `XDG_DATA_DIRS`) and the test suite checks it.
* New module or new installer path: check, in the tests or by hand with `rofi -show drun`, that the entry appears.
  A module without a launchable app (key bindings, settings only) needs nothing.
* Companion tools that live in their own repositories (`wm-theme`/Appearance.app, DisplayScaling.app, the dockapps)
  follow the same rule in their own installers.

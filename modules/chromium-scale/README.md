# chromium-scale — a smaller (or larger) Chromium

> Module `chromium-scale` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install chromium-scale`, or use it on its own as described below.

Chromium's `--force-device-scale-factor` scales the browser's own interface and every web page together, which
Xft.dpi and the page-zoom setting do not (page zoom leaves the toolbar alone). This module adds the flag to
Chromium's launcher; the default is 80%, which is 20% smaller than stock.

```
./install.sh --dry-run
./install.sh                 # 80%
./install.sh --percent 90    # 25..300, 100 is stock
./install.sh --uninstall
```

It writes `~/.local/share/applications/chromium.desktop`, a copy of the system launcher with the flag on the
`Exec=` line (running it again changes only the number; `--uninstall` deletes the copy). Notes:

* Quit Chromium completely first. A running instance, and any window opened through it, keeps its old scale.
* It applies to launches through the launcher: menu, launcher, Super+Space. Typing `chromium` in a terminal bypasses
  it, and so do tab-less windows made by the `webapp` module.
* The copy does not follow later changes to the system launcher after a Chromium package update; run the installer
  again (`wmodern update`) to rebuild it.
* Fractional scales soften text and 1px lines a little. If that bothers you, try a neighbouring value.

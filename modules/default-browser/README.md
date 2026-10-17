# Window Maker: one default browser, everywhere

> Module `default-browser` of [wmodern](https://github.com/jaderfeijo/wmodern): `wmodern install default-browser`, or run `install.sh` on its own.

Without a desktop environment, three separate settings decide which browser a link opens in, and they often disagree
(one session of mine had Pale Moon, Chromium and an Xfce helper in the mix). `install.sh` sets all three to Chromium:

| Setting | Used by | Changed with |
|---|---|---|
| `default-web-browser` | `xdg-open`, most programs, the xterm Ctrl+click helper | `xdg-settings set default-web-browser chromium.desktop` |
| `WebBrowser=` in `~/.config/xfce4/helpers.rc` | `xdg-open` when Xfce's helper is the default (only touched if the file exists) | `sed` on that line |
| the `x-www-browser` alternative | `sensible-browser`, `x-www-browser` and launchers that call them | `sudo update-alternatives --set x-www-browser /usr/bin/chromium` |

```
./install.sh --dry-run                 # look first
./install.sh                           # Chromium
./install.sh --browser firefox-esr     # NAME.desktop must exist
./install.sh --no-system               # skip the sudo step
./install.sh --uninstall               # restore the values found before the first run
```

The old values are kept in `~/.local/share/wmodern-default-browser/` for `--uninstall`.

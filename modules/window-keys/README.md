# window-keys — Super+Q, keyboard resizing and moving

| Keys | Does |
| --- | --- |
| `Super+Q` | Closes the focused window. With `Super+Tab` open it closes the **highlighted** window: the switcher hands any other key to Window Maker after focusing the selection, so this is Window Maker's own `CloseKey`. |
| `Super+W` | Still closes the window (moved from Window Maker's `CloseKey` to `xbindkeys`). |
| `Super+Shift+Alt` `+` / `-` | Grow / shrink the window by 10 px on every side. |
| `Super+Shift+Alt+Control` `+` / `-` | The same by 50 px on every side. |
| `Super+Shift+Alt` `←↑→↓` | Move the window 20 px. |
| `Super+Shift+Alt+Control` `←↑→↓` | Move it 100 px. |

Resizing is from the centre, stays on screen and never goes below 150x80. Set `WMODERN_RESIZE_SMALL` /
`WMODERN_RESIZE_LARGE` (pixels per side), `WMODERN_MOVE_SMALL` / `WMODERN_MOVE_LARGE` to change the steps. Moving keeps the window on the screen. (`Super+Shift+Arrows` are the tiling keys of `super-keys`.) `=`, `_` and the keypad `+`/`-` work as well.

```
./install.sh --dry-run
./install.sh
./install.sh --uninstall    # Super+W is Window Maker's CloseKey again
```

The installer makes the running Window Maker re-read `CloseKey` (SIGUSR2); no restart is needed. A one-time backup is kept as
`WindowMaker.bak-window-keys`. Needs `wmctrl`, `x11-utils` and `xbindkeys`.

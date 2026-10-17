# window-keys — Super+Q, keyboard resizing and moving

| Keys | Does |
| --- | --- |
| `Super+Q` | Closes the focused window. With `Super+Tab` open it closes the **highlighted** window: the switcher hands any other key to Window Maker after focusing the selection, so this is Window Maker's own `CloseKey`. |
| `Super+W` | Still closes the window (moved from Window Maker's `CloseKey` to `xbindkeys`). |
| `Super+Shift+Alt` `+` / `-` | Grow / shrink the window by 10 px on every side. |
| `Super+Shift+Alt+Control` `+` / `-` | The same by 50 px on every side. |
| `Super+Shift+Alt` `←↑→↓` | Move the window 3 px. |
| `Super+Shift+Control` `←↑→↓` | Move it 20 px. |
| `Super+Shift+Alt+Control` `←↑→↓` | Move it 100 px. |

Resizing is from the centre, stays on screen and never goes below 150x80. Set `WMODERN_RESIZE_SMALL` /
`WMODERN_RESIZE_LARGE` (pixels per side), `WMODERN_MOVE_SMALL` / `_MEDIUM` / `_LARGE` to change the steps. Moving keeps the window on the screen. The smallest step is 3 px because Window Maker places windows on a 3 px grid: a 1 or 2 px request is rounded back to where the window was. (`Super+Shift+Arrows` are the tiling keys of `super-keys`.) `=`, `_` and the keypad `+`/`-` work as well.

```
./install.sh --dry-run
./install.sh
./install.sh --uninstall    # Super+W is Window Maker's CloseKey again
```

The installer makes the running Window Maker re-read `CloseKey` (SIGUSR2); no restart is needed. A one-time backup is kept as
`WindowMaker.bak-window-keys`. Needs `wmctrl`, `x11-utils` and `xbindkeys`.

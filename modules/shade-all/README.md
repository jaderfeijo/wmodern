# shade-all: roll up every window on the desktop with one key

> Module `shade-all` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install shade-all`, or use it on its own as described below.

Window Maker can *shade* a window: roll it up so only its title bar remains. It has no key for doing that to
**all windows at once**. `shade-all` is a small toggle: press the key and every window on the current desktop is
shaded; press it again and they all come back. If only some are shaded, the first press shades the rest.

It is a clean-up gesture that keeps your layout: nothing is minimized, moved or resized, so everything is exactly
where it was when you unshade.

## Install

```
git clone https://github.com/jaderfeijo/wmodern.git && cd wmodern/modules/shade-all
./install.sh --dry-run            # look first
./install.sh                      # puts `shade-all` in ~/.local/bin and binds Super+Shift+H
./install.sh --key "Mod4 + Shift + s"   # or another key (xbindkeys syntax)
```

`./install.sh --uninstall` removes the command and the key binding. The binding is a marked block in
`~/.xbindkeysrc`, added once however often you run the installer. Needs `xbindkeys`, `wmctrl` and `xprop`
(`sudo apt install xbindkeys wmctrl x11-utils`, or `--install-deps`).

## How it works

```sh
wmctrl -i -r WINDOW_ID -b add,shaded        # or "remove,shaded"
```

for every window on the current desktop (and the sticky ones), after checking through `xprop` whether they are all
shaded already. The shaded state is the standard EWMH `_NET_WM_STATE_SHADED`, so it should work with other window
managers that implement it.

## Note: Super+Shift+H and the Super-key shortcuts

The `super-keys` item binds the same key (`Super+Shift+H`) to *show desktop*. A key can have only one binding, so when
you install both with `wmodern`, `super-keys` is applied with `--no-show-desktop` and `shade-all` keeps the key. If you
want both, give one of them another key.

Tested on Debian 13 with Window Maker 0.96: the installer (twice, in a scratch home directory, and uninstall).

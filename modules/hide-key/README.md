# hide-key — choose the key that hides an application

> Module `hide-key` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install hide-key`, or use it on its own as described below.

`super-keys` makes `Super+H` shade (roll up) the focused window. Window Maker's `HideKey` could be on the same shortcut,
and then `Super+H` hid the whole application (every window of it) instead. This module sets `HideKey` to something else.

```
./install.sh                  # Hide = Alt+H, Window Maker's own default
./install.sh --key Mod4+Shift+M   # any shortcut (Mod1 = Alt, Mod4 = Super)
./install.sh --none           # nothing hides applications
./install.sh --uninstall      # back to Alt+H
```

A one-time backup is kept as `WindowMaker.bak-hide-key`. A running Window Maker re-reads the file at once.
Run it again after re-applying `super-keys` if that moved `HideKey` back onto `Super+H`.
(`Super+Shift+H` is `shade-all`.)

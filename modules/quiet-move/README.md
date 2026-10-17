# quiet-move — no position box while moving windows

Window Maker shows a small box with the window's coordinates in the top-left corner of the screen while you drag a
window. This sets `MoveDisplay = none` in `~/GNUstep/Defaults/WindowMaker` so it is not shown. (Resizing has its own
box, `ResizeDisplay`, which is left alone.)

```
./install.sh --dry-run
./install.sh
./install.sh --uninstall    # MoveDisplay = corner, Window Maker's default
```

A one-time backup is kept as `WindowMaker.bak-quiet-move`. Window Maker reads the file only at startup, so use
root menu > Window Maker > Restart (or log out and in) afterwards.

# Window Maker with RandR: monitors and the primary display, without restarting

> Module `wmaker-randr` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install wmaker-randr`, or use it on its own as described below.

## The problem

Debian's `windowmaker` (0.96.0) has **no RandR support**. It asks X how big the screen is, and where the monitors are,
**once, when it starts**, and never again. Plug in a second monitor, unplug it, or change the primary display and Window
Maker carries on with the old picture: `_NET_DESKTOP_GEOMETRY` and `_NET_WORKAREA` keep the old size, windows cannot use
the new space properly, and the Dock stays where it was, often on the wrong display. No script can fix that from outside,
because the wrong numbers are inside Window Maker.

## The fix

Upstream Window Maker (git master) has RandR support: it follows screen changes while running, keeps the usable area
right, and moves the Dock to the primary head when `KeepDockOnPrimaryHead` is on. This module builds that version.

```
./install.sh                  # build the tested upstream commit into ~/.local/opt/wmaker, add ~/.local/bin/wmaker
./install.sh --ref master     # build upstream's latest instead
./install.sh --dry-run        # show what it would do
./install.sh --uninstall      # back to Debian's Window Maker
```

* It needs build packages (the script prints the exact `apt install` line if any are missing). Nothing is installed
  system-wide; Debian's package stays in place.
* `~/.local/bin/wmaker` is a small wrapper that starts the new build and **falls back to `/usr/bin/wmaker`** if the build
  is missing. `~/.local/bin` comes before `/usr/bin` on the login `PATH`, so the next login uses it by itself.
* It sets `KeepDockOnPrimaryHead = YES` in `~/GNUstep/Defaults/WindowMaker` (a backup is kept next to it, once).
* Your configuration in `~/GNUstep` is used as it is.

## One restart, once

The running Window Maker is the old binary and cannot be swapped for the new one from outside: log out and in once.
After that, monitor changes need no restart.

## Desk names

The build carries one small patch: new workspaces are called `Desk 2`, `Desk 3`, ... instead of `Workspace 2`
(`src/workspace.c`, `_("Workspace %i")` becomes `_("Desk %i")`; the first one is already `Desk 1`). Names you gave
yourself, and workspaces that already exist in `WMState`, are not touched; rename those from the Workspaces menu.

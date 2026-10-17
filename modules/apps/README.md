# One list of every installed app

> Module `apps` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install apps`, or use it on its own as described below.

A launcher only shows what is in the `.desktop` files under `XDG_DATA_DIRS`. Every way of installing software puts those
files somewhere else: apt in `/usr/share`, Flatpak in its `exports/share` (system and user), Snap in
`/var/lib/snapd/desktop`, web apps and your own entries in `~/.local/share`, Nix and Guix in their profiles. A bare Window
Maker session starts with only some of them, so apps seem to be missing (a Snap app, for example).

`wmapps` is the one place that knows all those directories. The launcher asks it instead of keeping its own list.

```
wmapps doctor                  # what is installed but would not show in the launcher, and why
wmapps list [--source snap]    # every launchable app with where it came from (system, flatpak, snap, web, user, ...)
wmapps launch                  # the launcher (rofi drun) with every app visible
wmapps exec CMD...             # run anything with the complete XDG_DATA_DIRS, right now
wmapps env                     # export XDG_DATA_DIRS=...   (eval "$(wmapps env)")
wmapps dirs                    # the application directories that exist on this machine
wmapps fix | unfix             # a marked block in ~/.xsessionrc so every login has the complete list
```

* Only directories that exist are added, and nothing is duplicated, so new sources are picked up automatically at the
  next login (the block asks `wmapps env` each time instead of holding a fixed list).
* `list` applies rofi's own rules (`NoDisplay`, `Hidden`, `OnlyShowIn`/`NotShowIn`); `--all` includes hidden entries,
  `--json` is for scripts.
* `doctor` also checks the Window Maker process's environment (what everything started from the launcher inherits), the
  Snaps and Flatpaks that have no entry, and AppImages (in `~/Applications`, `~/AppImages`, `~/.local/bin`, `~/bin`)
  that have none.
* The Super-key repo's `wmsk-launcher` (Super+Space) calls `wmapps launch` when `wmapps` is installed.

## Install

```
git clone https://github.com/jaderfeijo/wmodern.git && cd wmodern/modules/apps
./install.sh --dry-run
./install.sh            # ~/.local/bin/wmapps and the ~/.xsessionrc block (--no-session: only the command)
```

`./install.sh --uninstall` removes both. Running it twice changes nothing.

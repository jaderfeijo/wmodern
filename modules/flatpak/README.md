# Window Maker: Flatpak apps in the launcher, and `slack://` sign-in links

> Module `flatpak` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install flatpak`, or use it on its own as described below.

Flatpak apps are found through the **`XDG_DATA_DIRS`** environment variable, which has to contain Flatpak's export
directories (`/var/lib/flatpak/exports/share` and `~/.local/share/flatpak/exports/share`). Two things then depend on it
in a bare Window Maker session:

1. **The launcher.** rofi, dmenu-style launchers and menus read the `.desktop` files from those directories. If the
   variable lacks them, a freshly installed Flatpak app simply never shows up.
2. **Sign-in links.** Slack, Zoom, Teams and others finish signing in by opening a `slack://...` style link. The browser
   hands it to `xdg-open`, which needs to find an app registered for that scheme. If the app's `.desktop` file cannot
   be found, or no handler is set, you click "Open Slack" and nothing happens.

## What I found on Debian 13

Debian's `/etc/X11/Xsession.d/20flatpak` already adds the directories when you log in through GDM, **if Flatpak was
installed before you logged in**. So often nothing is needed. The cases where it is:

* you installed Flatpak (or added a second installation) **after** logging in, and have not logged out since;
* your session is started by something that does not run Debian's Xsession scripts;
* the URL scheme has no handler registered yet.

`flatpak-wm check` tells you which one you have by looking at the variable in your shell **and** in the running window
manager (what everything you start from the Dock and launcher inherits):

```
$ flatpak-wm check
Flatpak export directories, and whether they are in XDG_DATA_DIRS:
  /var/lib/flatpak/exports/share   this shell: yes   window manager session: yes
  ~/.local/share/flatpak/exports/share   (does not exist: nothing installed there)

Looks fine.
```

## Use

```
flatpak-wm check                 # diagnose
flatpak-wm env rofi -show drun   # run something with the directories added, right now (no re-login)
flatpak-wm fix                   # add them for every future login (a marked block in ~/.xsessionrc); --dry-run first
flatpak-wm handler slack         # make the Flatpak that declares slack:// the handler of slack:// links
```

`handler` looks through the installed Flatpak apps for one whose `MimeType` includes `x-scheme-handler/<scheme>` and
registers it with `xdg-mime` (it writes `~/.config/mimeapps.list`). If several apps claim the scheme it lists them and
asks you to name one: `flatpak-wm handler slack com.slack.Slack.desktop`. Check the result with
`xdg-mime query default x-scheme-handler/slack`, or click a `slack://` link.

For a launcher key, put `flatpak-wm env` in front, for example `flatpak-wm env rofi -show drun`. (The key bindings in
my [Super-key repo](https://github.com/jaderfeijo/wmaker-super-keys) use a launcher script that does the same thing.)

## Install

```
git clone https://github.com/jaderfeijo/wmodern.git && cd wmodern/modules/flatpak
./install.sh --dry-run
./install.sh            # puts `flatpak-wm` in ~/.local/bin (--install-deps to apt-install flatpak and xdg-utils)
```

`./install.sh --uninstall` removes the command. `flatpak-wm fix` only ever adds one clearly marked block to
`~/.xsessionrc`, and running it twice does not duplicate it.

Tested on Debian 13 with Window Maker 0.96, system-wide Flatpak and the Slack Flatpak: the check, `fix` in a scratch home
directory (run twice), and `handler` against the real Slack app. I did not test a user-level installation.

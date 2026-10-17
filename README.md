<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="logo/wmodern-dark.svg">
    <img src="logo/wmodern.svg" alt="wmodern" height="90">
  </picture>
</p>

<p align="center"><b>A modern desktop on <a href="https://www.windowmaker.org/">Window Maker</a>.</b><br>
Pick the pieces you want; wmodern installs them, and keeps them up to date.</p>

Window Maker is small, fast and stays out of the way, and it ships with almost nothing: no launcher, no media keys,
no screen lock, no power menu, no clipboard that works between programs. This repository is my setup on Debian 13
(X11), written up as independent pieces. Take one, or take all of them.

## Install

```
curl -fsSL https://raw.githubusercontent.com/jaderfeijo/wmodern/main/install.sh | bash
```

A menu opens: **up/down** to move, **space** to select or unselect, **a** all, **n** none, **u** everything with an
update, **Enter** to install, **q** to quit. It then shows what it is going to do and asks once before it starts.
To look first: add `-s -- --dry-run` after `bash`, or read [`install.sh`](install.sh).

* **Safe to run again.** Each item records the version it installed. Running it again re-applies what you select
  without duplicating anything, and marks items that have a newer version as *update available*.
* **Updating.** The first run installs the command `wmodern` into `~/.local/bin`:
  `wmodern update` installs newer versions of everything you have (and updates itself first), `wmodern` shows the menu,
  `wmodern list` shows what is installed, `wmodern remove ID` uninstalls an item.
* **Your session is left alone.** It never restarts Window Maker or anything running: log out and in when it is done.
  Everything goes into your home directory, except the packages it asks `sudo apt-get` for (shown first) and the few
  files the power-button menu needs in `/etc`.
* **Options:** `--dry-run`, `--yes`, `--no-sudo` (no apt, no `/etc`), and item names, for example
  `... | bash -s -- install focus lock xterm --yes`.

## What is in it

| Item | What it does |
|---|---|
| [`super-keys`](https://github.com/jaderfeijo/wmaker-super-keys) | macOS-style **Super-key shortcuts**: `Super+Space` launcher, tiling and centering, directional focus (`Super+arrows`), desktops created on demand, move window to desktop, cycle windows of one application, show desktop. |
| [`focus`](modules/focus) | **Focus follows mouse** with instant auto-raise, and the gotcha that Window Maker must be restarted to read it. |
| [`shade-all`](modules/shade-all) | **Shade all windows**: one key rolls up every window on the desktop to its title bar, again to unroll. Takes `Super+Shift+H` from the show-desktop binding of `super-keys` (the installer handles that). |
| [`thinkpad`](modules/thinkpad) | **Lenovo ThinkPad keys**: brightness, volume, mute and microphone-mute with an on-screen bar, mute LEDs, tap-to-click for the touchpad. |
| [`power`](modules/power) | **Power-button menu** (lock, suspend, hibernate, log out, restart, shut down) through `acpid` and rofi. |
| [`lock`](modules/lock) | **Lock on suspend** and on `loginctl lock-session`, with `xss-lock` and `i3lock`. |
| [`xterm`](modules/xterm) | **xterm clipboard** that works (Ctrl+Shift+C/V, Super+C/V, OSC 52), **Ctrl+click on a link** (opens in Chromium on the current desktop), the xterm menu on right click, and an optional text scale (`Xft.dpi`), with the custom-window-class trap explained. |
| [`caps-lock`](modules/caps-lock) | **Normal Caps Lock**: Debian's Window Maker turns Caps Lock into the Compose key at every login; this removes `compose:caps` for good (and only that option) and switches Debian's startup script off. |
| [`no-welcome`](modules/no-welcome) | **No welcome window**: switches off the welcome window Debian's Window Maker live packages show at every login (moved to `AutoStart/Disabled`, nothing deleted). |
| [`quiet-move`](modules/quiet-move) | **No move tooltip**: hides the position box Window Maker shows in the corner while you drag a window (`MoveDisplay = none`). |
| [`workspace-name`](modules/workspace-name) | **Workspace name flash**: shows the name of the workspace in the centre of the screen when you switch (`WorkspaceNameDisplayPosition = center`). |
| [`window-keys`](modules/window-keys) | **Super+Q and resize keys**: Super+Q closes the window, also the highlighted one in the Super+Tab switcher; Super+Shift+Alt `+`/`-` resize it around its centre (Control for bigger steps). |
| [`fixed-nerd`](https://github.com/jaderfeijo/fixed-nerd) | **Fixed Nerd font**: the classic X11 `fixed` 6x13 bitmap font extended with Powerline, Nerd Font icons and the symbols coding TUIs (Claude Code, lazygit, btop, ...) use, as the default font of xterm and uxterm. |
| [`webapp`](modules/webapp) | **Web apps**: `webapp add NAME URL` makes a launcher entry that opens a site in a tab-less Chromium window. |
| [`default-browser`](modules/default-browser) | **Chromium as the default browser** in all three places a link can look (`xdg-settings`, the Xfce helper, the `x-www-browser` alternative); remove restores the old values. |
| [`chromium-scale`](modules/chromium-scale) | **Smaller Chromium**: its interface and every web page at 80% (20% smaller than stock) with `--force-device-scale-factor`, through the launcher; any value from 25 to 300. |
| [`flatpak`](modules/flatpak) | **Flatpak in the session**: launcher visibility and `slack://`-style sign-in links. |
| [`omarchy`](modules/omarchy) | **Omarchy ports**: Omarchy's web-app and TUI launcher installers (unmodified), a searchable web-app catalog and fzf pickers for apt and Flatpak, adapted to Window Maker. |
| [`pwvol`](https://github.com/jaderfeijo/wmpwvol) | **Volume dockapp** for PipeWire: live level meter, red crossed-out speaker when muted. |
| [`bluetooth`](https://github.com/jaderfeijo/wmbluetooth) | **Bluetooth dockapp**: connected devices and their batteries; click to connect. |
| [`battery`](https://github.com/jaderfeijo/wmbattery-power-draw) | **Battery dockapp showing watts**: a patch for Debian's `wmbattery`, built from source. |
| [`getapp`](https://github.com/jaderfeijo/getapp) | **One fuzzy search to install anything**: apt, Flatpak, the Snap Store and web apps in one list. |

Items in [`modules/`](modules) live in this repository; the larger programs keep their own repositories
(each with its own tests and history) and are installed from there. Each module has its own README and its own
installer, so you can also use one without wmodern: `git clone` this repository and run
`modules/<name>/install.sh --help`.

## How the pieces fit together

* **No framework.** Plain shell and a little Python, small files that do one thing, and standard tools
  (`xbindkeys`, `wmctrl`, `rofi`, `xss-lock`, `dunst`, `wpctl`).
* **Nothing is replaced.** Installers add a clearly marked block (`# >>> name >>>` ... `# <<< name <<<`) to your
  `~/.xbindkeysrc`, Window Maker `autostart`, `~/.Xresources`; running them twice does not duplicate it, and
  `--uninstall` removes exactly that block. For Window Maker's own settings they keep a one-time backup.
* **Every app is in the launcher.** Apps wmodern installs, and apps you install later (apt, Flatpak, web apps, ...), get a
  `.desktop` entry so they show in `Super+Space`.
* **Everything has `--dry-run`** and `--uninstall`.
* **Nothing about the author's machine** is in here: no host names, home paths or addresses (checked by the tests).

## Tests

```
tests/run.sh
```

Syntax checks, a privacy scan, and the installer driven in a scratch home directory with no display: install,
install again (nothing changes), update detection, update, remove.

## Contributing a module

Add `modules/<name>/` with a `README.md` and an installer that is idempotent and supports `--dry-run` and
`--uninstall`, then add one line to the `CATALOGUE` and the two `case` blocks in `install.sh`.

## Licence

[MIT](LICENSE).

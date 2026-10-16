# Omarchy ports: web apps, TUI launchers and software pickers on Window Maker

> Module `omarchy` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install omarchy`, or use it on its own as described below.

[Omarchy](https://github.com/basecamp/omarchy) has small, well-made scripts for turning websites and terminal programs
into launcher entries, and a menu to install software. They are written for Hyprland, walker and a particular
terminal. This module runs them on Window Maker: the Omarchy scripts are used **unmodified**, with a few small shims in
their place and some extra scripts around them.

## What you get

| Command | What it does |
|---|---|
| `omarchy-webapp-install` / `omarchy-webapp-remove` | Make or delete a launcher entry that opens a site in a tab-less Chromium window (asks for name, URL and icon with `gum`; fetches the site's icon). **Omarchy's, unmodified.** |
| `omarchy-tui-install` / `omarchy-tui-remove` | The same for a terminal program: a launcher entry that opens it in an xterm. **Omarchy's, unmodified.** |
| `omarchy-webapp-window-class` | Prints the window class Chromium gives an app window, for `StartupWMClass`. **Omarchy's, unmodified.** |
| `webapp-catalog` | A searchable list of about 30 well-known web apps (Gmail, WhatsApp, YouTube, ...). Pick one to install it, pick an installed one to remove it, or choose "Custom URL". |
| `software-install`, `software-remove` | Pick apt packages with fzf (Tab to select several), with a preview. |
| `software-flatpak`, `software-flatpak-remove` | The same for Flathub apps. |

Launcher entries for these are added too (Web Apps, Install Software, Remove Software, Install Flatpak App, Remove
Flatpak App), so they appear in rofi next to everything else.

**The shims** replace what Omarchy gets from its desktop: `omarchy-i18n` (English only, reads `data/en-cli.json`),
`omarchy-launch-webapp` (`chromium --app=URL`), `omarchy-menu-select` (rofi), `omarchy-notification-send`
(`notify-send`) and `xdg-terminal-exec` (an xterm with the requested window class; an existing real
`xdg-terminal-exec` is never replaced).

## Install

```
git clone https://github.com/jaderfeijo/wmodern.git && cd wmodern/modules/omarchy
./install.sh --dry-run            # look first
./install.sh --install-deps       # scripts into ~/.local/bin, data into ~/.local/share/omarchy-port
```

Needs `gum`, `jq`, `fzf`, `rofi`, `curl`, `file`, `xterm` and `chromium` (all in Debian 13). `./install.sh --uninstall`
removes the scripts it installed (a script you changed is kept) and the launcher entries; web apps you made with it
stay until you remove them with `omarchy-webapp-remove`.

## How it relates to the other pieces

* The `webapp` module is a small standalone command that does what `omarchy-webapp-install` does. Use either; they
  do not conflict (different command names), and `webapp-catalog` lists apps made by `omarchy-webapp-install` only.
* The `getapp` item is a single search over apt, Flatpak, the Snap Store **and** web apps. The `software-*` pickers
  here are the simpler one-source versions.

## Licence

The scripts named *unmodified* above, and `data/en-cli.json`, are from Omarchy, Copyright (c) David Heinemeier
Hansson, used under the MIT licence, which is included as [`LICENSE-omarchy`](LICENSE-omarchy). The shims, the catalog and
the other scripts are part of wmodern (MIT).

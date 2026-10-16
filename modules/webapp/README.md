# Window Maker: web apps as launcher entries (Chromium `--app`)

> Module `webapp` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install webapp`, or use it on its own as described below.

Slack, WhatsApp Web, YouTube, a dashboard: a website you use like an application is nicer in a window of its own, with
no tabs and no address bar, found in the launcher like any other program. Chromium does this with
`chromium --app=URL`. Window Maker has nothing to make the launcher entry, so this is a single script that does:

```
webapp add "WhatsApp" web.whatsapp.com          # fetches the site's icon, writes the launcher entry
webapp add "Dashboard" https://example.com/d  ~/Pictures/dash.png
webapp list
webapp remove "WhatsApp"
```

The idea comes from [Omarchy](https://github.com/basecamp/omarchy)'s web-app installer; this is a small standalone
rewrite for any Debian system, with no dependency on it.

## What it does

* Writes `~/.local/share/applications/<Name>.desktop` with `Exec=chromium --app="URL"`. Rofi, dmenu-style launchers and
  every freedesktop menu find it.
* Fetches the **site's own icon**: the `apple-touch-icon` (usually 180 px or more), then `/apple-touch-icon.png`, then
  Google's favicon service as a last resort. You can pass your own image file, image URL or icon-theme name instead.
* Sets **`StartupWMClass`** to the window class Chromium gives an app window (`chrome-<host>__<path>-Default`), so
  docks and taskbars can match the running window to the entry and its icon. Without it every web app looks like
  "Chromium".
* Marks its entries with `X-Webapp-Source=chromium-app`, so `list` and `remove` only ever touch what it made.

Safety details worth copying if you write your own: it refuses anything that is not `http(s)` (Chromium's `--app=`
would run a `javascript:`, `file:` or `data:` address), refuses spaces in the address (they would split the browser
arguments), refuses a name containing `/` (it becomes a file name), escapes newlines in every value written to the
`.desktop` file (a newline would start a second `Exec=` line), and quotes the address as one `Exec` argument.

## Install

```
git clone https://github.com/jaderfeijo/wmodern.git && cd wmodern/modules/webapp
./install.sh --dry-run
./install.sh --install-deps          # puts `webapp` in ~/.local/bin; apt-installs chromium, curl, file if missing
```

Needs `bash`, `curl`, `file` and a Chromium-family browser (`chromium`, `google-chrome`, `brave-browser`,
`microsoft-edge`; set `WEBAPP_BROWSER` to choose). `./install.sh --uninstall` removes the command.

## Notes

* A web app uses your normal Chromium profile, so sign-ins are shared with the browser. For a separate profile add
  `--user-data-dir=...` to the `Exec=` line of the entry.
* **Slack, Teams and similar** sign in through a `slack://`-style redirect that has to reach a handler. See the `flatpak`
  module if you installed those as Flatpaks.
* If you want one search box for web apps, Flatpak, apt and Snap at once, my
  [`getapp`](https://github.com/jaderfeijo/getapp) lists a catalog of about 90 web apps and installs them the same way.
* Tested on Debian 13 with Chromium: adding, listing, removing, the refusals above, and the icon fetch.

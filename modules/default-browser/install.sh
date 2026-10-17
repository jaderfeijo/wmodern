#!/usr/bin/env bash
# Make Chromium (or another browser) the default browser everywhere a link can come from.
#
#   ./install.sh                     Chromium
#   ./install.sh --browser NAME      another browser; NAME.desktop must exist (for example firefox-esr)
#   ./install.sh --no-system         skip the x-www-browser alternative (needs sudo)
#   ./install.sh --uninstall         put back what was set before
#   ./install.sh --dry-run           show what would change
#
# Three places decide where a link opens, and on a bare Window Maker session they can disagree:
#   1. xdg-settings default-web-browser   what xdg-open and most programs use
#   2. WebBrowser= in ~/.config/xfce4/helpers.rc   what xdg-open asks when Xfce's helper is the default (only if
#      that file exists; the browser needs a helper entry in /usr/share/xfce4/helpers)
#   3. the x-www-browser alternative (/etc/alternatives, sudo)   what "sensible-browser" style launchers use
# The values found before the first run are kept in ~/.local/share/wmodern-default-browser/ for --uninstall.
set -euo pipefail

BROWSER=chromium NOSYSTEM=0 DRY=0 UNINSTALL=0
HELPERS="${XDG_CONFIG_HOME:-$HOME/.config}/xfce4/helpers.rc"
STATE="${XDG_DATA_HOME:-$HOME/.local/share}/wmodern-default-browser"
while [ $# -gt 0 ]; do
  case "$1" in
    --browser) BROWSER="${2:?--browser needs a name}"; shift ;;
    --no-system) NOSYSTEM=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
[[ "$BROWSER" =~ ^[A-Za-z0-9._+-]+$ ]] || { echo "bad browser name: $BROWSER" >&2; exit 2; }
BROWSER=${BROWSER%.desktop}

say() { echo "$([ "$DRY" = 1 ] && echo '[dry-run] ')$*"; }
run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
have() { command -v "$1" >/dev/null 2>&1; }

# the x-www-browser alternative that points at BROWSER's binary (chromium -> /usr/bin/chromium)
alt_target() { local p; p=$(command -v "$BROWSER" 2>/dev/null) || p="/usr/bin/$BROWSER"; echo "$p"; }

if [ "$UNINSTALL" = 1 ]; then
  if [ ! -d "$STATE" ]; then echo "Nothing to undo (no saved settings in $STATE)."; exit 0; fi
  if [ -s "$STATE/xdg" ] && have xdg-settings; then run xdg-settings set default-web-browser "$(cat "$STATE/xdg")" || echo "Could not restore xdg-settings." >&2; fi
  if [ -s "$STATE/helper" ] && [ -f "$HELPERS" ]; then
    say "WebBrowser=$(cat "$STATE/helper") in $HELPERS"
    [ "$DRY" = 1 ] || sed -i "s/^WebBrowser=.*/WebBrowser=$(cat "$STATE/helper")/" "$HELPERS"
  fi
  if [ "$NOSYSTEM" = 0 ] && [ -f "$STATE/alternative-manual" ] && have update-alternatives; then
    if [ -s "$STATE/alternative" ]; then run sudo update-alternatives --set x-www-browser "$(cat "$STATE/alternative")"
    else run sudo update-alternatives --auto x-www-browser; fi
  fi
  run rm -rf "$STATE"
  echo "Previous default browser settings restored."; exit 0
fi

DESKTOP="$BROWSER.desktop"
if [ ! -e "/usr/share/applications/$DESKTOP" ] && [ ! -e "${XDG_DATA_HOME:-$HOME/.local/share}/applications/$DESKTOP" ]; then
  echo "Warning: $DESKTOP not found; is $BROWSER installed? Continuing with what can be set." >&2
fi

# remember the old values once, before the first change
if [ ! -d "$STATE" ] && [ "$DRY" = 0 ]; then
  mkdir -p "$STATE"
  have xdg-settings && xdg-settings get default-web-browser > "$STATE/xdg" 2>/dev/null || : > "$STATE/xdg"
  [ -f "$HELPERS" ] && sed -n 's/^WebBrowser=//p' "$HELPERS" | head -1 > "$STATE/helper" || : > "$STATE/helper"
  if have update-alternatives && update-alternatives --query x-www-browser 2>/dev/null | grep -q '^Status: manual'; then
    : > "$STATE/alternative-manual"; update-alternatives --query x-www-browser | sed -n 's/^Value: //p' > "$STATE/alternative"
  fi
fi

if have xdg-settings; then
  run xdg-settings set default-web-browser "$DESKTOP" || echo "Could not set xdg-settings (is $DESKTOP installed?)." >&2
  [ "$DRY" = 1 ] || echo "xdg-settings: default-web-browser = $(xdg-settings get default-web-browser 2>/dev/null || echo '?')"
else echo "xdg-settings not found (package xdg-utils); skipped." >&2; fi

if [ -f "$HELPERS" ]; then
  if [ -e "/usr/share/xfce4/helpers/$DESKTOP" ]; then
    say "WebBrowser=$BROWSER in $HELPERS"
    [ "$DRY" = 1 ] || sed -i "s/^WebBrowser=.*/WebBrowser=$BROWSER/" "$HELPERS"
  else echo "No Xfce helper for $BROWSER (/usr/share/xfce4/helpers/$DESKTOP); left $HELPERS alone." >&2; fi
fi

if [ "$NOSYSTEM" = 1 ]; then
  echo "Skipped the x-www-browser alternative (--no-system). To set it:  sudo update-alternatives --set x-www-browser $(alt_target)"
elif have update-alternatives; then
  if update-alternatives --list x-www-browser 2>/dev/null | grep -qx "$(alt_target)"; then
    run sudo update-alternatives --set x-www-browser "$(alt_target)"
  else echo "$(alt_target) is not an x-www-browser alternative; skipped." >&2; fi
fi
echo "Done. Links from xdg-open (and so from xterm Ctrl+click) now open in $BROWSER."

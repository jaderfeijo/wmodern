#!/usr/bin/env bash
# Text scale (Xft.dpi), xterm clipboard settings, ctrl+click on links and a right-click menu, written as a marked
# block into ~/.Xresources, plus the xterm-open-url helper in ~/.local/bin.
# Run ./install.sh --help for the options. Nothing of yours is replaced; --uninstall removes the block again.
set -euo pipefail

NAME=xterm-clipboard
XRES="${XRESOURCES_FILE:-$HOME/.Xresources}"
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BIN="${WMC_BIN_DIR:-$HOME/.local/bin}"
OPENER="$BIN/xterm-open-url"
DPI="" CLASSES=() SUPER=1 OSC52=1 URLCLICK=1 RIGHTMENU=1 DRY=0 UNINSTALL=0 APPLY=1

while [ $# -gt 0 ]; do
  case "$1" in
    --dpi) DPI="${2:?--dpi needs a number}"; shift ;;
    --class) CLASSES+=("${2:?--class needs a window class}"); shift ;;
    --no-super) SUPER=0 ;;
    --no-osc52) OSC52=0 ;;
    --no-url-click) URLCLICK=0 ;;
    --no-right-menu) RIGHTMENU=0 ;;
    --no-apply) APPLY=0 ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help)
      cat <<USAGE
Usage: ./install.sh [--dpi N] [--class NAME]... [--no-super] [--no-osc52] [--no-url-click] [--no-right-menu] [--dry-run] [--no-apply] [--uninstall]
  --dpi N        set Xft.dpi (text scale for GTK/Qt apps; 96 is normal, 72 makes text 25% smaller, 120 larger)
  --class NAME   also give xterm windows started with "-class NAME" the same settings (repeatable)
  --no-super     do not bind Super+C / Super+V (Ctrl+Shift+C/V and Shift+Insert are always added)
  --no-osc52     do not let programs set the clipboard with the OSC 52 escape sequence
  --no-url-click do not make Ctrl+click on a link open it (in Chromium/Chrome on the current desktop)
  --no-right-menu do not move xterm's main menu from Ctrl+left click to the right mouse button
  --no-apply     do not run xrdb now (the settings then take effect at next login)
USAGE
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
[ -z "$DPI" ] || [[ "$DPI" =~ ^[0-9]+$ ]] || { echo "--dpi must be a whole number" >&2; exit 2; }
for c in "${CLASSES[@]}"; do [[ "$c" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] || { echo "bad class name: $c" >&2; exit 2; }; done

block() {  # block add|remove FILE [CONTENT_FILE]
  [ "$DRY" = 1 ] && { echo "[dry-run] block $1 in $2"; return 0; }
  python3 - "$1" "$2" "${3:-}" "$NAME" <<'PY'
import os, re, sys
action, path, content, name = sys.argv[1:5]
begin, end = f"! >>> {name} >>>", f"! <<< {name} <<<"
text = open(path).read() if os.path.exists(path) else ""
text = re.sub(r"(?ms)^" + re.escape(begin) + r"\n.*?^" + re.escape(end) + r"\n?", "", text)
text = text.rstrip("\n")
if action == "add":
    text = (text + "\n\n" if text else "") + f"{begin}\n{open(content).read().rstrip()}\n{end}"
open(path, "w").write(text + "\n" if text else "")
PY
}

if [ "$UNINSTALL" = 1 ]; then
  block remove "$XRES"
  if [ "$DRY" = 1 ]; then echo "[dry-run] remove $OPENER"; else rm -f "$OPENER"; fi
  [ "$DRY" = 0 ] && [ "$APPLY" = 1 ] && [ -n "${DISPLAY:-}" ] && echo "Removed. Log out and in (or restart the apps) for the old values to return; xrdb cannot delete keys."
  echo "Removed the $NAME block from $XRES."; exit 0
fi

URL_REGEX='[a-zA-Z][a-zA-Z0-9+.-]*:[/][/][-[:alnum:]_.~:/?#@!$&*+,;=%]+'
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
{
  [ -z "$DPI" ] || printf '%s\n\n' "Xft.dpi: $DPI"
  for cls in XTerm UXTerm "${CLASSES[@]}"; do
    binds=("Ctrl Shift <Key>C: copy-selection(CLIPBOARD)" "Ctrl Shift <Key>V: insert-selection(CLIPBOARD)")
    [ "$SUPER" = 1 ] && binds+=("Mod4 <Key>c: copy-selection(CLIPBOARD)" "Mod4 <Key>v: insert-selection(CLIPBOARD)")
    binds+=("Shift <Key>Insert: insert-selection(CLIPBOARD)")
    # Ctrl+click opens the URL under the pointer. exec-selectable reads it from the screen, so nothing is selected.
    # The regex avoids a literal "//" (xrdb's cpp would treat it as a comment and cut the value off) and the
    # translation string may not contain a double quote or backslash (Xt cannot parse them).
    [ "$URLCLICK" = 1 ] && binds+=("Ctrl <Btn1Down>: ignore()" "Ctrl <Btn1Up>: exec-selectable(\"xterm-open-url '%t'\", \"regex $URL_REGEX\")")
    [ "$RIGHTMENU" = 1 ] && binds+=("<Btn3Down>: popup-menu(mainMenu)")
    printf '%s*selectToClipboard: true\n' "$cls"
    [ "$OSC52" = 1 ] && printf '%s*disallowedWindowOps: 20,21,SetXprop\n' "$cls"
    printf '%s*VT100.translations: #override \\n\\\n' "$cls"
    for i in "${!binds[@]}"; do
      if [ "$i" -lt $((${#binds[@]} - 1)) ]; then printf '    %s \\n\\\n' "${binds[$i]}"; else printf '    %s\n\n' "${binds[$i]}"; fi
    done
  done
  [ "$OSC52" = 1 ] && printf '%s\n' 'XTerm*allowWindowOps: false' 'UXTerm*allowWindowOps: false'
} > "$tmp"

if [ "$URLCLICK" = 1 ]; then
  if [ "$DRY" = 1 ]; then echo "[dry-run] install $OPENER"; else mkdir -p "$BIN"; install -m 755 "$HERE/xterm-open-url" "$OPENER"; fi
  { command -v xdotool >/dev/null && command -v xprop >/dev/null; } ||
    echo "Note: install xdotool and x11-utils for 'open on the current desktop'; links open with xdg-open until then."
elif [ "$DRY" = 0 ]; then rm -f "$OPENER"; fi

if [ "$DRY" = 1 ]; then echo "[dry-run] would add to $XRES:"; sed 's/^/    /' "$tmp"; fi
block add "$XRES" "$tmp"
if [ "$DRY" = 1 ]; then echo "(dry run: nothing was written)"; else echo "Settings written to $XRES."; fi
if [ "$APPLY" = 1 ] && [ "$DRY" = 0 ]; then
  if [ -n "${DISPLAY:-}" ] && command -v xrdb >/dev/null; then
    xrdb -merge "$XRES" && echo "Loaded with xrdb. New xterm windows use it now; already open ones and GTK apps need a restart."
  else echo "No X display here: the settings load at your next login (or run: xrdb -merge $XRES)."; fi
fi
grep -qs 'xrdb' "${GNUSTEP_USER_ROOT:-$HOME/GNUstep}/Library/WindowMaker/autostart" 2>/dev/null ||
  echo "Note: Window Maker does not load ~/.Xresources by itself; put  xrdb -merge ~/.Xresources  in its autostart file."

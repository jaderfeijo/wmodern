#!/usr/bin/env bash
# Text scale (Xft.dpi) and xterm clipboard settings, written as a marked block into ~/.Xresources.
# Run ./install.sh --help for the options. Nothing of yours is replaced; --uninstall removes the block again.
set -euo pipefail

NAME=xterm-clipboard
XRES="${XRESOURCES_FILE:-$HOME/.Xresources}"
DPI="" CLASSES=() SUPER=1 OSC52=1 DRY=0 UNINSTALL=0 APPLY=1

while [ $# -gt 0 ]; do
  case "$1" in
    --dpi) DPI="${2:?--dpi needs a number}"; shift ;;
    --class) CLASSES+=("${2:?--class needs a window class}"); shift ;;
    --no-super) SUPER=0 ;;
    --no-osc52) OSC52=0 ;;
    --no-apply) APPLY=0 ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help)
      cat <<USAGE
Usage: ./install.sh [--dpi N] [--class NAME]... [--no-super] [--no-osc52] [--dry-run] [--no-apply] [--uninstall]
  --dpi N        set Xft.dpi (text scale for GTK/Qt apps; 96 is normal, 72 makes text 25% smaller, 120 larger)
  --class NAME   also give xterm windows started with "-class NAME" the same settings (repeatable)
  --no-super     do not bind Super+C / Super+V (Ctrl+Shift+C/V and Shift+Insert are always added)
  --no-osc52     do not let programs set the clipboard with the OSC 52 escape sequence
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
  [ "$DRY" = 0 ] && [ "$APPLY" = 1 ] && [ -n "${DISPLAY:-}" ] && echo "Removed. Log out and in (or restart the apps) for the old values to return; xrdb cannot delete keys."
  echo "Removed the $NAME block from $XRES."; exit 0
fi

tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
{
  [ -z "$DPI" ] || printf '%s\n\n' "Xft.dpi: $DPI"
  for cls in XTerm "${CLASSES[@]}"; do
    printf '%s*selectToClipboard: true\n' "$cls"
    [ "$OSC52" = 1 ] && printf '%s*disallowedWindowOps: 20,21,SetXprop\n' "$cls"
    printf '%s*VT100.translations: #override \\n\\\n' "$cls"
    printf '    Ctrl Shift <Key>C: copy-selection(CLIPBOARD) \\n\\\n'
    printf '    Ctrl Shift <Key>V: insert-selection(CLIPBOARD) \\n\\\n'
    [ "$SUPER" = 1 ] && printf '    Mod4 <Key>c: copy-selection(CLIPBOARD) \\n\\\n    Mod4 <Key>v: insert-selection(CLIPBOARD) \\n\\\n'
    printf '    Shift <Key>Insert: insert-selection(CLIPBOARD)\n\n'
  done
  [ "$OSC52" = 1 ] && printf '%s\n' 'XTerm*allowWindowOps: false'
} > "$tmp"

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

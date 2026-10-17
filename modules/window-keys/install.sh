#!/usr/bin/env bash
# Window keys: Super+Q closes the focused window (also the one highlighted in the Super+Tab switcher), and
# Super+Shift+Alt +/- resize it around its centre (add Control for bigger steps). Super+W keeps closing windows too.
# Run ./install.sh --help for the options. A marked block is added to ~/.xbindkeysrc; --uninstall removes it again.
set -euo pipefail

NAME=wmodern-window-keys
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX="${PREFIX:-$HOME/.local}"
XBINDKEYSRC="$HOME/.xbindkeysrc"
WMDEFAULTS="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}/Defaults/WindowMaker"
DRY=0 UNINSTALL=0 RESTART=1 DEPS=1 INSTALL_DEPS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="${2:?--prefix needs a directory}"; shift ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --no-restart) RESTART=0 ;;
    --install-deps) INSTALL_DEPS=1 ;;
    --skip-deps-check) DEPS=0 ;;
    -h|--help) echo "Usage: ./install.sh [--prefix DIR] [--dry-run] [--uninstall] [--install-deps] [--no-restart]"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
BIN="$PREFIX/bin"

have() { command -v "$1" >/dev/null 2>&1; }
run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
block() {  # block add|remove FILE [CONTENT_FILE]
  [ "$DRY" = 1 ] && { echo "[dry-run] block $1 in $2"; return 0; }
  python3 - "$1" "$2" "${3:-}" "$NAME" <<'PY'
import os, re, sys
action, path, content, name = sys.argv[1:5]
begin, end = f"# >>> {name} >>>", f"# <<< {name} <<<"
text = open(path).read() if os.path.exists(path) else None
if text is None and action == "remove":
    sys.exit(0)
text = re.sub(r"(?ms)^" + re.escape(begin) + r"\n.*?^" + re.escape(end) + r"\n?", "", text or "")
text = re.sub(r"\n{3,}", "\n\n", text).lstrip("\n")
if action == "remove":
    text = text.rstrip("\n") + "\n" if text.strip() else ""
else:
    text = text.rstrip("\n"); text = (text + "\n\n" if text else "") + f"{begin}\n{open(content).read().rstrip()}\n{end}\n"
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
open(path, "w").write(text)
PY
}
set_close_key() {  # Window Maker's own CloseKey, so Super+Q also works while the Super+Tab switcher is open
  [ "$DRY" = 1 ] && { echo "[dry-run] CloseKey = \"$1\" in $WMDEFAULTS"; return 0; }
  python3 - "$WMDEFAULTS" "$1" <<'PY'
import os, re, shutil, sys
path, value = sys.argv[1:3]
text = open(path).read() if os.path.exists(path) else "{\n}\n"
pattern = re.compile(r"(?m)^([ \t]*)CloseKey[ \t]*=[ \t]*[^;\n]*;[ \t]*$")
if pattern.search(text):
    text = pattern.sub(lambda m: f'{m.group(1)}CloseKey = "{value}";', text, count=1)
else:
    close = text.rstrip().rfind("}")
    text = text[:close] + f'  CloseKey = "{value}";\n' + text[close:]
os.makedirs(os.path.dirname(path), exist_ok=True)
backup = path + ".bak-window-keys"
if os.path.exists(path) and not os.path.exists(backup):
    shutil.copy2(path, backup)
open(path, "w").write(text)
PY
  # SIGUSR2 makes the running Window Maker re-read its defaults. Only the real one gets it: Debian's wrapper process
  # has the same name, and the signal would terminate it (and the session with it).
  if [ -n "${DISPLAY:-}" ] && pgrep -f -- 'wmaker --for-real' >/dev/null 2>&1; then pkill -USR2 -f -- 'wmaker --for-real' 2>/dev/null || true; echo "Window Maker CloseKey is now $1 (reloaded in the running session)."
  else echo "Window Maker CloseKey is now $1 (used when Window Maker next starts)."; fi
}
restart_xbindkeys() {
  if [ "$RESTART" = 1 ] && [ "$DRY" = 0 ] && [ -n "${DISPLAY:-}" ] && have xbindkeys; then
    pkill -x xbindkeys 2>/dev/null || true; sleep 0.3; (setsid xbindkeys >/dev/null 2>&1 &); echo "xbindkeys restarted."
  fi
}

if [ "$UNINSTALL" = 1 ]; then
  run rm -f -- "$BIN/wmodern-resize" "$BIN/wmodern-move"; block remove "$XBINDKEYSRC"; set_close_key "Mod4+W"
  restart_xbindkeys
  echo "Removed. Super+W closes windows again."; exit 0
fi

if [ "$DEPS" = 1 ]; then
  missing=(); have wmctrl || missing+=(wmctrl); have xprop || missing+=(x11-utils); have xbindkeys || missing+=(xbindkeys); have python3 || missing+=(python3)
  if [ "${#missing[@]}" -gt 0 ]; then
    if [ "$INSTALL_DEPS" = 1 ] && have apt-get; then run sudo apt-get install -y "${missing[@]}"
    else echo "Missing: ${missing[*]}. Install them with:  sudo apt install ${missing[*]}   (or use --install-deps)"; [ "$DRY" = 1 ] || exit 1; fi
  fi
fi

run install -D -m 755 "$HERE/wmodern-resize" "$BIN/wmodern-resize"
run install -D -m 755 "$HERE/wmodern-move" "$BIN/wmodern-move"
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
{
  echo "# Super+W closes the focused window (Super+Q does too, through Window Maker itself)"
  printf '"wmctrl -c :ACTIVE:"\n    Mod4 + w\n\n'
  echo "# Resize the focused window around its centre: Super+Shift+Alt +/- (small), add Control (large)"
  for k in plus equal KP_Add; do printf '"%s/wmodern-resize grow small"\n    Mod4 + Shift + Mod1 + %s\n\n' "$BIN" "$k"; done
  for k in minus underscore KP_Subtract; do printf '"%s/wmodern-resize shrink small"\n    Mod4 + Shift + Mod1 + %s\n\n' "$BIN" "$k"; done
  for k in plus equal KP_Add; do printf '"%s/wmodern-resize grow large"\n    Mod4 + Shift + Mod1 + Control + %s\n\n' "$BIN" "$k"; done
  for k in minus underscore KP_Subtract; do printf '"%s/wmodern-resize shrink large"\n    Mod4 + Shift + Mod1 + Control + %s\n\n' "$BIN" "$k"; done
  echo "# Move the focused window: Super+Shift+Alt+arrows (small), add Control (large)"
  for k in Left Right Up Down; do
    printf '"%s/wmodern-move %s small"\n    Mod4 + Shift + Mod1 + %s\n\n' "$BIN" "${k,,}" "$k"
    printf '"%s/wmodern-move %s large"\n    Mod4 + Shift + Mod1 + Control + %s\n\n' "$BIN" "${k,,}" "$k"
  done
} > "$tmp"
block add "$XBINDKEYSRC" "$tmp"
set_close_key "Mod4+Q"
restart_xbindkeys
echo "Installed $BIN/wmodern-resize and $BIN/wmodern-move. Autostart xbindkeys if it is not already."

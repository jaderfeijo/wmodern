#!/usr/bin/env bash
# Installs the ThinkPad key fixes from this module. Run ./setup.sh --help for the options.
# It never replaces your config files: it adds a clearly marked block, and --uninstall removes it again.
set -euo pipefail

NAME=thinkpad-fixes
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX="${PREFIX:-$HOME/.local}"
AUTOSTART="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}/Library/WindowMaker/autostart"
XBINDKEYSRC="$HOME/.xbindkeysrc"
DUNSTRC="${XDG_CONFIG_HOME:-$HOME/.config}/dunst/dunstrc"
DRY=0 UNINSTALL=0 TOUCHPAD=1 RESTART=1 DEPS=1

while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) UNINSTALL=1 ;;
    --dry-run) DRY=1 ;;
    --no-touchpad) TOUCHPAD=0 ;;
    --no-restart) RESTART=0 ;;
    --skip-deps-check) DEPS=0 ;;
    --prefix) PREFIX="${2:?--prefix needs a directory}"; shift ;;
    --autostart-file) AUTOSTART="${2:?--autostart-file needs a path}"; shift ;;
    -h|--help)
      cat <<USAGE
Usage: ./setup.sh [--dry-run] [--uninstall] [--no-touchpad] [--no-restart] [--prefix DIR] [--autostart-file FILE]
  installs osd (+ touchpad-tap) into DIR/bin, the key bindings into ~/.xbindkeysrc, a dunst config if you have
  none, and the start-up lines into Window Maker's autostart file (or FILE, for another window manager).
USAGE
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
BIN="$PREFIX/bin"

# --- marked blocks (exact and idempotent) ---------------------------------------------------------
block() {  # block add|remove FILE [CONTENT_FILE]   ("add" puts the block before a final "exit 0" if there is one)
  [ "$DRY" = 1 ] && { echo "[dry-run] block $1 in $2"; return 0; }
  python3 - "$1" "$2" "${3:-}" "$NAME" <<'PY'
import os, re, sys
action, path, content, name = sys.argv[1:5]
begin, end = f"# >>> {name} >>>", f"# <<< {name} <<<"
text = open(path).read() if os.path.exists(path) else None
if text is None and action == "remove":
    sys.exit(0)
text = text or ""
text = re.sub(r"(?ms)^" + re.escape(begin) + r"\n.*?^" + re.escape(end) + r"\n?", "", text)
text = re.sub(r"\n{3,}", "\n\n", text).lstrip("\n")   # no blank lines left behind
if action == "remove":
    text = text.rstrip("\n") + "\n" if text.strip() else ""      # no blank line left where the block was
if action == "add":
    block = f"{begin}\n{open(content).read().rstrip()}\n{end}\n"
    last_exit = list(re.finditer(r"(?m)^exit\s+0\s*$", text))
    if last_exit:
        i = last_exit[-1].start(); text = text[:i] + block + text[i:]
    else:
        text = text.rstrip("\n"); text = (text + "\n\n" if text else "") + block
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
open(path, "w").write(text)
PY
}
run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
have() { command -v "$1" >/dev/null 2>&1; }

if [ "$UNINSTALL" = 1 ]; then
  run rm -f "$BIN/osd" "$BIN/touchpad-tap"
  block remove "$XBINDKEYSRC"; block remove "$AUTOSTART"
  cmp -s "$DUNSTRC" "$HERE/dunstrc" 2>/dev/null && run rm -f "$DUNSTRC"
  [ "$RESTART" = 1 ] && [ "$DRY" = 0 ] && [ -n "${DISPLAY:-}" ] && { pkill -x xbindkeys || true; }
  echo "Removed. (Packages stay installed.)"; exit 0
fi

# --- dependencies ---------------------------------------------------------------------------------
if [ "$DEPS" = 1 ]; then
  missing=()
  for pair in xbindkeys:xbindkeys brightnessctl:brightnessctl dunst:dunst notify-send:libnotify-bin wpctl:wireplumber python3:python3; do
    have "${pair%%:*}" || missing+=("${pair##*:}")
  done
  [ "$TOUCHPAD" = 1 ] && ! have xinput && missing+=(xinput)
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Missing packages. Install them first:  sudo apt install ${missing[*]}"; [ "$DRY" = 1 ] || exit 1
  fi
fi
if [ ! -w "$(ls /sys/class/backlight/*/brightness 2>/dev/null | head -n 1)" ] 2>/dev/null; then
  echo "Note: you cannot write to the backlight yet. brightnessctl's udev rule lets the 'video' group do it:"
  echo "      sudo usermod -aG video \$USER   (then log out and in)"
fi

# --- install --------------------------------------------------------------------------------------
run install -D -m 755 "$HERE/osd" "$BIN/osd"
[ "$TOUCHPAD" = 1 ] && run install -D -m 755 "$HERE/touchpad-tap.sh" "$BIN/touchpad-tap"

tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
sed "s#\"osd #\"$BIN/osd #" "$HERE/xbindkeys-thinkpad.conf" > "$tmp"
block add "$XBINDKEYSRC" "$tmp"

if [ ! -f "$DUNSTRC" ]; then run install -D -m 644 "$HERE/dunstrc" "$DUNSTRC"
elif ! grep -q 'appname = "osd"' "$DUNSTRC"; then
  echo "Note: you already have a dunst config. Add the [osd] section from this module's dunstrc to it for the pop-up style."
fi

{ echo "# ThinkPad keys: start xbindkeys once the session has settled (an early start does not grab the keys reliably)"
  echo "( sleep 3; pkill -x xbindkeys; exec xbindkeys ) >/dev/null 2>&1 &"
  echo "pgrep -x dunst >/dev/null || dunst >/dev/null 2>&1 &"
  [ "$TOUCHPAD" = 1 ] && echo "( sleep 2; $BIN/touchpad-tap ) >/dev/null 2>&1 &"
  true; } > "$tmp"
[ -f "$AUTOSTART" ] || { [ "$DRY" = 1 ] || { mkdir -p "$(dirname "$AUTOSTART")"; printf '#!/bin/sh\nexit 0\n' > "$AUTOSTART"; chmod +x "$AUTOSTART"; }; }
block add "$AUTOSTART" "$tmp"

if [ "$RESTART" = 1 ] && [ "$DRY" = 0 ] && [ -n "${DISPLAY:-}" ]; then
  pkill -x xbindkeys 2>/dev/null || true; sleep 0.3; (setsid xbindkeys >/dev/null 2>&1 &)
  pgrep -x dunst >/dev/null || (setsid dunst >/dev/null 2>&1 &)
  [ "$TOUCHPAD" = 1 ] && "$BIN/touchpad-tap" || true
fi
echo "Installed. Bindings: $XBINDKEYSRC   Start-up lines: $AUTOSTART"
echo "If you do not use Window Maker's autostart, put the lines between the '$NAME' markers in your session start-up."

#!/usr/bin/env bash
# Normal Caps Lock on Window Maker. The Debian Window Maker live packages turn Caps Lock into the Compose key at
# every login (a startup script sets the XKB option "compose:caps"). This installs a small command that takes the
# option off again, runs it at every login, and switches Debian's startup script off. A marked block is added to the
# Window Maker autostart file; --uninstall removes it and switches Debian's script back on.
# Run ./install.sh --help for the options.
set -euo pipefail

NAME=wmodern-caps-lock
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX="${PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin"
WM_ROOT="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}"
AUTOSTART="$WM_ROOT/Library/WindowMaker/autostart"
DEBIAN_SCRIPT=01_compose_key                       # from the wmlive-base package, in AutoStart/Enabled
DRY=0 UNINSTALL=0 APPLY=1

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="${2:?--prefix needs a directory}"; BIN="$PREFIX/bin"; shift ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --no-apply) APPLY=0 ;;
    -h|--help)
      cat <<USAGE
Usage: ./install.sh [--prefix DIR] [--dry-run] [--no-apply] [--uninstall]
  --no-apply   do not change the running keyboard now (it is fixed at your next login)
USAGE
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

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
text = re.sub(r"\n{3,}", "\n\n", text)      # other installers leave blank lines behind; keep the file stable
if action == "remove":
    text = text.rstrip("\n") + "\n" if text.strip() else ""
else:
    blk = f"{begin}\n{open(content).read().rstrip()}\n{end}\n"
    last = list(re.finditer(r"(?m)^exit\s+0\s*$", text))
    if last:
        i = last[-1].start(); text = text[:i] + blk + text[i:]
    else:
        text = text.rstrip("\n"); text = (text + "\n\n" if text else "#!/bin/sh\n\n") + blk
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
open(path, "w").write(text)
PY
  [ -f "$2" ] && head -c 2 "$2" | grep -q '^#!' && chmod +x "$2" || true
}

ENABLED="$WM_ROOT/AutoStart/Enabled/$DEBIAN_SCRIPT" DISABLED="$WM_ROOT/AutoStart/Disabled/$DEBIAN_SCRIPT"

if [ "$UNINSTALL" = 1 ]; then
  block remove "$AUTOSTART"
  run rm -f -- "$BIN/normal-caps-lock"
  if [ -e "$DISABLED" ] && [ ! -e "$ENABLED" ]; then run mv -- "$DISABLED" "$ENABLED"; echo "Debian's $DEBIAN_SCRIPT startup script is switched on again."; fi
  echo "Removed. Caps Lock becomes the Compose key again at your next login."; exit 0
fi

run install -D -m 755 "$HERE/normal-caps-lock" "$BIN/normal-caps-lock"
# Debian's own startup script would set the option again at every login: switch it off the way Debian intends.
if [ -e "$ENABLED" ]; then
  run mkdir -p "$(dirname "$DISABLED")"; run mv -- "$ENABLED" "$DISABLED"
  echo "Switched off Debian's $DEBIAN_SCRIPT startup script (moved to AutoStart/Disabled)."
fi
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
printf '%s\n' "# Normal Caps Lock: take compose:caps off the keyboard options (the system sets it at login)" \
  '( sleep 2; "$HOME/.local/bin/normal-caps-lock" ) >/dev/null 2>&1 &' > "$tmp"
[ "$PREFIX" = "$HOME/.local" ] || sed -i "s|\"\$HOME/.local/bin/|\"$BIN/|" "$tmp"
block add "$AUTOSTART" "$tmp"
echo "Installed $BIN/normal-caps-lock and run it at every login (block in $AUTOSTART)."
if [ "$APPLY" = 1 ] && [ "$DRY" = 0 ] && [ -n "${DISPLAY:-}" ] && have setxkbmap; then
  "$BIN/normal-caps-lock" && echo "Caps Lock is normal in this session now."
else
  echo "Not applied to a running session: Caps Lock is normal from your next login (or run: normal-caps-lock)."
fi

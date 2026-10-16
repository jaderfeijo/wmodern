#!/usr/bin/env bash
# Installs `shade-all` (shade or unshade every window on the current desktop) and binds a key to it.
# Run ./install.sh --help for the options. A marked block is added to ~/.xbindkeysrc; --uninstall removes it again.
set -euo pipefail

NAME=wmodern-shade-all
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX="${PREFIX:-$HOME/.local}"
XBINDKEYSRC="$HOME/.xbindkeysrc"
KEY="Mod4 + Shift + h" DRY=0 UNINSTALL=0 RESTART=1 DEPS=1 INSTALL_DEPS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --key) KEY="${2:?--key needs an xbindkeys key, e.g. \"Mod4 + Shift + s\"}"; shift ;;
    --prefix) PREFIX="${2:?--prefix needs a directory}"; shift ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --no-restart) RESTART=0 ;;
    --install-deps) INSTALL_DEPS=1 ;;
    --skip-deps-check) DEPS=0 ;;
    -h|--help)
      cat <<USAGE
Usage: ./install.sh [--key "Mod4 + Shift + h"] [--prefix DIR] [--dry-run] [--uninstall] [--install-deps] [--no-restart]
  --key KEY   the key that toggles shading, in xbindkeys syntax (default: Super+Shift+H)
USAGE
      exit 0 ;;
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

if [ "$UNINSTALL" = 1 ]; then
  run rm -f -- "$BIN/shade-all"; block remove "$XBINDKEYSRC"
  echo "Removed. Log out and in (or restart xbindkeys) for the key to be released."; exit 0
fi

if [ "$DEPS" = 1 ]; then
  missing=(); have wmctrl || missing+=(wmctrl); have xprop || missing+=(x11-utils); have xbindkeys || missing+=(xbindkeys); have python3 || missing+=(python3)
  if [ "${#missing[@]}" -gt 0 ]; then
    if [ "$INSTALL_DEPS" = 1 ] && have apt-get; then run sudo apt-get install -y "${missing[@]}"
    else echo "Missing: ${missing[*]}. Install them with:  sudo apt install ${missing[*]}   (or use --install-deps)"; [ "$DRY" = 1 ] || exit 1; fi
  fi
fi

run install -D -m 755 "$HERE/shade-all" "$BIN/shade-all"
# A key can only have one binding: say so if another one is already there.
if [ -f "$XBINDKEYSRC" ]; then
  outside=$(awk -v b="# >>> $NAME >>>" -v e="# <<< $NAME <<<" '$0==b{s=1} !s{print} $0==e{s=0}' "$XBINDKEYSRC")
  grep -qxF "    $KEY" <<<"$outside" && echo "Warning: $KEY is already bound elsewhere in $XBINDKEYSRC (the first binding wins). Pick another with --key."
fi
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
printf '%s\n' "# Shade / unshade every window on this desktop (toggle)" "\"$BIN/shade-all\"" "    $KEY" > "$tmp"
block add "$XBINDKEYSRC" "$tmp"
echo "Installed $BIN/shade-all and bound it to: $KEY  (in $XBINDKEYSRC)"
if [ "$RESTART" = 1 ] && [ "$DRY" = 0 ] && [ -n "${DISPLAY:-}" ] && have xbindkeys; then
  pkill -x xbindkeys 2>/dev/null || true; sleep 0.3; (setsid xbindkeys >/dev/null 2>&1 &); echo "xbindkeys restarted."
fi
echo "It works with any window manager that supports the EWMH 'shaded' state, such as Window Maker. Autostart xbindkeys if it is not already."

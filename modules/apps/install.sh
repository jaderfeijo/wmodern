#!/usr/bin/env bash
# Installs the `wmapps` command into ~/.local/bin (or --prefix DIR/bin) and, unless --no-session, the ~/.xsessionrc block
# that gives every login the complete list of application directories. --uninstall removes both again.
set -euo pipefail
PREFIX="$HOME/.local" DRY=0 UNINSTALL=0 DEPS=0 SESSION=1
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="${2:?--prefix needs a directory}"; shift ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --install-deps) DEPS=1 ;;
    --no-session) SESSION=0 ;;
    -h|--help) echo "Usage: ./install.sh [--prefix DIR] [--no-session] [--install-deps] [--dry-run] [--uninstall]"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
dest="$PREFIX/bin/wmapps"
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ "$UNINSTALL" = 1 ]; then
  [ -x "$dest" ] && { if [ "$DRY" = 1 ]; then echo "[dry-run] wmapps unfix"; else "$dest" unfix >/dev/null; fi; }
  run rm -f -- "$dest"; echo "Removed $dest and its ~/.xsessionrc block."; exit 0
fi
run install -D -m 755 "$here/wmapps" "$dest"
[ "$DRY" = 1 ] || echo "Installed $dest"
if [ "$SESSION" = 1 ]; then
  if [ "$DRY" = 1 ]; then echo "[dry-run] wmapps fix"; else "$dest" fix >/dev/null; echo "Session block written to ~/.xsessionrc (used from the next login)."; fi
fi
missing=()
command -v python3 >/dev/null || missing+=(python3); command -v rofi >/dev/null || missing+=(rofi)
if [ "${#missing[@]}" -gt 0 ]; then
  if [ "$DEPS" = 1 ] && command -v apt-get >/dev/null; then run sudo apt-get install -y "${missing[@]}"
  else echo "Still needed: ${missing[*]}   (sudo apt install ${missing[*]}, or rerun with --install-deps)"; fi
fi
case ":$PATH:" in *":$PREFIX/bin:"*) ;; *) echo "Note: $PREFIX/bin is not on your PATH." ;; esac
echo "Try:  wmapps doctor"

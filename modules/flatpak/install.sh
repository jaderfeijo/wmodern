#!/usr/bin/env bash
# Installs the `flatpak-wm` command into ~/.local/bin (or --prefix DIR/bin). --uninstall removes it again.
set -euo pipefail
PREFIX="$HOME/.local" DRY=0 UNINSTALL=0 DEPS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="${2:?--prefix needs a directory}"; shift ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --install-deps) DEPS=1 ;;
    -h|--help) echo "Usage: ./install.sh [--prefix DIR] [--install-deps] [--dry-run] [--uninstall]"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
dest="$PREFIX/bin/flatpak-wm"
if [ "$UNINSTALL" = 1 ]; then run rm -f -- "$dest"; echo "Removed $dest (the ~/.xsessionrc block, if you added one with 'flatpak-wm fix', is left; delete the marked block by hand)."; exit 0; fi
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
run install -D -m 755 "$here/flatpak-wm" "$dest"
[ "$DRY" = 1 ] || echo "Installed $dest"
missing=()
command -v flatpak >/dev/null || missing+=(flatpak); command -v xdg-mime >/dev/null || missing+=(xdg-utils); command -v python3 >/dev/null || missing+=(python3)
if [ "${#missing[@]}" -gt 0 ]; then
  if [ "$DEPS" = 1 ] && command -v apt-get >/dev/null; then run sudo apt-get install -y "${missing[@]}"
  else echo "Still needed: ${missing[*]}   (sudo apt install ${missing[*]}, or rerun with --install-deps)"; fi
fi
case ":$PATH:" in *":$PREFIX/bin:"*) ;; *) echo "Note: $PREFIX/bin is not on your PATH." ;; esac
echo "Try:  flatpak-wm check"

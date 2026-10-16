#!/usr/bin/env bash
# Installs the `webapp` command into ~/.local/bin (or --prefix DIR/bin). --uninstall removes it again.
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
dest="$PREFIX/bin/webapp"
if [ "$UNINSTALL" = 1 ]; then run rm -f -- "$dest"; echo "Removed $dest (launcher entries you made are kept; remove them with 'webapp remove' first)."; exit 0; fi
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
run install -D -m 755 "$here/webapp" "$dest"
[ "$DRY" = 1 ] || echo "Installed $dest"
missing=()
command -v curl >/dev/null || missing+=(curl); command -v file >/dev/null || missing+=(file)
for b in chromium chromium-browser google-chrome google-chrome-stable brave-browser microsoft-edge; do command -v "$b" >/dev/null && { found=1; break; }; done
[ -n "${found:-}" ] || missing+=(chromium)
if [ "${#missing[@]}" -gt 0 ]; then
  if [ "$DEPS" = 1 ] && command -v apt-get >/dev/null; then run sudo apt-get install -y "${missing[@]}"
  else echo "Still needed: ${missing[*]}   (sudo apt install ${missing[*]}, or rerun with --install-deps)"; fi
fi
case ":$PATH:" in *":$PREFIX/bin:"*) ;; *) echo "Note: $PREFIX/bin is not on your PATH." ;; esac
echo "Try:  webapp add \"Hacker News\" news.ycombinator.com"

#!/usr/bin/env bash
# Installs the Omarchy ports: web-app and TUI launcher scripts, a searchable web-app catalog, and fzf software pickers,
# adapted to run on Window Maker (rofi + xterm instead of Hyprland + walker + alacritty). Run ./install.sh --help.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX="${PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DATA="$DATA_HOME/omarchy-port"
APPS="$DATA_HOME/applications"
DRY=0 UNINSTALL=0 DEPS=1 INSTALL_DEPS=0 LAUNCHERS=1

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="${2:?--prefix needs a directory}"; BIN="$PREFIX/bin"; shift ;;
    --no-launchers) LAUNCHERS=0 ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --install-deps) INSTALL_DEPS=1 ;;
    --skip-deps-check) DEPS=0 ;;
    -h|--help)
      cat <<USAGE
Usage: ./install.sh [--prefix DIR] [--no-launchers] [--dry-run] [--uninstall] [--install-deps]
  installs the scripts into DIR/bin, the catalog data into ~/.local/share/omarchy-port, and launcher entries
  (Web Apps, Install/Remove Software, Install/Remove Flatpak App) into ~/.local/share/applications
  --no-launchers   do not create the launcher entries
USAGE
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

have() { command -v "$1" >/dev/null 2>&1; }
run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
mine() { cmp -s "$1" "$2" 2>/dev/null; }                      # is the installed file still the one we shipped?
launcher_names=("Web Apps" software-install software-remove software-flatpak software-flatpak-remove)

if [ "$UNINSTALL" = 1 ]; then
  for f in "$HERE"/bin/*; do n=$(basename "$f"); mine "$f" "$BIN/$n" && run rm -f -- "$BIN/$n" || { [ -e "$BIN/$n" ] && echo "kept $BIN/$n (changed or not ours)"; } || true; done
  for n in "${launcher_names[@]}"; do run rm -f -- "$APPS/$n.desktop"; done
  run rm -rf -- "$DATA"
  have update-desktop-database && [ "$DRY" = 0 ] && update-desktop-database "$APPS" >/dev/null 2>&1 || true
  echo "Removed. Web apps you created with it are kept (remove them with omarchy-webapp-remove first)."; exit 0
fi

if [ "$DEPS" = 1 ]; then
  missing=(); for p in gum jq fzf rofi curl file xterm chromium; do have "$p" || missing+=("$p"); done
  if [ "${#missing[@]}" -gt 0 ]; then
    if [ "$INSTALL_DEPS" = 1 ] && have apt-get; then run sudo apt-get install -y "${missing[@]}"
    else echo "Missing: ${missing[*]}. Install them with:  sudo apt install ${missing[*]}   (or use --install-deps)"; [ "$DRY" = 1 ] || exit 1; fi
  fi
fi

for f in "$HERE"/bin/*; do
  n=$(basename "$f")
  # do not shadow a real xdg-terminal-exec that is not ours
  if [ "$n" = xdg-terminal-exec ] && have xdg-terminal-exec && ! mine "$f" "$(command -v xdg-terminal-exec)"; then
    echo "Keeping the xdg-terminal-exec that is already installed ($(command -v xdg-terminal-exec))."; continue
  fi
  run install -D -m 755 "$f" "$BIN/$n"
done
run mkdir -p "$DATA"
run install -m 644 "$HERE/data/en-cli.json" "$HERE/data/webapps.tsv" "$HERE/LICENSE-omarchy" "$DATA/"
if [ "$LAUNCHERS" = 1 ]; then
  run mkdir -p "$APPS"
  for n in "${launcher_names[@]}"; do
    if [ "$DRY" = 1 ]; then echo "[dry-run] write $APPS/$n.desktop"; else sed "s#@BIN@#$BIN#g" "$HERE/applications/$n.desktop" > "$APPS/$n.desktop"; fi
  done
  have update-desktop-database && [ "$DRY" = 0 ] && update-desktop-database "$APPS" >/dev/null 2>&1 || true
fi
echo "Installed into $BIN. Launcher entries: Web Apps, Install/Remove Software, Install/Remove Flatpak App."
case ":$PATH:" in *":$BIN:"*) ;; *) echo "Note: $BIN is not on your PATH." ;; esac

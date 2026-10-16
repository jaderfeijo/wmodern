#!/usr/bin/env bash
# Installs the power-button menu. Run ./install.sh --help for the options.
# Two parts: the menu and its helper run in YOUR session (no root), and a few small files go to /etc (via sudo).
set -euo pipefail

NAME=power-button-menu
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX="${PREFIX:-$HOME/.local}"
AUTOSTART="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}/Library/WindowMaker/autostart"
ROOT=""                                   # test hook: install the system files under this directory instead of /
DRY=0 UNINSTALL=0 SYSTEM=1 RESTART=1 DEPS=1 INSTALL_DEPS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) UNINSTALL=1 ;;
    --dry-run) DRY=1 ;;
    --no-system) SYSTEM=0 ;;
    --no-restart) RESTART=0 ;;
    --install-deps) INSTALL_DEPS=1 ;;
    --skip-deps-check) DEPS=0 ;;
    --prefix) PREFIX="${2:?--prefix needs a directory}"; shift ;;
    --autostart-file) AUTOSTART="${2:?--autostart-file needs a path}"; shift ;;
    --root) ROOT="${2:?--root needs a directory}"; shift ;;
    -h|--help)
      cat <<USAGE
Usage: ./install.sh [--dry-run] [--uninstall] [--install-deps] [--no-system] [--no-restart] [--prefix DIR] [--autostart-file FILE]
  user part:   power-menu and power-menu-listener into DIR/bin, and a start-up block in Window Maker's autostart file
  system part: /etc/acpi/events/power-menu, /etc/acpi/power-menu.sh and /etc/systemd/logind.conf.d/power-key.conf
               (uses sudo), then restarts acpid and tells systemd-logind to re-read its config
  --no-system  do only the user part (for example when someone else manages /etc)
USAGE
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
BIN="$PREFIX/bin"
SUDO=""; [ -z "$ROOT" ] && [ "$(id -u)" != 0 ] && SUDO="sudo"
FILES=("acpi-power-menu.conf:/etc/acpi/events/power-menu:644" "acpi-power-menu.sh:/etc/acpi/power-menu.sh:755" "logind-power-key.conf:/etc/systemd/logind.conf.d/power-key.conf:644")

have() { command -v "$1" >/dev/null 2>&1; }
run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
block() {  # block add|remove FILE [CONTENT_FILE]   ("add" puts the block before a final "exit 0" if there is one)
  [ "$DRY" = 1 ] && { echo "[dry-run] block $1 in $2"; return 0; }
  python3 - "$1" "$2" "${3:-}" "$NAME" <<'PY'
import os, re, sys
action, path, content, name = sys.argv[1:5]
begin, end = f"# >>> {name} >>>", f"# <<< {name} <<<"
text = open(path).read() if os.path.exists(path) else None
if text is None and action == "remove":
    sys.exit(0)
text = re.sub(r"(?ms)^" + re.escape(begin) + r"\n.*?^" + re.escape(end) + r"\n?", "", text or "")
text = re.sub(r"\n{3,}", "\n\n", text).lstrip("\n")   # no blank lines left behind
if action == "remove":
    text = text.rstrip("\n") + "\n" if text.strip() else ""
else:
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

if [ "$UNINSTALL" = 1 ]; then
  [ -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/power-menu-listener.pid" ] && [ "$DRY" = 0 ] && [ "$RESTART" = 1 ] && \
    kill "$(cat "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/power-menu-listener.pid")" 2>/dev/null || true
  run rm -f "$BIN/power-menu" "$BIN/power-menu-listener"
  block remove "$AUTOSTART"
  if [ "$SYSTEM" = 1 ]; then
    for e in "${FILES[@]}"; do IFS=: read -r _ dest _ <<<"$e"; run $SUDO rm -f "$ROOT$dest"; done
    if [ -z "$ROOT" ] && [ "$DRY" = 0 ]; then $SUDO systemctl restart acpid 2>/dev/null || true; $SUDO systemctl kill -s HUP systemd-logind 2>/dev/null || true; fi
  fi
  echo "Removed. The power button is back to systemd's default (it powers off)."; exit 0
fi

# --- dependencies ---------------------------------------------------------------------------------
if [ "$DEPS" = 1 ]; then
  missing=()
  have rofi || missing+=(rofi)
  have python3 || missing+=(python3)
  if [ "$SYSTEM" = 1 ] && [ -z "$ROOT" ]; then have acpid || [ -x /usr/sbin/acpid ] || missing+=(acpid); fi
  if [ "${#missing[@]}" -gt 0 ]; then
    if [ "$INSTALL_DEPS" = 1 ] && have apt-get; then run $SUDO apt-get install -y "${missing[@]}"
    else echo "Missing: ${missing[*]}. Install them with:  sudo apt install ${missing[*]}   (or use --install-deps)"; [ "$DRY" = 1 ] || exit 1; fi
  fi
fi

# --- user part ------------------------------------------------------------------------------------
run install -D -m 755 "$HERE/power-menu" "$BIN/power-menu"
run install -D -m 755 "$HERE/power-menu-listener" "$BIN/power-menu-listener"
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
printf '%s\n' "# Power button menu: the helper that opens it when acpid says the button was pressed" "$BIN/power-menu-listener >/dev/null 2>&1 &" > "$tmp"
if [ ! -f "$AUTOSTART" ] && [ "$DRY" = 0 ]; then mkdir -p "$(dirname "$AUTOSTART")"; printf '#!/bin/sh\nexit 0\n' > "$AUTOSTART"; chmod +x "$AUTOSTART"; fi
block add "$AUTOSTART" "$tmp"
echo "User part installed: $BIN/power-menu, $BIN/power-menu-listener; start-up block in $AUTOSTART"
if [ "$RESTART" = 1 ] && [ "$DRY" = 0 ] && [ -n "${DISPLAY:-}" ]; then (setsid "$BIN/power-menu-listener" >/dev/null 2>&1 &); echo "  helper started"; fi

# --- system part ----------------------------------------------------------------------------------
if [ "$SYSTEM" = 1 ]; then
  for e in "${FILES[@]}"; do
    IFS=: read -r src dest mode <<<"$e"
    run $SUDO install -D -m "$mode" "$HERE/$src" "$ROOT$dest"
  done
  if [ -z "$ROOT" ] && [ "$DRY" = 0 ]; then
    $SUDO systemctl restart acpid
    $SUDO systemctl kill -s HUP systemd-logind
  fi
  echo "System part installed: /etc/acpi/events/power-menu, /etc/acpi/power-menu.sh, /etc/systemd/logind.conf.d/power-key.conf"
fi
echo
echo "Press the power button once, briefly: the menu should open (press it again to close it)."
echo "If your keyboard also has an xbindkeys/xbindkeys-like binding for XF86PowerOff, remove it (see README)."

#!/usr/bin/env bash
# Switch off the welcome window that Debian's Window Maker live packages (wmlive-base) show at login. Debian's own
# mechanism is used: the startup script is moved from AutoStart/Enabled to AutoStart/Disabled; --uninstall moves it back.
# Run ./install.sh --help for the options. Nothing is deleted.
set -euo pipefail

SCRIPT=99_welcome_message
WM_ROOT="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}"
ENABLED="$WM_ROOT/AutoStart/Enabled/$SCRIPT" DISABLED="$WM_ROOT/AutoStart/Disabled/$SCRIPT"
DRY=0 UNINSTALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help) echo "Usage: ./install.sh [--dry-run] [--uninstall]"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

if [ "$UNINSTALL" = 1 ]; then
  if [ -e "$DISABLED" ] && [ ! -e "$ENABLED" ]; then run mv -- "$DISABLED" "$ENABLED"; echo "The welcome window is switched on again (from your next login)."
  else echo "Nothing to restore."; fi
  exit 0
fi
if [ -e "$ENABLED" ]; then
  run mkdir -p "$(dirname "$DISABLED")"; run mv -- "$ENABLED" "$DISABLED"
  echo "Welcome window switched off (moved $SCRIPT to AutoStart/Disabled)."
else
  echo "The welcome window is already off."
fi

#!/usr/bin/env bash
# Window Maker: choose which key hides the application (HideKey), so Super+H can shade only the focused window.
# super-keys binds Super+H to ShadeKey; Window Maker then also had HideKey on Super+H and hid the whole application.
#
#   ./install.sh                  HideKey = Alt+H (Window Maker's own default)
#   ./install.sh --key Mod1+H     any Window Maker shortcut, e.g. Mod4+Shift+H or Control+Mod1+H
#   ./install.sh --none           no key hides the application at all
#   ./install.sh --uninstall      back to Window Maker's default (Alt+H)
#   ./install.sh --dry-run        show what would change
#
# Mod1 is Alt, Mod4 is Super. It edits ~/GNUstep/Defaults/WindowMaker (a backup is kept next to it, once) and tells a
# running Window Maker to re-read it.
set -euo pipefail

FILE="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}/Defaults/WindowMaker"
VALUE=Mod1+H DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --key) [ $# -ge 2 ] || { echo "--key needs a shortcut" >&2; exit 2; }; VALUE=$2; shift ;;
    --none) VALUE=None ;;
    --uninstall) VALUE=Mod1+H ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
case "$VALUE" in *[!A-Za-z0-9+_]*|'') echo "not a Window Maker shortcut: $VALUE" >&2; exit 2 ;; esac

python3 - "$FILE" "$VALUE" "$DRY" <<'PY'
import os, re, shutil, sys
path, value, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
key = "HideKey"
text = open(path).read() if os.path.exists(path) else "{\n}\n"
new = value if value == "None" else f'"{value}"'
pattern = re.compile(r"(?m)^([ \t]*)" + key + r"[ \t]*=[ \t]*[^;\n]*;[ \t]*$")
match = pattern.search(text)
if match:
    old = re.search(r"=\s*([^;]*);", match.group(0)).group(1).strip()
    text = text[:match.start()] + f"{match.group(1)}{key} = {new};" + text[match.end():]
else:
    old = "(not set)"
    close = text.rstrip().rfind("}")
    text = text[:close] + f"  {key} = {new};\n" + text[close:]
print(("[dry-run] " if dry else "") + f"{path}\n  {key}: {old} -> {new}")
if not dry:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    backup = path + ".bak-hide-key"
    if os.path.exists(path) and not os.path.exists(backup):
        shutil.copy2(path, backup)
    open(path, "w").write(text)
PY

[ "$DRY" = 1 ] && exit 0
# SIGUSR2 makes the running Window Maker re-read its defaults. Only the real one gets it: Debian's wrapper process
# has the same name, and the signal would terminate it (and the session with it).
if [ -n "${DISPLAY:-}" ] && pgrep -f -- 'wmaker --for-real' >/dev/null 2>&1; then
  pkill -USR2 -f -- 'wmaker --for-real' 2>/dev/null || true; echo "Reloaded in the running Window Maker."
else echo "Used when Window Maker next starts."; fi

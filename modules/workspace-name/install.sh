#!/usr/bin/env bash
# Window Maker: flash the workspace name in the centre of the screen when you switch workspaces
# (WorkspaceNameDisplayPosition = center).
#
#   ./install.sh               flash the workspace name at the centre of the screen
#   ./install.sh --uninstall   stop showing the name (Debian's default, none)
#   ./install.sh --dry-run     show what would change
#
# It edits ~/GNUstep/Defaults/WindowMaker (a backup is kept next to it, once). Window Maker only reads that file
# when it starts, so afterwards use: root menu > Window Maker > Restart (or log out and in).
set -euo pipefail

FILE="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}/Defaults/WindowMaker"
VALUE=center DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) VALUE=none ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

python3 - "$FILE" "$VALUE" "$DRY" <<'PY'
import os, re, shutil, sys
path, value, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
key = "WorkspaceNameDisplayPosition"
text = open(path).read() if os.path.exists(path) else "{\n}\n"
pattern = re.compile(r"(?m)^([ \t]*)" + key + r"[ \t]*=[ \t]*[^;\n]*;[ \t]*$")
match = pattern.search(text)
if match:
    old = re.search(r"=\s*([^;]*);", match.group(0)).group(1).strip()
    text = text[:match.start()] + f"{match.group(1)}{key} = {value};" + text[match.end():]
else:
    old = "(not set)"
    close = text.rstrip().rfind("}")
    text = text[:close] + f"  {key} = {value};\n" + text[close:]
print(("[dry-run] " if dry else "") + f"{path}\n  {key}: {old} -> {value}")
if not dry:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    backup = path + ".bak-workspace-name"
    if os.path.exists(path) and not os.path.exists(backup):
        shutil.copy2(path, backup)
    open(path, "w").write(text)
    print("Done. Now: root menu > Window Maker > Restart (Window Maker reads this file at startup).")
PY

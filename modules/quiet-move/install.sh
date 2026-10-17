#!/usr/bin/env bash
# Window Maker: no position tooltip while you move a window (MoveDisplay = none).
#
#   ./install.sh               hide the position box while moving windows
#   ./install.sh --uninstall   back to Window Maker's default (the box in the top-left corner)
#   ./install.sh --dry-run     show what would change
#
# It edits ~/GNUstep/Defaults/WindowMaker (a backup is kept next to it, once). Window Maker only reads that file
# when it starts, so afterwards use: root menu > Window Maker > Restart (or log out and in).
set -euo pipefail

FILE="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}/Defaults/WindowMaker"
VALUE=none DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) VALUE=corner ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

python3 - "$FILE" "$VALUE" "$DRY" <<'PY'
import os, re, shutil, sys
path, value, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
key = "MoveDisplay"
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
    backup = path + ".bak-quiet-move"
    if os.path.exists(path) and not os.path.exists(backup):
        shutil.copy2(path, backup)
    open(path, "w").write(text)
    print("Done. Now: root menu > Window Maker > Restart (Window Maker reads this file at startup).")
PY

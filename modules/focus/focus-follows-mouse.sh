#!/usr/bin/env bash
# Window Maker: focus follows the mouse, and the window under the pointer is raised automatically.
#
#   ./focus-follows-mouse.sh                 sloppy focus + auto-raise after 1 ms (practically instant)
#   ./focus-follows-mouse.sh --delay 250     ... raise after 250 ms of the pointer resting on the window
#   ./focus-follows-mouse.sh --click-to-focus   back to Window Maker's default (click to focus, no auto-raise)
#   ./focus-follows-mouse.sh --dry-run       show what would change
#
# It edits ~/GNUstep/Defaults/WindowMaker (a backup is kept next to it, once). Window Maker only reads that file
# when it starts, so afterwards use: root menu > Window Maker > Restart.
set -euo pipefail

FILE="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}/Defaults/WindowMaker"
MODE=sloppy DELAY=1 DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --delay) DELAY="${2:?--delay needs milliseconds}"; shift ;;
    --click-to-focus) MODE=manual; DELAY=0 ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
case "$DELAY" in ''|*[!0-9]*) echo "--delay must be a whole number of milliseconds" >&2; exit 2 ;; esac

python3 - "$FILE" "$MODE" "$DELAY" "$DRY" <<'PY'
import os, re, shutil, sys
path, mode, delay, dry = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
text = open(path).read() if os.path.exists(path) else "{\n}\n"
changes = []
for key, value in (("FocusMode", mode), ("RaiseDelay", delay)):
    pattern = re.compile(r"(?m)^([ \t]*)" + key + r"[ \t]*=[ \t]*[^;\n]*;[ \t]*$")
    match = pattern.search(text)
    if match:
        old = re.search(r"=\s*([^;]*);", match.group(0)).group(1).strip()
        text = text[:match.start()] + f"{match.group(1)}{key} = {value};" + text[match.end():]
    else:
        old = "(not set)"
        close = text.rstrip().rfind("}")
        text = text[:close] + f"  {key} = {value};\n" + text[close:]
    changes.append(f"  {key}: {old} -> {value}")
print(("[dry-run] " if dry else "") + f"{path}\n" + "\n".join(changes))
if not dry:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    backup = path + ".bak-focus-follows-mouse"
    if os.path.exists(path) and not os.path.exists(backup):
        shutil.copy2(path, backup)
    open(path, "w").write(text)
    print("Done. Now: root menu > Window Maker > Restart (Window Maker reads this file at startup).")
PY

#!/usr/bin/env bash
# Chromium: scale the whole browser (its own UI and every web page) with --force-device-scale-factor.
#
#   ./install.sh                  80%, that is 20% smaller than stock
#   ./install.sh --percent 90     any value from 25 to 300 (100 = stock size)
#   ./install.sh --uninstall      back to stock (removes the launcher override)
#   ./install.sh --dry-run        show what would change
#
# It writes a copy of Chromium's launcher to ~/.local/share/applications/chromium.desktop with the flag added to the
# Exec line, so it applies when Chromium is started from a menu, launcher or Super+Space. A Chromium that is already
# running keeps its old size: quit it completely first. Starting `chromium` from a terminal does not go through the
# launcher; add the flag there yourself.
set -euo pipefail

SYSTEM=/usr/share/applications/chromium.desktop
FILE="${XDG_DATA_HOME:-$HOME/.local/share}/applications/chromium.desktop"
PERCENT=80 DRY=0 UNINSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --percent) PERCENT=${2:?--percent needs a number}; shift ;;
    --uninstall) UNINSTALL=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
case "$PERCENT" in ''|*[!0-9]*) echo "--percent must be a whole number" >&2; exit 2 ;; esac
{ [ "$PERCENT" -ge 25 ] && [ "$PERCENT" -le 300 ]; } || { echo "--percent must be between 25 and 300" >&2; exit 2; }
[ "$PERCENT" = 100 ] && UNINSTALL=1

python3 - "$SYSTEM" "$FILE" "$PERCENT" "$UNINSTALL" "$DRY" <<'PY'
import os, re, sys
system, path, percent, uninstall, dry = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4] == "1", sys.argv[5] == "1"
tag = "[dry-run] " if dry else ""
flag = re.compile(r" --force-device-scale-factor=\S+")
if uninstall:
    if not os.path.exists(path):
        print(tag + "nothing to remove (" + path + ")")
    else:
        print(tag + "remove " + path + " (Chromium is back to its stock size)")
        if not dry:
            os.remove(path)
    sys.exit(0)
src = path if os.path.exists(path) else system        # keep any other edit made to an existing override
if not os.path.exists(src):
    sys.exit("chromium.desktop not found (is Chromium installed?)")
text = open(src).read()
scale = "%g" % (percent / 100)
new, n = re.subn(r"(?m)^(Exec=\S*chromium\S*)(?:" + flag.pattern + r")?", lambda m: m.group(1) + " --force-device-scale-factor=" + scale, text)
if not n:
    sys.exit("no Exec= line for chromium in " + src)
print(tag + path + "\n  Exec: --force-device-scale-factor=" + scale + " (" + str(percent) + "%)")
if not dry:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(new)
    print("Done. Quit Chromium completely and start it again.")
PY

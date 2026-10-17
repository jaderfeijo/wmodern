#!/usr/bin/env bash
# Builds upstream Window Maker with RandR support into ~/.local/opt/wmaker and installs a `wmaker` wrapper in
# ~/.local/bin, so the next login uses it. Debian's own package is left alone and remains the fallback.
# Run ./install.sh --help for the options.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX="${WMODERN_WMAKER_PREFIX:-$HOME/.local/opt/wmaker}"
BIN="${WMC_BIN_DIR:-$HOME/.local/bin}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wmodern/wmaker-src"
URL=https://github.com/window-maker/wmaker.git
REF=535288cec55e99371f0996da9a12c1744a8a0f62       # a tested upstream commit; --ref master follows upstream
XSESSIONRC="$HOME/.xsessionrc"
DEFAULTS="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}/Defaults/WindowMaker"
STAMP_SUFFIX="+desk-names"                        # the build is the commit plus our patch (see below)
DRY=0 UNINSTALL=0 JOBS=$(nproc 2>/dev/null || echo 2)

while [ $# -gt 0 ]; do
  case "$1" in
    --ref) REF="${2:?--ref needs a commit, tag or branch}"; shift ;;
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --skip-deps-check|--no-restart) ;;
    -h|--help) echo "Usage: ./install.sh [--ref COMMIT|BRANCH] [--dry-run] [--uninstall]"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
have() { command -v "$1" >/dev/null 2>&1; }

# A marked block in ~/.xsessionrc, which the login manager runs before the session starts: the login PATH does not
# contain ~/.local/bin, so without this the session would start Debian's /usr/bin/wmaker and not the wrapper.
xsession_block() {  # add|remove
  python3 - "$1" "$XSESSIONRC" <<'PY'
import os, re, sys
action, path = sys.argv[1:3]
begin, end = "# >>> wmodern:wmaker-randr >>>", "# <<< wmodern:wmaker-randr <<<"
text = open(path).read() if os.path.exists(path) else ""
text = re.sub(r"(?ms)^" + re.escape(begin) + r"\n.*?^" + re.escape(end) + r"\n?", "", text)
text = re.sub(r"\n{3,}", "\n\n", text).lstrip("\n")   # a block removed from the top must not leave blank lines
if action == "add":
    text = text.rstrip("\n") + ("\n\n" if text.strip() else "") + begin + "\n" + \
        "# Start the RandR-aware Window Maker from ~/.local/bin instead of Debian's\n" + \
        'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH"; export PATH ;; esac\n' + end + "\n"
elif not text.strip():
    sys.exit(0)
open(path, "w").write(text)
PY
}

if [ "$UNINSTALL" = 1 ]; then
  run rm -f -- "$BIN/wmaker"; run rm -rf -- "$PREFIX"; [ "$DRY" = 1 ] || xsession_block remove
  echo "Removed. The next login uses Debian's Window Maker again."; exit 0
fi

missing=()
for t in git gcc make autoconf automake libtoolize pkg-config; do have "$t" || missing+=("$t"); done
for m in x11 xrandr xext xmu xpm xft xrender fontconfig libpng libtiff-4 libwebp; do pkg-config --exists "$m" 2>/dev/null || missing+=("pkg-config:$m"); done
[ -e /usr/include/jpeglib.h ] || missing+=(libjpeg-dev); [ -e /usr/include/gif_lib.h ] || missing+=(libgif-dev)
if [ "${#missing[@]}" -gt 0 ] && [ "$DRY" = 0 ]; then
  echo "Missing: ${missing[*]}"
  echo "Install the build dependencies with:"
  echo "  sudo apt install build-essential autoconf automake libtool pkg-config libxrandr-dev libxft-dev libxpm-dev libxmu-dev libxext-dev libxrender-dev libfontconfig-dev libpng-dev libjpeg-dev libtiff-dev libgif-dev libwebp-dev libmagic-dev libbsd-dev"
  exit 1
fi

if [ "$DRY" = 1 ]; then
  echo "[dry-run] build upstream Window Maker ($REF) with RandR into $PREFIX and install $BIN/wmaker"
  echo "[dry-run] add a PATH line to $XSESSIONRC"
  echo "[dry-run] set KeepDockOnPrimaryHead = YES in $DEFAULTS"; exit 0
fi

if [ -x "$PREFIX/bin/wmaker" ] && [ "$(cat "$PREFIX/.wmodern-rev" 2>/dev/null)" = "$REF$STAMP_SUFFIX" ]; then
  echo "Window Maker $REF is already built; skipping the build."
  install -D -m 755 "$HERE/wmaker" "$BIN/wmaker"; xsession_block add
  echo "Installed $BIN/wmaker and the PATH line in $XSESSIONRC."; exit 0
fi
mkdir -p "$CACHE"
[ -d "$CACHE/.git" ] || git clone -q "$URL" "$CACHE"
git -C "$CACHE" fetch -q origin "$REF" 2>/dev/null || git -C "$CACHE" fetch -q origin
git -C "$CACHE" checkout -q --force "$REF" 2>/dev/null || git -C "$CACHE" checkout -q --force "origin/$REF"
cd "$CACHE"
git clean -qfdx
# New workspaces are called "Desk 2", "Desk 3", ... instead of "Workspace 2" (the name is only a format string)
sed -i 's/_("Workspace %i")/_("Desk %i")/' src/workspace.c
grep -q '_("Desk %i")' src/workspace.c
./autogen.sh >/dev/null 2>&1
./configure --prefix="$PREFIX" --sysconfdir="$PREFIX/etc" --enable-randr >/dev/null
make -j"$JOBS" >/dev/null
make install >/dev/null
"$PREFIX/bin/wmaker" --version >/dev/null
echo "$REF$STAMP_SUFFIX" > "$PREFIX/.wmodern-rev"
install -D -m 755 "$HERE/wmaker" "$BIN/wmaker"
xsession_block add

# With the new build, a Dock that is off the primary display is moved there when the layout changes.
if [ -f "$DEFAULTS" ]; then
  [ -e "$DEFAULTS.bak-wmaker-randr" ] || cp -p "$DEFAULTS" "$DEFAULTS.bak-wmaker-randr"
  if grep -q '^[[:space:]]*KeepDockOnPrimaryHead' "$DEFAULTS"; then
    sed -i 's/^\([[:space:]]*KeepDockOnPrimaryHead[[:space:]]*=[[:space:]]*\)[^;]*;/\1YES;/' "$DEFAULTS"
  else
    sed -i '$ i\  KeepDockOnPrimaryHead = YES;' "$DEFAULTS"
  fi
fi
echo "Installed Window Maker with RandR in $PREFIX and $BIN/wmaker."
echo "It is used from the next login (or Restart: root menu > Window Maker > Restart does not switch binaries, so log out and in)."

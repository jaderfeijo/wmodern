#!/usr/bin/env bash
# wmodern -- pick and install Window Maker customisations, and keep them up to date.
#
#   curl -fsSL https://raw.githubusercontent.com/jaderfeijo/wmodern/main/install.sh | bash
#
# It shows a list (arrow keys to move, space to select, Enter to install). Everything it installs lives in your home
# directory except the packages it asks sudo to apt-install. It is safe to run again: already-installed items are
# re-applied without duplicating anything, and items with a newer version are marked "update available".
# It never restarts or signals Window Maker, X or anything else in your running session: log out and in afterwards.
#
# Later:  wmodern            the list again        wmodern update    update everything installed
#         wmodern list       what is installed     wmodern remove ID uninstall one item
set -euo pipefail

VERSION=1
HOME_URL="https://github.com/jaderfeijo/wmodern.git"
SELF_NAME=wmodern
OLD_NAME=wmaker-customise                              # the name of an earlier version of this installer

BIN="${WMC_BIN_DIR:-$HOME/.local/bin}"
STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$SELF_NAME"
OLD_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/wmaker-customise"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$SELF_NAME"
STATE="$STATE_DIR/installed.tsv"                       # id <TAB> revision <TAB> date
AUTOSTART="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}/Library/WindowMaker/autostart"
XSESSIONRC="$HOME/.xsessionrc"                         # run by the login manager before Window Maker starts
REPO_BASE="${WMC_REPO_BASE:-https://github.com/jaderfeijo}"

DRY=0 YES=0 SUDO_OK=1 CMD=menu IDS=() NO_SELF=0 LOCAL=0

# ---------------------------------------------------------------------------------------------- the catalogue
# id | kind (module = modules/NAME in this repository, repo = github.com/jaderfeijo/NAME) | source | apt packages it needs | title | description
CATALOGUE=(
"super-keys|repo|wmaker-super-keys|xbindkeys wmctrl x11-utils python3 rofi|macOS-style Super keys|Super+Space launcher, Super+1..9 desktops, tiling, focus by direction, show desktop, lock key. Also changes some of Window Maker's own shortcuts (undone by remove)."
"focus|module|focus|python3 python3-xlib|Focus follows mouse|Focus follows the pointer and the window under it is raised at once. Takes effect when Window Maker is next started."
"wmaker-randr|module|wmaker-randr|build-essential autoconf automake libtool pkg-config libxrandr-dev libxft-dev libxpm-dev libxmu-dev libxext-dev libxrender-dev libfontconfig-dev libpng-dev libjpeg-dev libtiff-dev libgif-dev libwebp-dev libmagic-dev libbsd-dev|Window Maker with RandR|Builds upstream Window Maker with RandR into ~/.local, so plugging in monitors or changing the primary display moves the Dock and resizes the desktop with no restart. Debian stays as the fallback. Used from the next login."
"shade-all|module|shade-all|wmctrl x11-utils xbindkeys python3|Shade all windows|One key rolls up every window on the desktop to its title bar; press again to unroll. Uses Super+Shift+H."
"thinkpad|module|thinkpad|xbindkeys brightnessctl dunst libnotify-bin wireplumber xinput|ThinkPad keys|Brightness, volume, mute and mic-mute keys with an on-screen bar, plus touchpad tap-to-click. For Lenovo ThinkPads."
"power|module|power|rofi acpid python3|Power-button menu|The power button opens a menu: lock, suspend, log out, restart, shut down. Needs sudo for a few files in /etc."
"lock|module|lock|xss-lock i3lock python3|Lock on suspend|The screen locks before the machine sleeps and on 'loginctl lock-session' (xss-lock + i3lock)."
"xterm|module|xterm|python3 x11-xserver-utils|xterm clipboard|xterm shares the CLIPBOARD: Ctrl+Shift+C/V, Super+C/V, OSC 52. Leaves your text scale alone."
"caps-lock|module|caps-lock|python3 x11-xkb-utils|Normal Caps Lock|Debian's Window Maker turns Caps Lock into the Compose key at every login; this takes that off again, for good, and keeps your other keyboard options."
"no-welcome|module|no-welcome|python3|No welcome window|Switches off the welcome window that Debian's Window Maker live packages show at every login (moved to AutoStart/Disabled; undone by remove)."
"window-keys|module|window-keys|wmctrl x11-utils xbindkeys python3|Super+Q and resize keys|Super+Q closes the window (also the highlighted one in the Super+Tab switcher); Super+Shift+Alt +/- resize around the centre and Super+Shift+Alt+arrows move it; add Control for big steps."
"quiet-move|module|quiet-move|python3|No move tooltip|Hides the position box Window Maker shows while you drag a window. Takes effect when Window Maker is next started."
"workspace-name|module|workspace-name|python3|Workspace name flash|Flashes the name of the workspace in the centre of the screen when you switch workspaces. Takes effect when Window Maker is next started."
"fixed-nerd|repo|fixed-nerd|xfonts-utils x11-xserver-utils python3|Fixed Nerd font|The classic X11 'fixed' 6x13 font with Powerline and Nerd Font icons and TUI symbols, as the default font of xterm and uxterm. Used by new terminals."
"webapp|module|webapp|curl file chromium|Web apps (Chromium)|The 'webapp' command: turn a website into a launcher entry that opens in a tab-less Chromium window."
"chromium-scale|module|chromium-scale|chromium python3|Smaller Chromium|Chromium's own interface and every web page at 80% (20% smaller than stock), through its launcher. Quit Chromium and start it again."
"flatpak|module|flatpak|flatpak xdg-utils python3|Flatpak in the session|The 'flatpak-wm' command; makes Flatpak apps and slack:// style sign-in links work, for future logins."
"pwvol|repo|wmpwvol|python3-cairo pipewire-bin wireplumber|Volume dockapp|PipeWire volume dockapp: live meter, mute, scroll to change. Drag its icon into the Dock once."
"bluetooth|repo|wmbluetooth|python3-cairo python3-gi bluez rofi|Bluetooth dockapp|Connected Bluetooth devices and their batteries; click to connect. Drag its icon into the Dock once."
"battery|repo|wmbattery-power-draw||Battery dockapp with watts|Debian's wmbattery, built with a patch that shows the power draw in watts. Builds from source (sudo for build tools)."
"omarchy|module|omarchy|gum jq fzf rofi curl file xterm chromium|Omarchy ports|Omarchy's web-app and TUI installers, a web-app catalog and fzf software pickers, on Window Maker."
"getapp|repo|getapp|fzf python3|getapp installer|One fuzzy search to install from apt, Flatpak, the Snap Store and web apps."
)
declare -A KIND SRC DEPS TITLE DESC
IDS_ALL=()
for row in "${CATALOGUE[@]}"; do
  IFS='|' read -r id kind src deps title desc <<<"$row"
  IDS_ALL+=("$id"); KIND[$id]=$kind; SRC[$id]=$src; DEPS[$id]=$deps; TITLE[$id]=$title; DESC[$id]=$desc
done

# ---------------------------------------------------------------------------------------------- helpers
if [ -t 1 ]; then B=$'\033[1m' G=$'\033[32m' Y=$'\033[33m' R=$'\033[31m' D=$'\033[2m' N=$'\033[0m'; else B= G= Y= R= D= N=; fi
say() { printf '%s\n' "$*"; }
warn() { printf '%s%s%s\n' "$Y" "$*" "$N" >&2; }
die() { printf '%s%s%s\n' "$R" "$*" "$N" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

url_of() { echo "$REPO_BASE/${SRC[$1]}.git"; }          # for kind=repo
WM_SRC=""                                                                  # where modules/ lives (set by locate_src)
src_dir() { if [ "${KIND[$1]}" = module ]; then echo "$WM_SRC/modules/${SRC[$1]}"; else echo "$CACHE_DIR/src/$1"; fi; }

# A checkout we are run from, or WMODERN_SRC, is used as it is; otherwise a shallow clone of wmodern is kept in the cache.
locate_src() {
  [ -n "$WM_SRC" ] && return 0
  local me="${BASH_SOURCE[0]:-}" dir=""
  [ -n "$me" ] && [ -f "$me" ] && dir=$(cd "$(dirname "$me")" && pwd)
  if [ -n "${WMODERN_SRC:-}" ]; then WM_SRC=$WMODERN_SRC
  elif [ -n "$dir" ] && [ -d "$dir/modules" ] && [ -f "$dir/install.sh" ]; then WM_SRC=$dir; LOCAL=1
  else
    WM_SRC="$CACHE_DIR/wmodern"; mkdir -p "$CACHE_DIR"
    if [ -d "$WM_SRC/.git" ]; then git -C "$WM_SRC" fetch -q --depth 1 origin HEAD && git -C "$WM_SRC" reset -q --hard FETCH_HEAD
    else rm -rf "$WM_SRC"; git clone -q --depth 1 "$HOME_URL" "$WM_SRC"; fi
  fi
  [ -d "$WM_SRC/modules" ] || die "wmodern's modules were not found in $WM_SRC"
}
# A module's version is a hash of its files: it changes exactly when something in that module changes.
module_rev() { (cd "$WM_SRC/modules/${SRC[$1]}" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -c1-40); }

state_rev() { [ -f "$STATE" ] && awk -F'\t' -v id="$1" '$1==id{print $2}' "$STATE" | tail -1 || true; }
state_set() {
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$STATE_DIR"; touch "$STATE"
  { grep -v -P "^$1\t" "$STATE" || true; printf '%s\t%s\t%s\n' "$1" "$2" "$(date +%F)"; } >"$STATE.new" && mv "$STATE.new" "$STATE"
}
state_del() { [ -f "$STATE" ] && { { grep -v -P "^$1\t" "$STATE" || true; } >"$STATE.new"; mv "$STATE.new" "$STATE"; } || true; }

# marked block in a text file (same convention as the individual installers); "add" goes before a final "exit 0"
block() {  # block add|remove FILE NAME [CONTENT]
  [ "$DRY" = 1 ] && { say "  [dry-run] $1 block '$3' in $2"; return 0; }
  python3 - "$1" "$2" "$3" "${4:-}" <<'PY'
import os, re, sys
action, path, name, content = sys.argv[1:5]
begin, end = f"# >>> {name} >>>", f"# <<< {name} <<<"
text = open(path).read() if os.path.exists(path) else None
if text is None and action == "remove":
    sys.exit(0)
text = re.sub(r"(?ms)^" + re.escape(begin) + r"\n.*?^" + re.escape(end) + r"\n?", "", text or "")
if action == "remove":
    text = text.rstrip("\n") + "\n" if text.strip() else ""
else:
    blk = f"{begin}\n{content.rstrip()}\n{end}\n"
    last = list(re.finditer(r"(?m)^exit\s+0\s*$", text))
    if last:
        i = last[-1].start(); text = text[:i] + blk + text[i:]
    else:
        text = text.rstrip("\n"); text = (text + "\n\n" if text else "#!/bin/sh\n\n") + blk
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
open(path, "w").write(text)
PY
  [ -f "$2" ] && head -c 2 "$2" | grep -q '^#!' && chmod +x "$2" || true
}

# A marked block in ~/.xsessionrc. Unlike the autostart file, this runs before the session restore starts the saved
# windows, so whatever those windows need at startup (the font path for xterm) is already there.
xsession_block() {  # xsession_block add|remove NAME [CONTENT]
  [ "$DRY" = 1 ] && { say "  [dry-run] $1 block '$2' in $XSESSIONRC"; return 0; }
  python3 - "$1" "$XSESSIONRC" "$2" "${3:-}" <<'PY'
import os, re, sys
action, path, name, content = sys.argv[1:5]
begin, end = f"# >>> {name} >>>", f"# <<< {name} <<<"
text = open(path).read() if os.path.exists(path) else ""
text = re.sub(r"(?ms)^" + re.escape(begin) + r"\n.*?^" + re.escape(end) + r"\n?", "", text)
text = re.sub(r"\n{3,}", "\n\n", text).lstrip("\n")   # other installers' blocks leave blank lines; keep the file stable
if action == "add":
    text = text.rstrip("\n") + ("\n\n" if text.strip() else "") + f"{begin}\n{content.rstrip()}\n{end}\n"
elif not text.strip():
    sys.exit(0)
open(path, "w").write(text)
PY
}

# Fixed Nerd is a bitmap font on the X font path. Its own installer adds it to the autostart file, which runs too late
# for a restored uxterm: it opens first, cannot find the font and falls back to the default one.
fixed_nerd_fontpath() {  # add|remove
  local d='${XDG_DATA_HOME:-$HOME/.local/share}/fonts/X11/fixed-nerd'
  xsession_block "$1" "$SELF_NAME:fixed-nerd" "# Fixed Nerd on the X font path before the session restore starts its terminals
d=\"$d\"
[ -d \"\$d\" ] && { xset -fp \"\$d\" 2>/dev/null; xset +fp \"\$d\" && xset fp rehash; } >/dev/null 2>&1"
}

remote_rev() { if [ "${KIND[$1]}" = module ]; then module_rev "$1"; else git ls-remote "$(url_of "$1")" HEAD 2>/dev/null | awk '{print $1; exit}'; fi; }

fetch_src() {  # clone or update the cached checkout of component $1; prints nothing, sets FETCHED_REV
  local id=$1 dir url
  if [ "${KIND[$id]}" = module ]; then FETCHED_REV=$(module_rev "$id"); return 0; fi
  dir=$(src_dir "$1"); url=$(url_of "$1")
  mkdir -p "$CACHE_DIR/src"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch -q --depth 1 origin HEAD && git -C "$dir" reset -q --hard FETCH_HEAD
  else
    rm -rf "$dir"; git clone -q --depth 1 "$url" "$dir"
  fi
  FETCHED_REV=$(git -C "$dir" rev-parse HEAD)
}

# ---------------------------------------------------------------------------------------------- per-component actions
selected() { local x; for x in "${PLAN[@]:-}"; do [ "$x" = "$1" ] && return 0; done; return 1; }
installed_or_planned() { [ -n "$(state_rev "$1")" ] || selected "$1"; }

dockapp_block() {  # dockapp_block add|remove NAME
  local n=$2 content
  content="pgrep -f \"^python3 .*/$n\$\" >/dev/null || \"\$HOME/.local/bin/$n\" >/dev/null 2>&1 &"
  block remove "$AUTOSTART" "$OLD_NAME:$n"
  block "$1" "$AUTOSTART" "$SELF_NAME:$n" "$content"
}

do_install() {  # runs inside the component's checkout
  local id=$1 dry=""; [ "$DRY" = 1 ] && dry="--dry-run"
  case $id in
    super-keys) local extra=(); installed_or_planned xterm && extra+=(--no-xterm); installed_or_planned shade-all && extra+=(--no-show-desktop); ./install.sh --no-restart $dry "${extra[@]}" ;;
    focus)      ./focus-follows-mouse.sh $dry ;;
    wmaker-randr) ./install.sh $dry ;;
    shade-all)  ./install.sh --no-restart --skip-deps-check $dry ;;
    omarchy)    ./install.sh --skip-deps-check $dry ;;
    thinkpad)   ./setup.sh --no-restart --skip-deps-check $dry ;;
    power)      local extra=(); [ "$SUDO_OK" = 1 ] || extra+=(--no-system); ./install.sh --no-restart --skip-deps-check $dry "${extra[@]}" ;;
    lock)       ./install.sh --no-restart --skip-deps-check $dry ;;
    xterm)      ./install.sh --no-apply $dry ;;
    caps-lock)  ./install.sh --no-apply $dry ;;
    no-welcome) ./install.sh $dry ;;
    window-keys) ./install.sh --no-restart --skip-deps-check $dry ;;
    quiet-move) ./install.sh $dry ;;
    workspace-name) ./install.sh $dry ;;
    fixed-nerd) ./install.sh --no-apply $dry; fixed_nerd_fontpath add ;;
    webapp)     ./install.sh $dry ;;
    chromium-scale) ./install.sh $dry ;;
    flatpak)    ./install.sh $dry; if [ "$DRY" = 1 ]; then say "  [dry-run] flatpak-wm fix"; else "$BIN/flatpak-wm" fix; fi ;;
    pwvol|bluetooth)
      if [ "$DRY" = 1 ]; then say "  [dry-run] make install PREFIX=\$HOME/.local   (and add $id to the Window Maker autostart file)"
      else make install PREFIX="${PREFIX:-$HOME/.local}"; fi
      dockapp_block add "wm$( [ "$id" = pwvol ] && echo pwvol || echo bluetooth )" ;;
    battery)    local extra=(); [ "$SUDO_OK" = 1 ] && extra+=(--install-deps); ./install.sh $dry "${extra[@]}" ;;
    getapp)     local extra=(); [ "$SUDO_OK" = 1 ] || extra+=(--no-deps); ./install.sh $dry "${extra[@]}" ;;
  esac
}

do_remove() {
  local id=$1 dry=""; [ "$DRY" = 1 ] && dry="--dry-run"
  case $id in
    super-keys) ./install.sh --uninstall --no-restart $dry ;;
    focus)      ./focus-follows-mouse.sh --click-to-focus $dry ;;
    wmaker-randr) ./install.sh --uninstall $dry ;;
    shade-all)  ./install.sh --uninstall --no-restart --skip-deps-check $dry ;;
    omarchy)    ./install.sh --uninstall $dry ;;
    thinkpad)   ./setup.sh --uninstall --no-restart --skip-deps-check $dry ;;
    power)      local extra=(); [ "$SUDO_OK" = 1 ] || extra+=(--no-system); ./install.sh --uninstall --no-restart --skip-deps-check $dry "${extra[@]}" ;;
    lock)       ./install.sh --uninstall --no-restart $dry ;;
    xterm)      ./install.sh --uninstall --no-apply $dry ;;
    caps-lock)  ./install.sh --uninstall $dry ;;
    no-welcome) ./install.sh --uninstall $dry ;;
    window-keys) ./install.sh --uninstall --no-restart --skip-deps-check $dry ;;
    quiet-move) ./install.sh --uninstall $dry ;;
    workspace-name) ./install.sh --uninstall $dry ;;
    fixed-nerd) ./install.sh --uninstall --no-apply $dry; fixed_nerd_fontpath remove ;;
    webapp|flatpak|chromium-scale) ./install.sh --uninstall $dry ;;
    pwvol|bluetooth)
      local n=wm$id
      if [ "$DRY" = 1 ]; then say "  [dry-run] make uninstall"; else make uninstall PREFIX="${PREFIX:-$HOME/.local}"; fi
      dockapp_block remove "$n" ;;
    battery|getapp) ./install.sh --uninstall $dry ;;
  esac
}

# ---------------------------------------------------------------------------------------------- status and menu
declare -A REMOTE ST
compute_status() {
  locate_src
  local id tmp; tmp=$(mktemp -d)
  for id in "${IDS_ALL[@]}"; do ( remote_rev "$id" >"$tmp/$id" ) & done; wait
  for id in "${IDS_ALL[@]}"; do
    REMOTE[$id]=$(cat "$tmp/$id" 2>/dev/null || true)
    local have_rev; have_rev=$(state_rev "$id")
    if [ -z "$have_rev" ]; then ST[$id]=new
    elif [ -z "${REMOTE[$id]}" ]; then ST[$id]=installed
    elif [ "$have_rev" = "${REMOTE[$id]}" ]; then ST[$id]=current
    else ST[$id]=update; fi
  done
  rm -rf "$tmp"
}
status_label() {
  case ${ST[$1]} in
    new) printf '%s' "${D}not installed${N}" ;;
    current) printf '%s' "${G}installed, up to date${N}" ;;
    update) printf '%s' "${Y}update available${N}" ;;
    installed) printf '%s' "${G}installed${N}" ;;
  esac
}

menu() {  # sets PLAN
  [ -r /dev/tty ] && : </dev/tty 2>/dev/null || die "No terminal to show the menu on. Use:  $SELF_NAME install ID...   (see: $SELF_NAME list)"
  exec 3</dev/tty
  local n=${#IDS_ALL[@]} cur=0 top=0 drawn=0 key rest i rows view
  local -a sel=()
  for ((i = 0; i < n; i++)); do [ "${ST[${IDS_ALL[i]}]}" = update ] && sel[i]=1 || sel[i]=0; done
  rows=$(tput lines 2>/dev/null || echo 24); view=$((rows - 9)); [ "$view" -gt "$n" ] && view=$n; [ "$view" -lt 4 ] && view=4
  local cols; cols=$(tput cols 2>/dev/null || echo 80)
  tput civis 2>/dev/null || true
  trap 'tput cnorm 2>/dev/null || true' RETURN
  while :; do
    [ "$cur" -lt "$top" ] && top=$cur; [ "$cur" -ge $((top + view)) ] && top=$((cur - view + 1))
    [ "$drawn" -gt 0 ] && printf '\033[%dA' "$drawn"; printf '\033[J'
    local lines=0
    printf '%s\n%s\n\n' "${B}wmodern${N}  ${D}Window Maker customisations${N}" "${D}↑/↓ move   space select   a all   n none   u updates   Enter install   q quit${N}"; lines=$((lines + 3))
    for ((i = top; i < top + view && i < n; i++)); do
      local id=${IDS_ALL[i]} mark=" " ptr=" "
      [ "${sel[i]}" = 1 ] && mark="${G}x${N}"
      [ "$i" = "$cur" ] && ptr="${B}>${N}"
      printf '%s [%s] %-26s %s\n' "$ptr" "$mark" "${TITLE[$id]}" "$(status_label "$id")"; lines=$((lines + 1))
    done
    local more=$((n - top - view)); [ "$more" -lt 0 ] && more=0
    printf '%s\n' "${D}$( [ "$top" -gt 0 ] && echo "↑ $top more  " )$( [ "$more" -gt 0 ] && echo "↓ $more more" )${N}"; lines=$((lines + 1))
    printf '\n%s\n' "$(fold -s -w $((cols - 4)) <<<"${DESC[${IDS_ALL[cur]}]}" | sed 's/^/  /' | head -3)"; lines=$((lines + 1 + $(fold -s -w $((cols - 4)) <<<"${DESC[${IDS_ALL[cur]}]}" | head -3 | wc -l)))
    drawn=$lines
    IFS= read -rsn1 key <&3 || key=q
    if [ "$key" = $'\033' ]; then
      rest=""; IFS= read -rsn2 -t 0.05 rest <&3 || true
      case $rest in '[A') key=up ;; '[B') key=down ;; '') key=q ;; *) key=other ;; esac
    fi
    case $key in
      up|k) [ "$cur" -gt 0 ] && cur=$((cur - 1)) ;;
      down|j) [ "$cur" -lt $((n - 1)) ] && cur=$((cur + 1)) ;;
      ' ') sel[cur]=$((1 - sel[cur])) ;;
      a) local all=1; for ((i = 0; i < n; i++)); do [ "${sel[i]}" = 0 ] && all=0; done; for ((i = 0; i < n; i++)); do sel[i]=$((1 - all)); done ;;
      n) for ((i = 0; i < n; i++)); do sel[i]=0; done ;;
      u) for ((i = 0; i < n; i++)); do [ "${ST[${IDS_ALL[i]}]}" = update ] && sel[i]=1; done ;;
      q) PLAN=(); echo; return 0 ;;
      '') PLAN=(); for ((i = 0; i < n; i++)); do [ "${sel[i]}" = 1 ] && PLAN+=("${IDS_ALL[i]}"); done; echo; return 0 ;;
    esac
  done
}

# ---------------------------------------------------------------------------------------------- running a plan
confirm() {  # confirm "question"  (default yes)
  [ "$YES" = 1 ] && return 0
  local a; if [ -r /dev/tty ]; then read -r -p "$1 [Y/n] " a </dev/tty || a=n; else return 1; fi
  case $a in ''|y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

ensure_tools() {
  local missing=()
  have git || missing+=(git); have python3 || missing+=(python3); have curl || missing+=(curl)
  [ "${#missing[@]}" -eq 0 ] && return 0
  say "Needed to run this installer: ${missing[*]}"
  if have apt-get && [ "$SUDO_OK" = 1 ] && confirm "Install them with sudo apt-get?"; then
    [ "$DRY" = 1 ] && { say "  [dry-run] sudo apt-get install -y ${missing[*]}"; return 0; }
    sudo apt-get install -y "${missing[@]}"
  else die "Please install: ${missing[*]}"; fi
}

install_deps() {
  [ "$SUDO_OK" = 1 ] || return 0
  have apt-get || { warn "apt-get not found: install the needed packages yourself (see each README)."; return 0; }
  local want=() p id
  for id in "$@"; do for p in ${DEPS[$id]}; do dpkg -s "$p" >/dev/null 2>&1 || want+=("$p"); done; done
  [ "${#want[@]}" -eq 0 ] && return 0
  mapfile -t want < <(printf '%s\n' "${want[@]}" | sort -u)
  # a package that does not exist (other Debian-family distributions) must not abort everything
  local ok=() p2; for p2 in "${want[@]}"; do apt-cache show "$p2" >/dev/null 2>&1 && ok+=("$p2") || warn "package not available here, skipped: $p2"; done
  [ "${#ok[@]}" -eq 0 ] && return 0
  say "${B}Packages to install (sudo):${N} ${ok[*]}"
  if [ "$DRY" = 1 ]; then say "  [dry-run] sudo apt-get install -y --no-install-recommends ${ok[*]}"; return 0; fi
  confirm "Install these packages?" || { warn "Skipped. Some items may not work until they are installed."; return 0; }
  sudo apt-get install -y --no-install-recommends "${ok[@]}"
}

install_self() {
  [ "$NO_SELF" = 1 ] || [ "$DRY" = 1 ] && return 0
  locate_src
  local dest="$BIN/$SELF_NAME"
  mkdir -p "$BIN"
  cmp -s "$WM_SRC/install.sh" "$dest" 2>/dev/null || install -m 755 "$WM_SRC/install.sh" "$dest"
  # the earlier version of this installer was called wmaker-customise
  [ -f "$BIN/$OLD_NAME" ] && { rm -f "$BIN/$OLD_NAME"; say "Replaced the old '$OLD_NAME' command by '$SELF_NAME'."; }
  case ":$PATH:" in *":$BIN:"*) ;; *) warn "Note: $BIN is not on your PATH; run it as $dest" ;; esac
}

run_plan() {
  PLAN=("$@")
  [ "${#PLAN[@]}" -gt 0 ] || { say "Nothing selected."; return 0; }
  # shade-all owns Super+Shift+H, so the Super keys must be (re)applied without their show-desktop binding
  if selected shade-all && ! selected super-keys && [ -n "$(state_rev super-keys)" ]; then
    PLAN=(super-keys "${PLAN[@]}"); ST[super-keys]=${ST[super-keys]:-installed}
    say "(Re-applying super-keys too: shade-all takes over Super+Shift+H from its show-desktop binding.)"
  fi
  local id; say; say "${B}Plan:${N}"
  for id in "${PLAN[@]}"; do printf '  - %s (%s)\n' "${TITLE[$id]}" "${ST[$id]:-}"; done
  say
  confirm "Go ahead?" || { say "Cancelled."; return 0; }
  ensure_tools
  install_deps "${PLAN[@]}"
  local failed=() done_=() rev
  for id in "${PLAN[@]}"; do
    say; say "${B}==> ${TITLE[$id]}${N}"
    if ! fetch_src "$id"; then warn "could not download ${SRC[$id]}"; failed+=("$id"); continue; fi
    rev=$FETCHED_REV
    if ( cd "$(src_dir "$id")" && do_install "$id" ); then state_set "$id" "$rev"; done_+=("$id"); else warn "${TITLE[$id]} failed (see above)"; failed+=("$id"); fi
  done
  install_self
  say; say "${B}Summary${N}"
  for id in "${done_[@]:-}"; do [ -n "$id" ] && say "  ${G}ok${N}      ${TITLE[$id]}$( [ "$DRY" = 1 ] && echo ' (dry run)' )"; done
  for id in "${failed[@]:-}"; do [ -n "$id" ] && say "  ${R}failed${N}  ${TITLE[$id]}"; done
  next_steps
  [ "${#failed[@]}" -eq 0 ] || return 1
}

next_steps() {
  [ "$DRY" = 1 ] && return 0
  say; say "${B}Next${N}"
  say "  * Log out and in again (or use Window Maker > Restart when you choose) so key bindings, autostart and"
  say "    Window Maker's own settings take effect. Nothing in your running session was touched."
  selected pwvol || selected bluetooth && say "  * Dockapps: after the next login, drag their icons into the Dock once, so they keep their slot."
  say "  * Later:  $SELF_NAME   (the list)    $SELF_NAME update    $SELF_NAME remove ID"
}

# ---------------------------------------------------------------------------------------------- commands
cmd_list() {
  compute_status
  printf '%-12s %-28s %s\n' ID NAME STATUS
  local id; for id in "${IDS_ALL[@]}"; do printf '%-12s %-28s %s\n' "$id" "${TITLE[$id]}" "$(status_label "$id")"; done
}

self_update() {  # use the newest installer: if the cached wmodern has a different install.sh, switch to it
  [ "$NO_SELF" = 1 ] || [ "$LOCAL" = 1 ] && return 0
  locate_src
  local dest="$BIN/$SELF_NAME"
  if [ -f "$dest" ] && ! cmp -s "$WM_SRC/install.sh" "$dest" && [ "$DRY" = 0 ]; then
    install -m 755 "$WM_SRC/install.sh" "$dest"; say "Updated the installer itself."
    exec "$dest" --no-self-update "${ORIG_ARGS[@]}"
  fi
}

cmd_update() {
  compute_status
  local id up=(); for id in "${IDS_ALL[@]}"; do [ "${ST[$id]}" = update ] && up+=("$id"); done
  [ "${#up[@]}" -eq 0 ] && { say "Everything installed is up to date."; return 0; }
  run_plan "${up[@]}"
}

cmd_remove() {
  [ "${#IDS[@]}" -gt 0 ] || die "usage: $SELF_NAME remove ID...   (ids: ${IDS_ALL[*]})"
  local id failed=0
  for id in "${IDS[@]}"; do [ -n "${KIND[$id]:-}" ] || die "unknown id: $id (ids: ${IDS_ALL[*]})"; done
  confirm "Remove: ${IDS[*]}?" || { say "Cancelled."; return 0; }
  for id in "${IDS[@]}"; do
    say; say "${B}==> removing ${TITLE[$id]}${N}"
    fetch_src "$id" || { warn "could not download ${SRC[$id]} (needed for its uninstaller)"; failed=1; continue; }
    if ( cd "$(src_dir "$id")" && do_remove "$id" ); then
      state_del "$id"
      if [ "$id" = shade-all ] && [ -n "$(state_rev super-keys)" ] && fetch_src super-keys; then
        say "Giving Super+Shift+H back to super-keys' show-desktop ..."
        ( cd "$(src_dir super-keys)" && do_install super-keys ) || warn "could not re-apply super-keys"
      fi
    else failed=1; fi
  done
  return $failed
}

usage() {
  cat <<USAGE
Usage: $SELF_NAME [menu]                    choose what to install (default)
       $SELF_NAME list                      what exists and what is installed
       $SELF_NAME install [ID...|all]       install or re-apply the named items without the menu
       $SELF_NAME update                    install newer versions of everything already installed
       $SELF_NAME remove ID...              uninstall items
Options: --yes (no questions)  --dry-run (change nothing)  --no-sudo (no apt, no /etc changes)  --no-self-update
Items: ${IDS_ALL[*]}
USAGE
}

# ---------------------------------------------------------------------------------------------- main
ORIG_ARGS=("$@")
while [ $# -gt 0 ]; do
  case $1 in
    menu|list|install|update|remove) CMD=$1 ;;
    --yes|-y) YES=1 ;;
    --dry-run|-n) DRY=1 ;;
    --no-sudo) SUDO_OK=0 ;;
    --no-self-update) NO_SELF=1 ;;
    -h|--help|help) usage; exit 0 ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *) IDS+=("$1") ;;
  esac
  shift
done
[ ! -f "$STATE" ] && [ -f "$OLD_STATE_DIR/installed.tsv" ] && [ "$DRY" = 0 ] && { mkdir -p "$STATE_DIR"; cp "$OLD_STATE_DIR/installed.tsv" "$STATE"; }
[ "$(id -u)" = 0 ] && warn "Running as root installs into root's home. Run it as your normal user."
ensure_tools
for id in "${IDS[@]:-}"; do
  [ -z "$id" ] && continue
  [ "$id" = all ] || [ -n "${KIND[$id]:-}" ] || die "unknown item: $id (items: ${IDS_ALL[*]})"
done

locate_src
case $CMD in
  list) cmd_list ;;
  update) self_update; cmd_update ;;
  remove) cmd_remove ;;
  install)
    compute_status
    [ "${#IDS[@]}" -gt 0 ] || die "usage: $SELF_NAME install ID...|all"
    [ "${IDS[0]}" = all ] && IDS=("${IDS_ALL[@]}")
    run_plan "${IDS[@]}" ;;
  menu)
    [ "${#IDS[@]}" -eq 0 ] || die "give item names to 'install', not to the menu"
    compute_status
    PLAN=(); menu
    [ "${#PLAN[@]}" -gt 0 ] && run_plan "${PLAN[@]}" || say "Nothing selected." ;;
esac

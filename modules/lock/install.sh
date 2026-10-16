#!/usr/bin/env bash
# Locks the screen before the machine suspends and on `loginctl lock-session`, using xss-lock + i3lock.
# Run ./install.sh --help for the options. It adds a marked block to Window Maker's autostart file and never replaces
# anything of yours; --uninstall removes it again.
set -euo pipefail

NAME=lock-on-suspend
AUTOSTART="${GNUSTEP_USER_ROOT:-$HOME/GNUstep}/Library/WindowMaker/autostart"
XBINDKEYSRC="$HOME/.xbindkeysrc"
COLOR=000000 KEY="" DRY=0 UNINSTALL=0 RESTART=1 DEPS=1 INSTALL_DEPS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --color) COLOR="${2:?--color needs RRGGBB}"; shift ;;
    --bind-key) KEY="${2:-Mod4 + Control + q}"; [ $# -ge 2 ] && [[ "${2:-}" != --* ]] && shift || KEY="Mod4 + Control + q" ;;
    --autostart-file) AUTOSTART="${2:?--autostart-file needs a path}"; shift ;;
    --uninstall) UNINSTALL=1 ;;
    --dry-run) DRY=1 ;;
    --no-restart) RESTART=0 ;;
    --install-deps) INSTALL_DEPS=1 ;;
    --skip-deps-check) DEPS=0 ;;
    -h|--help)
      cat <<USAGE
Usage: ./install.sh [--color RRGGBB] [--bind-key ["Mod4 + Control + q"]] [--autostart-file FILE] [--dry-run] [--uninstall]
                    [--install-deps] [--no-restart]
  --color RRGGBB     lock screen colour (default 000000, black)
  --bind-key [KEY]   also bind a key to lock now, in ~/.xbindkeysrc (default Super+Ctrl+Q; xbindkeys syntax)
  --autostart-file   start-up file to use instead of Window Maker's autostart (any shell script run at login)
USAGE
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
[[ "$COLOR" =~ ^[0-9A-Fa-f]{6}$ ]] || { echo "--color must be six hex digits, e.g. 1d2021" >&2; exit 2; }

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
  block remove "$AUTOSTART"; block remove "$XBINDKEYSRC"
  [ "$RESTART" = 1 ] && [ "$DRY" = 0 ] && [ -n "${DISPLAY:-}" ] && { pkill -x xss-lock || true; pkill -x xbindkeys && (setsid xbindkeys >/dev/null 2>&1 &) || true; }
  echo "Removed. The screen no longer locks on suspend."; exit 0
fi

if [ "$DEPS" = 1 ]; then
  missing=(); have xss-lock || missing+=(xss-lock); have i3lock || missing+=(i3lock); have python3 || missing+=(python3)
  [ -n "$KEY" ] && ! have xbindkeys && missing+=(xbindkeys)
  if [ "${#missing[@]}" -gt 0 ]; then
    if [ "$INSTALL_DEPS" = 1 ] && have apt-get; then run sudo apt-get install -y "${missing[@]}"
    else echo "Missing: ${missing[*]}. Install them with:  sudo apt install ${missing[*]}   (or use --install-deps)"; [ "$DRY" = 1 ] || exit 1; fi
  fi
fi

tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
LOCK="xss-lock --transfer-sleep-lock -- i3lock -n -c $COLOR"
printf '%s\n' "# Lock the screen before suspend and on 'loginctl lock-session'" "$LOCK &" > "$tmp"
if [ ! -f "$AUTOSTART" ] && [ "$DRY" = 0 ]; then mkdir -p "$(dirname "$AUTOSTART")"; printf '#!/bin/sh\nexit 0\n' > "$AUTOSTART"; chmod +x "$AUTOSTART"; fi
block add "$AUTOSTART" "$tmp"
echo "Start-up line added to $AUTOSTART:  $LOCK &"
if [ -n "$KEY" ]; then
  printf '%s\n' "# Lock the screen now" "\"loginctl lock-session\"" "    $KEY" > "$tmp"
  block add "$XBINDKEYSRC" "$tmp"
  echo "Key binding added to $XBINDKEYSRC: $KEY"
fi

if [ "$RESTART" = 1 ] && [ "$DRY" = 0 ] && [ -n "${DISPLAY:-}" ]; then
  pkill -x xss-lock 2>/dev/null || true
  (setsid xss-lock --transfer-sleep-lock -- i3lock -n -c "$COLOR" >/dev/null 2>&1 &)
  [ -n "$KEY" ] && { pkill -x xbindkeys 2>/dev/null || true; sleep 0.3; (setsid xbindkeys >/dev/null 2>&1 &); }
  echo "xss-lock started."
fi
echo
echo "Check it:  systemd-inhibit --list | grep xss-lock    (should show \"Lock screen first\")"
echo "           loginctl lock-session                      (locks now; type your login password and Enter to unlock)"

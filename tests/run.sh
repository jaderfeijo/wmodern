#!/usr/bin/env bash
# Tests for wmodern. Everything runs in a throwaway home directory with no X display; nothing real is touched.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FAIL=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; FAIL=1; }
check() { local what=$1; shift; if "$@" >/dev/null 2>&1; then ok "$what"; else bad "$what"; fi; }

echo "syntax"
for f in "$ROOT/install.sh" $(grep -rlE '^#!.*(bash|sh)' "$ROOT/modules" "$ROOT/tests" | sort -u); do check "bash -n ${f#$ROOT/}" bash -n "$f"; done

echo "privacy"
scan() { ! grep -rnIE "$2" "$ROOT" --exclude-dir=.git --exclude=run.sh >/dev/null; }
check "no absolute home directories" scan x '(/home/[a-z_][a-z0-9_-]*|/Users/[A-Za-z0-9_-]+)'
check "no e-mail addresses" scan x '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
check "no tokens or private keys" scan x '(ghp_[A-Za-z0-9]{20}|BEGIN [A-Z ]*PRIVATE KEY)'
host=$(hostname -s 2>/dev/null); user=$(id -un)     # this machine's names are looked up, never written down
[ -n "$host" ] && check "no host name" scan x "$host"
check "no user name in paths" scan x "/(home|Users)/$user"


echo "installer (modules only, in a scratch home)"
H=$(mktemp -d); trap 'rm -rf "$H"' EXIT
run() { env -u DISPLAY HOME="$H" XDG_CONFIG_HOME= XDG_DATA_HOME= XDG_CACHE_HOME= bash "$ROOT/install.sh" "$@" --no-sudo --no-self-update; }
MODS="focus shade-all thinkpad power lock xterm webapp flatpak omarchy"
check "list works" run list
check "dry run changes nothing" bash -c "$(declare -f run); H='$H'; ROOT='$ROOT'; run install $MODS --dry-run --yes && [ ! -e '$H/.xbindkeysrc' ] && [ ! -e '$H/.local/bin/webapp' ]"
check "install all modules" run install $MODS --yes
snap() { (cd "$H" && find . -type f -not -path './.cache/*' -not -name installed.tsv -not -name '*.bak-*' -print0 | sort -z | xargs -0 sha256sum | sha256sum); }
a=$(snap); run install $MODS --yes >/dev/null 2>&1; b=$(snap)
[ "$a" = "$b" ] && ok "second run changes nothing (idempotent)" || bad "second run changed files"
run install $MODS --yes >/dev/null 2>&1; c=$(snap); [ "$b" = "$c" ] && ok "third run changes nothing" || bad "third run changed files"
for m in thinkpad power lock; do [ "$(grep -c '>>>' "$H/GNUstep/Library/WindowMaker/autostart")" -ge 3 ] || bad "autostart blocks"; done
n=$(grep -c '>>> lock-on-suspend' "$H/GNUstep/Library/WindowMaker/autostart"); [ "$n" = 1 ] && ok "one lock block, not several" || bad "lock block count $n"
[ -x "$H/.local/bin/webapp" ] && [ -x "$H/.local/bin/flatpak-wm" ] && [ -x "$H/.local/bin/shade-all" ] && [ -x "$H/.local/bin/omarchy-webapp-install" ] && ok "commands installed and executable" || bad "commands missing"
check "all up to date after install" bash -c "$(declare -f run); H='$H'; ROOT='$ROOT'; ! run list | grep -E 'update available'"
sed -i 's/^focus\t[0-9a-f]*/focus\t0000000000000000000000000000000000000000/' "$H/.local/share/wmodern/installed.tsv"
check "detects an update" bash -c "$(declare -f run); H='$H'; ROOT='$ROOT'; run list | grep -E '^focus .*update available'"
check "update installs it" bash -c "$(declare -f run); H='$H'; ROOT='$ROOT'; run update --yes && ! run list | grep -q 'update available'"
check "remove works" run remove xterm focus shade-all omarchy --yes
[ "$(grep -c selectToClipboard "$H/.Xresources" 2>/dev/null)" = 0 ] && ok "removed block is gone" || bad "xterm block still there"
check "unknown item is refused" bash -c "$(declare -f run); H='$H'; ROOT='$ROOT'; ! run install nonsense --yes"

echo
[ "$FAIL" = 0 ] && echo "all tests passed" || { echo "SOME TESTS FAILED"; exit 1; }

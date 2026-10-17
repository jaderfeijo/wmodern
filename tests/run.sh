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
MODS="focus wmaker-randr shade-all thinkpad power lock xterm caps-lock no-welcome quiet-move workspace-name window-keys webapp chromium-scale default-browser flatpak omarchy"
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
[ -x "$H/.local/bin/xterm-open-url" ] && grep -q 'exec-selectable' "$H/.Xresources" && grep -q 'UXTerm\*VT100.translations' "$H/.Xresources" && ok "xterm: ctrl+click opener and bindings installed" || bad "xterm ctrl+click missing"
! grep -q '://' "$H/.Xresources" && ok "xterm: no literal // in ~/.Xresources (xrdb's cpp would cut the line off)" || bad "xterm: // in ~/.Xresources"
check "xterm-open-url ignores text that is not a URL" env PATH=/nonexistent /bin/sh "$H/.local/bin/xterm-open-url" "not a url"
check "remove works" run remove xterm focus shade-all omarchy --yes
[ "$(grep -c selectToClipboard "$H/.Xresources" 2>/dev/null)" = 0 ] && ok "removed block is gone" || bad "xterm block still there"
[ ! -e "$H/.local/bin/xterm-open-url" ] && ok "removed opener is gone" || bad "xterm-open-url left behind"
check "unknown item is refused" bash -c "$(declare -f run); H='$H'; ROOT='$ROOT'; ! run install nonsense --yes"

echo "fixed-nerd font path reaches ~/.xsessionrc (stub repository, scratch home)"
S=$(mktemp -d); mkdir -p "$S/fixed-nerd.git" && ( cd "$S/fixed-nerd.git" && printf '#!/bin/sh\nexit 0\n' > install.sh && chmod +x install.sh &&
  git init -q && git add . && git -c user.name=t -c user.email=t@example.invalid commit -qm stub )
X=$(mktemp -d); printf '# user line\nexport FOO=1\n' > "$X/.xsessionrc"
xrun() { env -u DISPLAY HOME="$X" XDG_CONFIG_HOME= XDG_DATA_HOME= XDG_CACHE_HOME= WMC_REPO_BASE="$S" bash "$ROOT/install.sh" "$@" --no-sudo --no-self-update; }
xrun install fixed-nerd --yes >/dev/null 2>&1; a=$(sha256sum "$X/.xsessionrc")
grep -q 'wmodern:fixed-nerd' "$X/.xsessionrc" && grep -q 'xset +fp' "$X/.xsessionrc" && grep -q 'FOO=1' "$X/.xsessionrc" && ok "font path block added, user lines kept" || bad "xsessionrc block missing"
xrun install fixed-nerd --yes >/dev/null 2>&1; [ "$a" = "$(sha256sum "$X/.xsessionrc")" ] && ok "re-install leaves ~/.xsessionrc unchanged" || bad "~/.xsessionrc changed on re-install"
sh -n "$X/.xsessionrc" && ok "~/.xsessionrc is valid shell" || bad "~/.xsessionrc has a syntax error"
xrun remove fixed-nerd --yes >/dev/null 2>&1; ! grep -q 'fixed-nerd' "$X/.xsessionrc" && grep -q 'FOO=1' "$X/.xsessionrc" && ok "remove takes the block out again" || bad "block left behind after remove"
rm -rf "$S" "$X"

echo
[ "$FAIL" = 0 ] && echo "all tests passed" || { echo "SOME TESTS FAILED"; exit 1; }

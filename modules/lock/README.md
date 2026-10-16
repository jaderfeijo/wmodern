# Window Maker: lock the screen on suspend (and on demand) with xss-lock + i3lock

> Module `lock` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install lock`, or use it on its own as described below.

Window Maker has no screen locker, so closing the lid or pressing suspend just resumes straight into your open
session. This makes the screen **lock before the machine goes to sleep**, so waking it asks for your password, and also
lets `loginctl lock-session` (or a key bound to it) lock it on demand.

## How it works

| Piece | Role |
|---|---|
| [`i3lock`](https://i3wm.org/i3lock/) | The locker. A plain coloured screen; you type your login password (there is no visible prompt) and press Enter. Works with any window manager. |
| [`xss-lock`](https://bitbucket.org/raymonad/xss-lock) | Watches systemd-logind. It takes a **delay inhibitor** ("Lock screen first") so suspend waits until the screen is locked, and it runs the locker when logind asks for a lock (`loginctl lock-session`) or the X screensaver fires. |

The line that does it, started from Window Maker's autostart file:

```
xss-lock --transfer-sleep-lock -- i3lock -n -c 000000 &
```

* `-n` (`--nofork`) keeps i3lock in the foreground, so xss-lock can tell when the screen is actually locked.
* `--transfer-sleep-lock` hands the sleep inhibitor to the locker, so the machine only sleeps once the lock is up
  (this is what closes the "unlocked for a moment after resume" gap).
* `-c 000000` is the colour; pick another with `--color`.

## Install

```
git clone https://github.com/jaderfeijo/wmodern.git && cd wmodern/modules/lock
./install.sh --dry-run                       # look first
./install.sh --bind-key                      # install, and bind Super+Ctrl+Q to "lock now"
```

Options: `--color 1d2021`, `--bind-key "Mod4 + l"` (xbindkeys syntax; needs `xbindkeys`), `--install-deps` (apt-installs
`xss-lock` and `i3lock`), `--autostart-file FILE` for another window manager or session script, `--uninstall`.
The installer only adds a clearly marked block to your autostart file; nothing of yours is replaced.

## Check that it works

```
systemd-inhibit --list | grep xss-lock       # shows "Lock screen first", mode delay
loginctl lock-session                        # locks now
systemctl suspend                            # locks, sleeps; waking it asks for the password
```

On my machine the screen locks on `loginctl lock-session` and the inhibitor is registered; I also suspended and
resumed with the lock in place. I did not set up an idle timeout. xss-lock also locks when the X screensaver fires, so
`xset s 600 5` (lock after ten minutes) should add that, but I have not tried it.

## Notes

* You unlock with the same password you log in with: i3lock authenticates through PAM.
* If the screen locker ever hangs, switch to a text console (`Ctrl+Alt+F2`), log in, and `pkill i3lock`.
* Pair it with the `power` module: its *Lock* entry runs `loginctl lock-session`.

# Window Maker: a power-button menu (lock, suspend, hibernate, log out, restart, shut down)

> Module `power` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install power`, or use it on its own as described below.

Press the laptop's power button and Window Maker's own shutdown dialog (`wmlive-shutdown`, the root menu's *Shutdown*) pops up. Without `wmlive-utils` installed, a rofi menu with **Lock, Suspend, Hibernate, Log out, Restart, Shut down** pops up instead. Press it
again to close the menu. Without this, systemd's default on a window manager is to power the machine off the moment
you touch the button.

Tested on a Lenovo ThinkPad with Debian 13, systemd, GDM and a Window Maker X11 session. The menu runs `systemctl` and
`loginctl`, so it should work on any systemd distribution; the log-out entry is Window Maker specific.

## How it works

```
power button -> firmware -> acpid -> /etc/acpi/power-menu.sh -> FIFO -> power-menu-listener -> rofi
                                     (root, outside your session)        (inside your session)
```

| File | Where it ends up | Role |
|---|---|---|
| `power-menu` | `~/.local/bin` | The rofi menu and what each entry runs |
| `power-menu-listener` | `~/.local/bin`, started from Window Maker's autostart | Waits on a FIFO in `$XDG_RUNTIME_DIR`; opens the menu, or closes it if it is already open |
| `acpi-power-menu.conf` | `/etc/acpi/events/power-menu` | Tells acpid to run our handler on a power-button event |
| `acpi-power-menu.sh` | `/etc/acpi/power-menu.sh` | Writes to every logged-in user's FIFO |
| `logind-power-key.conf` | `/etc/systemd/logind.conf.d/power-key.conf` | `HandlePowerKey=ignore`, so systemd does not power off on the press |
| `install.sh` | | Installs, tests and removes all of it |

## Install

```
git clone https://github.com/jaderfeijo/wmodern.git && cd wmodern/modules/power
./install.sh --dry-run            # see what it would do
./install.sh                      # install (asks for sudo for the /etc part; --install-deps installs acpid and rofi)
```

Then press the power button once, briefly. `./install.sh --uninstall` puts everything back (the button then powers off
again). `--no-system` installs only the part that runs in your session, for machines where `/etc` is managed elsewhere.
Needs `rofi` and `acpid` (`sudo apt install rofi acpid`).

## Things that cost me time

1. **Two events per press.** One press makes the firmware send two ACPI events (`button/power PBTN` and
   `button/power LNXPWRBN`) about 90 ms apart. A toggle that treats each as a press opens the menu and immediately
   closes it. The listener ignores anything within 400 ms of the previous event. (See them with `acpi_listen`.)
2. **Do not also bind `XF86PowerOff` in your key daemon.** At one point the menu stopped appearing, and it came back
   as soon as I removed my old `xbindkeys` binding for that key. That fits the binding opening the menu and the
   ACPI path "toggling" it closed again (I did not capture the key event to prove it). Use the ACPI route only.
3. **Why a FIFO and a helper in your session instead of running the menu from acpid.** acpid runs as root outside any
   login session, and `systemctl suspend` / `reboot` / `poweroff` are refused for processes that are not in one
   (polkit). So acpid only *pokes* a helper that already lives in your session, and the menu runs there.
4. **`HandlePowerKey=ignore` is needed.** Otherwise systemd-logind acts on the button itself. On Debian with GDM the
   login screen's session also holds a *block* inhibitor on power-key handling (`systemd-inhibit --list` shows
   `gsd-media-keys ... handle-power-key`), which made the button unreliable before I set this. A long press
   (about four seconds) still forces the machine off in hardware.
5. **Log out = ask Window Maker to exit** (`pkill -TERM -x wmaker`, the same as *Exit session*). My first version used
   `loginctl terminate-session`, which killed the whole session abruptly and GDM never brought the login screen back;
   the machine looked stuck (switching to the login screen's virtual terminal with `Ctrl+Alt+F1` got me out). I have
   not re-tested the clean-exit version on a real logout, so treat that entry as unverified. Change it with
   `POWER_MENU_LOGOUT='your command'`.
6. **Don't kill your own shell when testing.** `pkill -f power-menu-listener` also matches the command line of the
   shell you type it in. The listener keeps a pid file and replaces its previous copy by itself, so you do not need to.
7. **The button seems to need a short hold on some machines.** The software side adds about 25 ms after the event
   arrives; if the delay you feel is before the event shows up in `acpi_listen`, it is the firmware.

## Settings

| Variable | Default | |
|---|---|---|
| `ROFI` | `rofi` | the menu program (anything that reads lines on stdin and prints the choice, e.g. `dmenu`-style, also works if the arguments suit it) |
| `POWER_MENU_LOGOUT` | `pkill -TERM -x wmaker` | command for the *Log out* entry |

Hibernate is listed only when logind reports it as available (`CanHibernate` is `yes`: swap and a resume device are set up). Edit the entries at the top of `power-menu`. Lock uses `loginctl lock-session`; see the separate `lock` module
(linked from the directory) for a screen locker that reacts to it.

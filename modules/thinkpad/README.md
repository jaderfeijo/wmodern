# Lenovo ThinkPad on Window Maker: brightness, volume and mic-mute keys, with an on-screen bar (and tap-to-click)

> Module `thinkpad` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install thinkpad`, or use it on its own as described below.

Window Maker is a window manager, not a desktop environment, so nothing is listening to the ThinkPad's special keys:
the brightness, volume, mute and microphone-mute keys do nothing, and there is no on-screen feedback. This module fixes
that. Tested on a **Lenovo ThinkPad X230** with Debian 13, Window Maker, PipeWire and X11; other ThinkPads use the same
standard key names, so it should carry over.

## What is wrong, and what the keys really send

The keys are fine: the kernel (`thinkpad_acpi`) and X already turn them into standard keysyms. They simply have no
program attached. Check with `xmodmap -pke | grep XF86` or press the key in `xev`:

| Key | Keysym | Keycode on the X230 |
|---|---|---|
| Brightness down / up | `XF86MonBrightnessDown` / `XF86MonBrightnessUp` | 232 / 233 |
| Volume down / up | `XF86AudioLowerVolume` / `XF86AudioRaiseVolume` | 122 / 123 |
| Mute | `XF86AudioMute` | 121 |
| Microphone mute | `XF86AudioMicMute` | 198 |

## The fix

| Piece | Role |
|---|---|
| [`xbindkeys`](https://www.nongnu.org/xbindkeys/) | Runs a command when a keysym is pressed (`xbindkeys-thinkpad.conf`) |
| `osd` (script) | Does the change, then shows the bar. Volume and microphone through **`wpctl`** (PipeWire), brightness through **`brightnessctl`** |
| [`dunst`](https://dunst-project.org/) | Draws the pop-up. A progress bar comes from `notify-send -h int:value:N`; a stack tag makes each pop-up *replace* the last, so holding a key moves one bar instead of piling them up |
| `dunstrc` | Style: bottom-centre, dark, with a progress bar |
| `touchpad-tap.sh` | Turns on tap-to-click (see below) |
| `setup.sh` | Installs all of it and can remove it again |

Behaviour: volume moves in 5% steps, never above 100%, and a volume key un-mutes (like on a phone or a Mac). The
pop-up shows `Volume 45%` with a bar, `Volume muted`, `Microphone muted` / `on`, or `Brightness 30%`. Change the
step with `OSD_STEP=10`.

**The ThinkPad's mute and mic-mute LEDs just work.** `thinkpad_acpi` exposes them as `platform::mute` and
`platform::micmute` LEDs that follow the sound card's mute switches, and `wpctl set-mute` flips those. No extra code.

## Install

```
sudo apt install xbindkeys brightnessctl dunst libnotify-bin wireplumber xinput
git clone https://github.com/jaderfeijo/wmodern.git && cd wmodern/modules/thinkpad
./setup.sh --dry-run      # look first
./setup.sh                                    # install   (./setup.sh --uninstall removes it again)
```

`setup.sh` copies the scripts to `~/.local/bin`, adds the key bindings to `~/.xbindkeysrc` and a start-up block to
Window Maker's `autostart` file inside clearly marked blocks (nothing of yours is replaced), creates a dunst
config only if you have none, and starts everything right away. Use `--no-touchpad` to skip the touchpad part and
`--autostart-file FILE` if you start things from somewhere other than Window Maker's autostart.

## Things that cost me time

1. **Brightness needs the `video` group.** `brightnessctl` installs a udev rule that makes the backlight writable
   by group `video`. Check `ls -l /sys/class/backlight/*/brightness` (group `video`, mode `rw-rw-r--`) and
   `id` (you are in `video`); otherwise `sudo usermod -aG video $USER` and log in again.
2. **dunst ignored my pop-up settings.** With dunst 1.12, a drop-in file (`~/.config/dunst/dunstrc.d/*.conf`) was
   silently skipped because I had no `~/.config/dunst/dunstrc`: dunst then used `/etc/xdg/dunst/dunstrc`, and it
   only reads drop-ins next to the config file it uses. Put the settings in a real `~/.config/dunst/dunstrc`.
3. **`xbindkeys` started straight from the autostart file did not react.** After a reboot the process was running
   but the keys did nothing until it was restarted. I did not pin down why (most likely it starts before the session
   is ready), but restarting it a few seconds later fixed it, so the start-up block does that:
   `( sleep 3; pkill -x xbindkeys; exec xbindkeys ) &`.
4. **Start dunst yourself.** dunst ships a D-Bus service file that can start it on the first notification, but I
   did not want to depend on that without a desktop session, so the autostart block runs it explicitly.
5. **Use `wpctl`, not `amixer`.** With PipeWire the volume applications hear belongs to PipeWire's default sink;
   `amixer` changes the raw sound-card mixer underneath it, which is not the same control.

## Touchpad: tap to click

libinput leaves tapping **off** by default, so a ThinkPad touchpad only clicks when you press it down. `touchpad-tap.sh`
turns on tapping with `xinput`:

* one-finger tap is a left click, two fingers a right click, three fingers a middle click
* tap, then tap again and hold, to drag

It finds the touchpad by name (`xinput list`); set `TOUCHPAD="device name"` if yours is called something unusual. The
setting does not persist by itself, so `setup.sh` runs it from the autostart block a moment after login. (To make
it permanent for every X session instead, an `InputClass` section in `/etc/X11/xorg.conf.d/` with
`Option "Tapping" "on"` should do it; I did not test that route, and it needs root and a restart of X.)

## Not in this module

The power button menu and the screen lock are separate customisations; see the directory page linked at the top.

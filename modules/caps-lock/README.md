# caps-lock — normal Caps Lock

On Debian's Window Maker live images, **Caps Lock is the Compose key**: a startup script
(`/etc/X11/Xsession.d/99x14-composekey`, and a copy in your home, `~/GNUstep/AutoStart/Enabled/01_compose_key`,
both from the `wmlive-base` package) runs `setxkbmap -option compose:caps` at every login. A fix you apply by hand
(`setxkbmap -option ''`) lasts until the next login, which is why it keeps coming back.

This module makes the fix stick:

* installs `~/.local/bin/normal-caps-lock`, which removes **only** `compose:caps` from your XKB options (any other
  option you set stays) and does nothing when it is not set;
* runs it two seconds after Window Maker starts, from a marked block in the Window Maker `autostart` file, so it
  also wins over the system script, which cannot be edited without root and would be restored by package updates;
* switches off the copy in your home the way Debian intends (moves `01_compose_key` from `AutoStart/Enabled` to
  `AutoStart/Disabled`);
* applies the change to the running session right away (unless `--no-apply`).

```
./install.sh --dry-run     # look first
./install.sh               # install
./install.sh --uninstall   # remove the block, switch Debian's script back on
```

If you do want a Compose key, put it elsewhere, for example `setxkbmap -option compose:ralt`.

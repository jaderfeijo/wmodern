# no-welcome — no welcome window at login

Debian's Window Maker live packages (`wmlive-base`) start a "welcome" window at every login, from the script
`~/GNUstep/AutoStart/Enabled/99_welcome_message`. This module switches it off the way Debian intends: the script is
moved to `~/GNUstep/AutoStart/Disabled/`. Nothing is deleted; `--uninstall` moves it back.

```
./install.sh --dry-run
./install.sh
./install.sh --uninstall
```

It takes effect at the next login; a welcome window that is already open is not closed.

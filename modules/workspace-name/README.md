# workspace-name — flash the workspace name when switching

When you switch workspaces, Window Maker briefly shows the new workspace's name in the middle of the screen. This sets
`WorkspaceNameDisplayPosition = center` in `~/GNUstep/Defaults/WindowMaker` (Debian's default file has `none`). Other
values Window Maker accepts: `top`, `bottom`, `topleft`, `topright`, `bottomleft`, `bottomright`.

```
./install.sh --dry-run
./install.sh
./install.sh --uninstall    # WorkspaceNameDisplayPosition = none
```

A one-time backup is kept as `WindowMaker.bak-workspace-name`. Window Maker reads the file only at startup, so use
root menu > Window Maker > Restart (or log out and in) afterwards. Rename workspaces from the Workspaces menu or the
Clip to get something better than "Workspace 2".

# Window Maker: text scale and a clipboard that works in xterm

> Module `xterm` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install xterm`, or use it on its own as described below.

Two small things in `~/.Xresources` that a bare Window Maker session needs, plus the one trap that cost me an evening.
`install.sh` writes them as a clearly marked block and never touches the rest of your file.

## 1. Text scale: `Xft.dpi`

GTK and Qt programs size their text from `Xft.dpi`. Without a desktop environment nothing sets it, so you get the
toolkit default (usually 96). On a small, dense screen that can look too big; on a large one, too small.

```
Xft.dpi: 72        # text 25% smaller than 96;  120 would make it 25% larger
```

Use `./install.sh --dpi 72` (omit `--dpi` to leave the scale alone). Programs read it when they start, so restart
the ones that are already open.

## 2. xterm and the clipboard

By default xterm selections go to the **PRIMARY** selection only (select, then middle-click). A browser or a GTK app
pastes from the **CLIPBOARD** with Ctrl+V, so text copied in xterm never arrives and the other way round. The block
makes xterm:

| Setting | Effect |
|---|---|
| `selectToClipboard: true` | Whatever you select is also put on the CLIPBOARD. |
| `Ctrl+Shift+C` / `Ctrl+Shift+V` | Copy / paste through the CLIPBOARD, as in other terminals. |
| `Super+C` / `Super+V` | The same on the Super key, for macOS-style muscle memory (`--no-super` to skip). |
| `Shift+Insert` | Paste from the CLIPBOARD. |
| `disallowedWindowOps: 20,21,SetXprop` | Keeps xterm's dangerous window operations (reading the title and so on) off, while still letting programs *set* the clipboard with the **OSC 52** escape sequence. That is how tools such as Claude Code, tmux (`set-clipboard on`) and Neovim copy from inside a terminal, even over SSH. |

### The trap: a custom window class gets none of this

xterm looks its resources up under its **class name**. A plain `xterm` has class `XTerm`, so `XTerm*selectToClipboard`
works. If you start it with `-class Something` (a launcher that needs its own window class, so Window Maker's Dock
can tell it apart from your other terminals, for example), `XTerm*...` no longer applies: copy and paste quietly
stop working in that window and nothing says why. Repeat the settings under the new class:

```
./install.sh --class Claude
```

which writes the same block for `Claude*`. A Dock launcher that opens a program in its own xterm class:

```
xterm -name claude -class Claude -T Claude -e claude
```

## Install

```
git clone https://github.com/jaderfeijo/wmodern.git && cd wmodern/modules/xterm
./install.sh --dry-run                          # look first
./install.sh --dpi 72 --class Claude            # example
```

Window Maker does not read `~/.Xresources` by itself. Put this near the top of
`~/GNUstep/Library/WindowMaker/autostart` (the installer reminds you if it is missing):

```
xrdb -merge ~/.Xresources
```

`./install.sh` also runs `xrdb -merge` straight away when it can (`--no-apply` skips that). Open xterms keep their old
settings; new ones pick the new ones up. `./install.sh --uninstall` removes the block.

## Check

```
xrdb -query | grep -i -E 'dpi|selectToClipboard'
# in an xterm: select some text, then paste it into a browser with Ctrl+V
printf '\033]52;c;%s\a' "$(printf 'from OSC 52' | base64)"     # in xterm: then paste elsewhere with Ctrl+V
```

Tested on Debian 13 with xterm 398 and Window Maker 0.96.

# Window Maker: focus follows the mouse + instant auto-raise

> Module `focus` of [wmodern](https://github.com/jaderfeijo/wmodern): install it with `wmodern install focus`, or use it on its own as described below.

By default Window Maker is *click to focus*: you click a window to give it the keyboard focus and to raise it.
This switches it to **focus follows mouse with auto-raise**: rest the pointer on a window and it gets the focus and
comes to the front, with no click.

## The two settings

Both live in `~/GNUstep/Defaults/WindowMaker`:

```
FocusMode = sloppy;
RaiseDelay = 1;
```

| Key | Value | Meaning |
|---|---|---|
| `FocusMode` | `sloppy` | The window under the pointer gets the focus. "Sloppy" means the focus *stays* where it was when the pointer moves out onto the empty desktop, instead of being dropped. |
| `RaiseDelay` | `1` | Raise the window after the pointer has been on it for this many milliseconds. **`0` turns auto-raise off**, so `1` is the smallest value that is "instant". `250` is a comfortable value if instant feels jumpy. |

For the default behaviour again: `FocusMode = manual;` and `RaiseDelay = 0;`.

## Apply it

Either run the script in this module (it edits the file safely and keeps a one-time backup):

```
./focus-follows-mouse.sh                    # sloppy focus, raise after 1 ms
./focus-follows-mouse.sh --delay 250        # raise after 250 ms
./focus-follows-mouse.sh --click-to-focus   # back to the default
./focus-follows-mouse.sh --dry-run          # show what would change
```

or use **WPrefs** (the preferences tool): *Focus Mode* and the auto-raise delay, then Save. Or edit the two lines by
hand.

## The part that trips people up: restart Window Maker

Window Maker reads this file **only when it starts**. Editing it, or even saving from WPrefs, changes the file but
the running Window Maker keeps behaving the old way, so it looks as if nothing happened. Apply it with
**root menu > Window Maker > Restart** (your windows stay open) or by logging out and in.

## Caveats

* With focus following the pointer, typing goes to whatever window is under the mouse. If you type while the pointer
  drifts over a different window, the keys go there. A longer `RaiseDelay` softens this for overlapping windows.
* Keyboard-driven window switching still works; it just moves the focus, and the pointer is not warped.
* Tested on Debian 13 with Window Maker from the Debian package.

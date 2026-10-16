#!/bin/sh
# Turn on tap-to-click on the touchpad (libinput leaves it off by default):
#   one-finger tap = left click, two fingers = right click, three fingers = middle click,
#   and tap-then-hold to drag. Finds the touchpad by name; override with:  TOUCHPAD="device name" touchpad-tap.sh
dev=${TOUCHPAD:-$(xinput list --name-only | grep -i touchpad | head -n 1)}
[ -n "$dev" ] || { echo "no touchpad found (see: xinput list)" >&2; exit 1; }
xinput set-prop "$dev" "libinput Tapping Enabled" 1
xinput set-prop "$dev" "libinput Tapping Drag Enabled" 1
xinput set-prop "$dev" "libinput Tapping Button Mapping Enabled" 1 0     # "lrm": left, right, middle

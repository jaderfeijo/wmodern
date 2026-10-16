#!/bin/sh
# /etc/acpi/power-menu.sh : called by acpid (as root, outside any login session) when the power button is pressed.
# It only pokes the power-menu-listener of every logged-in user; the menu and its actions run inside the session,
# because systemctl suspend / reboot / poweroff are refused for processes that are not part of one.
for fifo in ${POWER_MENU_RUN_GLOB:-/run/user/*}/power-menu.fifo; do
  [ -p "$fifo" ] && timeout 1 sh -c 'echo > "$1"' sh "$fifo"
done
exit 0

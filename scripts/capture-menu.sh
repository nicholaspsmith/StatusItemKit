#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

# Capture a menu-bar app's open menu to a PNG, for README screenshots.
#
#   scripts/capture-menu.sh <ProcessName> <output.png> [item-index]
#
# Set MENU_ACTION=showmenu for an app whose left click does something else and
# whose menu lives on right-click.
#
# Drives the status item through the accessibility API rather than asking for a
# hand-aimed region: the bar reflows constantly, so a hardcoded rect goes stale
# the moment anything else appears. Needs Accessibility and Screen Recording for
# whichever process runs this (Terminal/iTerm).
set -euo pipefail

PROC="${1:?usage: capture-menu.sh <ProcessName> <output.png> [item-index]}"
OUT="${2:?usage: capture-menu.sh <ProcessName> <output.png> [item-index]}"
INDEX="${3:-1}"

pgrep -f "MacOS/$PROC" >/dev/null || { echo "$PROC is not running" >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"

# An app that sets NSApp.mainMenu (SoundChain does, for its Edit shortcuts) has
# its application menu as menu bar 1 and its status item as menu bar 2.
MB=$(osascript -e "tell application \"System Events\" to tell process \"$PROC\" to count menu bars" 2>/dev/null || echo 1)
[ "$MB" = 2 ] || MB=1

# The open menu's "x,y,w,h", or nothing while it's closed.
geometry() {
  osascript <<AS 2>/dev/null || true
tell application "System Events" to tell process "$PROC"
  set m to menu 1 of menu bar item $INDEX of menu bar $MB
  set p to position of m
  set s to size of m
  return ((item 1 of p) as text) & "," & ((item 2 of p) as text) & "," & ((item 1 of s) as text) & "," & ((item 2 of s) as text)
end tell
AS
}
is_rect() { [[ "$1" =~ ^-?[0-9]+,-?[0-9]+,[1-9][0-9]*,[1-9][0-9]*$ ]]; }

# A menu left open by a previous run would be toggled *shut* by our click. Close
# it first, but only if one is actually open: an Escape with no menu open goes
# to the frontmost app (a terminal running an agent reads it as "interrupt").
if is_rect "$(geometry)"; then
  osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true
  sleep 0.4
fi

if [ "${MENU_ACTION:-click}" = "showmenu" ]; then
  osascript >/dev/null <<AS
tell application "System Events" to tell process "$PROC"
  perform action "AXShowMenu" of menu bar item $INDEX of menu bar $MB
end tell
AS
else
  osascript >/dev/null <<AS
tell application "System Events" to tell process "$PROC"
  click menu bar item $INDEX of menu bar $MB
end tell
AS
fi

# The menu animates in; poll rather than guess a single sleep long enough for
# the slowest machine.
GEO=""
for _ in 1 2 3 4 5 6; do
  sleep 0.5
  GEO=$(geometry)
  is_rect "$GEO" && break
  GEO=""
done

if [ -z "$GEO" ]; then
  echo "could not read $PROC's menu geometry from menu bar $MB (is its icon hidden in System Settings ▸ Menu Bar, or under the notch?)" >&2
  exit 1
fi

IFS=, read -r X Y W H <<< "$GEO"
# Exact bounds: padding the rect pulls in desktop bleed around the rounded
# corners, which looks like a mistake in a README.
screencapture -x -R"$X,$Y,$W,$H" "$OUT"
osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true

echo "captured $PROC -> $OUT ($(sips -g pixelWidth -g pixelHeight "$OUT" 2>/dev/null | awk '/pixel/{printf "%s ", $2}'))"

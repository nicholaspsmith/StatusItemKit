#!/usr/bin/env bash
# Capture a menu-bar app's open menu to a PNG, for README screenshots.
#
#   scripts/capture-menu.sh <ProcessName> <output.png> [item-index]
#
# Set MENU_ACTION=showmenu for an app whose left click does something else and
# whose menu lives on right-click (Curtain toggles the curtain on left click).
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

# A menu left open by a previous run would be toggled *shut* by our click, and
# the geometry query then returns a degenerate rect. Always start closed.
osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true
sleep 0.4

if [ "${MENU_ACTION:-click}" = "showmenu" ]; then
  osascript >/dev/null <<AS
tell application "System Events" to tell process "$PROC"
  perform action "AXShowMenu" of menu bar item $INDEX of menu bar 1
end tell
AS
else
  osascript >/dev/null <<AS
tell application "System Events" to tell process "$PROC"
  click menu bar item $INDEX of menu bar 1
end tell
AS
fi

# The menu animates in; poll rather than guess a single sleep long enough for
# the slowest machine.
GEO=""
for _ in 1 2 3 4 5 6; do
  sleep 0.5
  GEO=$(osascript <<AS 2>/dev/null || true
tell application "System Events" to tell process "$PROC"
  set m to menu 1 of menu bar item $INDEX of menu bar 1
  set p to position of m
  set s to size of m
  return ((item 1 of p) as text) & "," & ((item 2 of p) as text) & "," & ((item 1 of s) as text) & "," & ((item 2 of s) as text)
end tell
AS
)
  [[ "$GEO" =~ ^-?[0-9]+,-?[0-9]+,[1-9][0-9]*,[1-9][0-9]*$ ]] && break
  GEO=""
done

if [ -z "$GEO" ]; then
  osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true
  echo "could not read $PROC's menu geometry (is the icon hidden behind Curtain?)" >&2
  exit 1
fi

IFS=, read -r X Y W H <<< "$GEO"
# Exact bounds: padding the rect pulls in desktop bleed around the rounded
# corners, which looks like a mistake in a README.
screencapture -x -R"$X,$Y,$W,$H" "$OUT"
osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true

echo "captured $PROC -> $OUT ($(sips -g pixelWidth -g pixelHeight "$OUT" 2>/dev/null | awk '/pixel/{printf "%s ", $2}'))"

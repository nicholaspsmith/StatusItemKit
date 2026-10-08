#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

# Tests for smoke-launch.sh, against tiny fixture apps compiled here (cc):
# one that stays up and writes a default, one that aborts at launch, one that
# is not a menu-bar app. Launches real (throwaway) processes on this Mac; each
# has its own bundle id, so nothing of yours is touched.
#
#   scripts/release/test-smoke-launch.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
smoke="$here/smoke-launch.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/smoke-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
fails=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# make_app <name> <bundle id> <LSUIElement true|false|none> <C source>
make_app() {
    local name="$1" bid="$2" agent="$3" src="$4" app="$work/$1.app"
    mkdir -p "$app/Contents/MacOS"
    printf '%s\n' "$src" > "$work/$name.c"
    cc -DPROOF="\"$work/$name.home\"" -o "$app/Contents/MacOS/$name" "$work/$name.c" -framework CoreFoundation || exit 2
    local ui=""
    [ "$agent" != none ] && ui="<key>LSUIElement</key><$agent/>"
    cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$name</string>
<key>CFBundleIdentifier</key><string>$bid</string>
<key>CFBundlePackageType</key><string>APPL</string>
$ui
</dict></plist>
PLIST
    codesign --force --sign - "$app" >/dev/null 2>&1
    echo "$app"
}

STAYS='#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(void) {
    CFPreferencesSetAppValue(CFSTR("SmokeTestWrote"), CFSTR("yes"), kCFPreferencesCurrentApplication);
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
    FILE *f = fopen(PROOF, "w");        /* the home it was given, for the test to read */
    if (f) { fprintf(f, "%s|%s", getenv("HOME"), getenv("CFFIXED_USER_HOME")); fclose(f); }
    sleep(120);
    return 0;
}'
DIES='#include <stdio.h>
#include <stdlib.h>
int main(void) { fprintf(stderr, "Fatal error: the fixture dies at launch\n"); abort(); }'

stays="$(make_app SmokeStays com.nicholaspsmith.smoketest.stays true "$STAYS")"
dies="$(make_app SmokeDies com.nicholaspsmith.smoketest.dies true "$DIES")"
windowed="$(make_app SmokeWindowed com.nicholaspsmith.smoketest.windowed none "$STAYS")"

# 1. An app that stays up passes, and is gone afterwards.
defaults delete com.nicholaspsmith.smoketest.stays >/dev/null 2>&1
defaults write com.nicholaspsmith.smoketest.stays Before kept
out="$("$smoke" "$stays" 2 2>&1)"; rc=$?
[ $rc -eq 0 ] && pass "a live app passes" || fail "a live app passes (rc $rc): $out"
echo "$out" | grep -q "stayed up" && pass "says it stayed up" || fail "says it stayed up: $out"
ps -axww -o args= | grep -qF "$stays/Contents/MacOS/" && fail "the app is stopped afterwards" || pass "the app is stopped afterwards"

# 2. ...and what it wrote to its defaults is put back.
[ "$(defaults read com.nicholaspsmith.smoketest.stays Before 2>/dev/null)" = kept ] \
    && pass "existing defaults survive" || fail "existing defaults survive"
defaults read com.nicholaspsmith.smoketest.stays SmokeTestWrote >/dev/null 2>&1 \
    && fail "the launch's own write is undone" || pass "the launch's own write is undone"
defaults delete com.nicholaspsmith.smoketest.stays >/dev/null 2>&1

# 3. ...and it ran with a scratch home.
proof="$(cat "$work/SmokeStays.home" 2>/dev/null)"
case "$proof" in
    "$HOME|"*|*"|$HOME"|"|"*|"") fail "runs with a scratch HOME and CFFIXED_USER_HOME: '$proof'" ;;
    *) [ "${proof%%|*}" = "${proof#*|}" ] && [ ! -e "${proof%%|*}" ] \
           && pass "runs with a scratch HOME and CFFIXED_USER_HOME, removed afterwards" \
           || fail "runs with a scratch HOME and CFFIXED_USER_HOME: '$proof'" ;;
esac

# 4. An app that dies at launch fails, and says why.
out="$("$smoke" "$dies" 2 2>&1)"; rc=$?
[ $rc -eq 1 ] && pass "a crashing app fails" || fail "a crashing app fails (rc $rc): $out"
echo "$out" | grep -q "SmokeDies quit" && pass "says it quit" || fail "says it quit: $out"
echo "$out" | grep -q "Fatal error: the fixture dies at launch" && pass "shows the app's output" || fail "shows the app's output: $out"
echo "$out" | grep -q "SIGABRT\|abort" && pass "shows the crash" || fail "shows the crash: $out"

# 5. An app with windows is not launched.
out="$("$smoke" "$windowed" 2 2>&1)"; rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q "not launched" && pass "a windowed app is skipped" || fail "a windowed app is skipped (rc $rc): $out"

# 6. Bad input is a usage error.
"$smoke" "$work/nope.app" >/dev/null 2>&1; rc=$?
[ $rc -eq 2 ] && pass "a missing bundle is exit 2" || fail "a missing bundle is exit 2 (rc $rc)"

for a in "$stays" "$dies" "$windowed"; do
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$a" >/dev/null 2>&1
done
[ $fails -eq 0 ] && echo "all passed" || echo "$fails failed"
[ $fails -eq 0 ]

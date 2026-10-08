#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

# Does a built menu-bar app stay up after it launches? Menu Crane 1.3.0 passed
# every test and crashed at launch; this is the check that would have caught
# it. The release workflow's pull-request check runs it on the freshly built
# app (on a GitHub macOS runner); parity runs its own copy of the same check
# on the M5 before it installs anything.
#
#   scripts/release/smoke-launch.sh <App.app> [seconds]       default 5
#
# Exit 0: it was still running <seconds> after it appeared (or it was not
# launched because it has no LSUIElement: an app with windows would come to
# the front). Exit 1: it quit, or never started within 30 s; the crash
# report's exception and top frames and the app's own output are printed.
# Exit 2: usage.
#
# Safe beside an installed copy of the same app: `open -n` starts a new,
# hidden, background instance; HOME and CFFIXED_USER_HOME are an empty scratch
# dir; the app's defaults domain (which cfprefsd does not redirect) is put
# back exactly as it was if the launch changed it; the copy is stopped
# (SIGTERM, then SIGKILL) and LaunchServices forgets it.
set -uo pipefail

START_TIMEOUT=30
STOP_TIMEOUT=5
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
REPORTS="$HOME/Library/Logs/DiagnosticReports"

app="${1:-}"
secs="${2:-5}"
if [ -z "$app" ] || [ ! -f "$app/Contents/Info.plist" ] || ! [[ "$secs" =~ ^[0-9]+$ ]]; then
    echo "usage: smoke-launch.sh <App.app> [seconds]" >&2
    exit 2
fi
app="$(cd "$app" && pwd -P)"     # LaunchServices runs the real path, symlinks resolved
plist="$app/Contents/Info.plist"
key() { /usr/bin/plutil -extract "$1" raw -o - "$plist" 2>/dev/null; }
exe_name="$(key CFBundleExecutable)"
bid="$(key CFBundleIdentifier)"
label="$(basename "$app" .app)"
exe="$app/Contents/MacOS/$exe_name"
if [ -z "$exe_name" ] || [ ! -x "$exe" ]; then
    echo "✗ $label has no executable at Contents/MacOS/${exe_name:-?}"
    exit 1
fi
case "$(key LSUIElement | tr '[:upper:]' '[:lower:]')" in
    true|1|yes) ;;
    *) echo "• $label not launched: it is not a menu-bar app (no LSUIElement)"; exit 0 ;;
esac

work="$(mktemp -d "${TMPDIR:-/tmp}/smoke-launch.XXXXXX")"
mkdir -p "$work/home"
touch "$work/started"
pids() {
    ps -axww -o pid=,args= | awk -v exe="$exe" '{
        line = $0; sub(/^ *[0-9]+ +/, "", line)
        if (line == exe || index(line, exe " ") == 1) print $1 }'
}
[ -n "$bid" ] && defaults export "$bid" "$work/before.plist" 2>/dev/null

/usr/bin/open -n -W -g -j -F \
    --env "HOME=$work/home" --env "CFFIXED_USER_HOME=$work/home" \
    --stdout "$work/app.log" --stderr "$work/app.log" "$app" >"$work/open.log" 2>&1 &
opener=$!

# Poll five times a second: up for secs*5 polls in a row (ps takes time too,
# so the window only ever runs long).
verdict="" ticks=0 waited=0
while :; do
    if [ -n "$(pids)" ]; then
        ticks=$((ticks + 1))
        [ "$ticks" -ge $((secs * 5)) ] && break
    elif [ "$ticks" -gt 0 ]; then
        verdict="quit $((ticks / 5)) s after launch"; break
    elif ! kill -0 "$opener" 2>/dev/null; then
        verdict="quit at launch"; break
    else
        waited=$((waited + 1))
        [ "$waited" -ge $((START_TIMEOUT * 5)) ] && { verdict="did not start within $START_TIMEOUT s"; break; }
    fi
    sleep 0.2
done

# Stop it, then put back what it changed.
left="$(pids)"
[ -n "$left" ] && kill -TERM $left 2>/dev/null
for _ in $(seq $((STOP_TIMEOUT * 5))); do
    left="$(pids)"; [ -z "$left" ] && break; sleep 0.2
done
[ -n "$left" ] && kill -KILL $left 2>/dev/null
for _ in $(seq $((STOP_TIMEOUT * 5))); do kill -0 "$opener" 2>/dev/null || break; sleep 0.2; done
kill -KILL "$opener" 2>/dev/null
wait "$opener" 2>/dev/null
if [ -n "$bid" ] && [ -f "$work/before.plist" ] && defaults export "$bid" "$work/after.plist" 2>/dev/null \
    && ! cmp -s "$work/before.plist" "$work/after.plist"; then
    defaults delete "$bid" >/dev/null 2>&1
    defaults import "$bid" "$work/before.plist"
    echo "• put back the $bid defaults the launch changed"
fi
"$LSREGISTER" -u "$app" >/dev/null 2>&1

if [ -z "$verdict" ]; then
    echo "✓ $label stayed up for $secs s"
    rm -rf "$work"
    exit 0
fi

echo "✗ $label $verdict"
if [ "${verdict#quit}" != "$verdict" ]; then
    report=""
    for _ in $(seq 25); do
        report="$(find "$REPORTS" -maxdepth 1 -name "$exe_name-*.ips" -newer "$work/started" 2>/dev/null | sort | tail -1)"
        [ -n "$report" ] && break
        sleep 0.2
    done
    if [ -n "$report" ]; then
        tail -n +2 "$report" > "$work/report.json"
        x() { /usr/bin/plutil -extract "$1" raw -o - "$work/report.json" 2>/dev/null; }
        t="$(x faultingThread)"; t="${t:-0}"
        echo "  crash: $(x exception.type) ($(x exception.signal)), $report"
        for i in 0 1 2 3 4 5; do
            sym="$(x "threads.$t.frames.$i.symbol")" || break
            src="$(x "threads.$t.frames.$i.sourceFile")"; line="$(x "threads.$t.frames.$i.sourceLine")"
            [ -n "$src" ] && [ "${src#/<}" = "$src" ] && sym="$sym ($(basename "$src"):$line)"
            echo "    $sym"
        done
    elif [ "${CI:-}" = true ] && command -v lldb >/dev/null; then
        # CI runners write no crash reports: launch it once more under lldb
        # for the crashing thread's backtrace. Only on CI: on a Mac, attaching
        # a debugger asks for Developer Tools access.
        echo "  no crash report; the crash under lldb:"
        mkdir -p "$work/home2"
        perl -e 'alarm shift; exec @ARGV' $((secs + 30)) \
            lldb --batch -o "process launch --environment HOME=$work/home2 --environment CFFIXED_USER_HOME=$work/home2" \
                 -k "thread backtrace" -k "kill" -k "quit" -- "$exe" 2>&1 \
            | grep -E "stop reason|^ *(\* )?frame #[0-9]" | head -8 | sed 's/^/    /'
        "$LSREGISTER" -u "$app" >/dev/null 2>&1
    else
        echo "  no crash report"
    fi
fi
if [ -s "$work/app.log" ]; then
    echo "  output:"; tail -10 "$work/app.log" | sed 's/^/    /'
fi
if [ -s "$work/open.log" ]; then
    echo "  open:"; tail -5 "$work/open.log" | sed 's/^/    /'
fi
rm -rf "$work"
exit 1

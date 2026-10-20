#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

# Hand a Menumon app's install over to parity, which owns ~/Applications on
# the Macs it syncs. A local build in <repo>/build is a second copy with the
# same bundle id: LaunchServices can launch it in place of parity's (Menu Crane
# ran a 3-week-old build that way, 2026-10-20), and once ~/Applications links
# to it parity treats the app as hand-installed and stops syncing it.
#
#   scripts/parity/handoff.sh <repo-dir>      what each app's install.sh runs first
#
# Asks the coordinator (parity-ctl on the M5: locally there, over the
# parity_ctl SSH key elsewhere) to install or sync every app of the repo on
# this Mac, then waits for that cycle and reports how it went. Parity builds
# committed work only, so it warns about uncommitted changes and unpushed
# commits on main first.
#
# Exit status:
#   0   parity installed or synced the app(s)
#   10  parity doesn't manage this repo (or PARITY=off): build locally
#   1   parity manages it but the hand-off failed; nothing local was built
#
# PARITY=off ./install.sh skips the hand-off and builds locally, leaving a
# copy parity won't sync. PARITY_WAIT=<seconds> caps the wait (default 900;
# 0 = just ask and return).
set -euo pipefail

REPO_DIR="$(cd "${1:?usage: handoff.sh <repo-dir>}" && pwd)"
REPO="$(basename "$REPO_DIR")"
WAIT="${PARITY_WAIT:-900}"
LOCAL_CTL="$HOME/.local/bin/parity-ctl"
SECRET="$HOME/Library/Application Support/Parity/secret"

if [ "${PARITY:-}" = off ]; then
    echo "PARITY=off: building locally; parity won't sync this copy" >&2
    exit 10
fi

# The M5 runs the coordinator; anywhere else reaches it the way Parity.app does.
if [ -x "$LOCAL_CTL" ] && [ -f "$SECRET" ]; then
    CTL=("$LOCAL_CTL")
else
    ROUTE="$(defaults read com.nicholaspsmith.Parity PreferredRoute 2>/dev/null || echo macbook-pro-m5.local)"
    # The key's forced command splits on the first two spaces, so the JSON goes
    # unquoted as the last word.
    CTL=(ssh -i "$HOME/.ssh/parity_ctl" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=5
         -o StrictHostKeyChecking=accept-new "$ROUTE" parity-ctl)
fi
ctl() { "${CTL[@]}" "$@"; }
MACHINE="$(scutil --get LocalHostName)"

# Is any link in ~/Applications already parity's for this repo? Then an
# unreachable coordinator is a failure, not a reason to build locally.
parity_linked() {
    local f
    for f in "$HOME/Applications"/*.app; do
        [ -L "$f" ] && case "$(readlink "$f")" in "$HOME/.parity/builds/$REPO/"*) return 0 ;; esac
    done
    return 1
}

if ! STATE="$(ctl state 2>/dev/null)"; then
    if parity_linked; then
        echo "parity: coordinator unreachable; nothing installed." >&2
        echo "  Retry when the M5 is reachable, or PARITY=off $0 to build a local copy parity won't sync." >&2
        exit 1
    fi
    exit 10
fi

# Apps of this repo parity knows, and which of them this Mac lacks.
read_state() {  # "have|lack<TAB>key" per app of this repo parity syncs
    /usr/bin/python3 -c '
import json, sys
repo, machine = sys.argv[1:3]
d = json.loads(sys.stdin.read())
if repo in (d.get("settings") or {}).get("excluded", []):
    sys.exit(0)
for k, v in sorted((d.get("apps") or {}).items()):
    if ":" not in k or k.split(":", 1)[0] != repo:
        continue
    m = (v.get("machines") or {}).get(machine) or {}
    print(("have" if m else "lack") + "\t" + k)
' "$REPO" "$MACHINE"
}

KEYS="$(read_state <<<"$STATE")"
[ -n "$KEYS" ] || exit 10

# Parity merges committed work: say what this run won't include.
if [ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]; then
    echo "parity: uncommitted changes in $REPO aren't built; commit them (on a feature branch) first" >&2
fi
BRANCH="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || true)"
case "$BRANCH" in
    main|master)
        AHEAD="$(git -C "$REPO_DIR" rev-list --count "origin/$BRANCH..HEAD" 2>/dev/null || echo 0)"
        [ "$AHEAD" = 0 ] || echo "parity: $AHEAD commit(s) on $BRANCH aren't pushed; parity never pushes $BRANCH, so they aren't built" >&2 ;;
esac

while IFS=$'\t' read -r have key; do
    if [ "$have" = lack ]; then
        echo "parity: asking to install ${key#*:} on $MACHINE"
        OUT="$(ctl install "{\"key\":\"$key\",\"machine\":\"$MACHINE\"}")" || { echo "parity: install refused: $OUT" >&2; exit 1; }
    fi
done <<<"$KEYS"
OUT="$(ctl sync "{\"repo\":\"$REPO\"}")" || { echo "parity: sync refused: $OUT" >&2; exit 1; }
echo "parity: sync of $REPO requested"
[ "$WAIT" -gt 0 ] || exit 0

# Wait for the cycle: an app is done once it has left "in sync" and come back,
# got a new build here, or sat still for a minute (nothing to do); stop on failure.
exec /usr/bin/python3 -c '
import json, os, subprocess, sys, time
repo, machine, wait, before, ctl = sys.argv[1], sys.argv[2], int(sys.argv[3]), json.loads(sys.argv[4]), sys.argv[5:]
FAILED = ("failed", "conflict", "missing-input")

def apps(d):
    return {k: v for k, v in (d.get("apps") or {}).items() if ":" in k and k.split(":", 1)[0] == repo}

def build(v):
    return ((v.get("machines") or {}).get(machine) or {}).get("build")

old = {k: build(v) for k, v in apps(before).items()}
last = {k: v.get("state") for k, v in apps(before).items()}
before_state = dict(last)
busy, start = set(), time.monotonic()
while True:
    time.sleep(5)
    try:
        now = apps(json.loads(subprocess.run(ctl + ["state"], capture_output=True, text=True, timeout=20).stdout))
    except Exception:
        continue
    pending = False
    for k, v in sorted(now.items()):
        name, state, detail = k.split(":", 1)[1], v.get("state") or "", " ".join((v.get("detail") or "").split())
        if state != last.get(k):
            print(f"parity: {name}: {state}" + (f" ({detail})" if detail else ""), flush=True)
            last[k] = state
        # a failure left over from an earlier cycle counts only once this one had its chance
        if state in FAILED and (k in busy or before_state.get(k) not in FAILED or time.monotonic() - start >= 60):
            print(f"parity: {name} was not installed; what is installed is unchanged", file=sys.stderr)
            sys.exit(1)
        if state in FAILED:
            pending = True
        elif state != "in sync":
            busy.add(k); pending = True
        elif k not in busy and build(v) == old.get(k) and time.monotonic() - start < 60:
            pending = True
    if not pending:
        for k, v in sorted(now.items()):
            name, b = k.split(":", 1)[1], build(v) or "?"
            print(f"parity: {name} on {machine} is build {b}")
            # parity relaunches only what was running; install.sh always opened the app
            app = os.path.expanduser("~/Applications/" + name)
            if os.path.lexists(app) and subprocess.run(["pgrep", "-f", "/" + name + "/Contents/MacOS/"],
                                                       capture_output=True).returncode != 0:
                subprocess.run(["/usr/bin/open", app])
        sys.exit(0)
    if time.monotonic() - start >= wait:
        print(f"parity: still working after {wait}s; Polly shows how it ends")
        sys.exit(0)
' "$REPO" "$MACHINE" "$WAIT" "$STATE" "${CTL[@]}"

#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

# Put a Menubarn app (or StatusItemKit) under the release rule: every push is a release.
#
#   scripts/release/adopt.sh [repo...]     default: every Menubarn app in ~/Code, and StatusItemKit
#
# For each repo, idempotently:
#   - CHANGELOG.md, backfilled from its vX.Y.Z tags if it has none (commits
#     after the last tag go under [Unreleased]);
#   - .github/workflows/release.yml, which calls this repo's reusable
#     menubarn-release.yml to tag and publish each push to main;
#   - core.hooksPath (local to that repo) -> scripts/release/hooks, for the
#     pre-push check. Local git config is per machine: re-run this after
#     cloning an app somewhere new.
# Nothing is committed; commit the first two with [no release] in the message.
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
APPS=(menubar-barn keylight-menubar vpn-dns-menubar MacOS_Process_Monitor battery-time-menubar
      claude-usage-menubar MacRecorder apollo-monitor-menubar media-tracking-killer-menubar
      download-recycler-menubar monitor-lizard-menubar home-assistant-menubar StatusItemKit)
if [ $# -eq 0 ]; then
    set -- "${APPS[@]/#/$HOME/Code/}"
fi

backfill() {
    local tags prev="" date
    echo "# Changelog"
    echo
    echo "Every push to \`main\` is a release. Add a \`## [X.Y.Z] - YYYY-MM-DD\` section at"
    echo "the top (minor for features, patch for fixes); GitHub tags it and publishes"
    echo "the section as the release notes. Versions follow [Semantic"
    echo "Versioning](https://semver.org/)."
    tags=($(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' | sort -rV))
    if [ ${#tags[@]} -gt 0 ] && [ -n "$(git log --no-merges --format=%h "${tags[0]}..HEAD")" ]; then
        echo; echo "## [Unreleased]"; echo
        git log --no-merges --format='- %s' "${tags[0]}..HEAD"
    fi
    for i in "${!tags[@]}"; do
        prev="${tags[$((i + 1))]:-}"
        date="$(git log -1 --format=%cs "${tags[$i]}")"
        echo; echo "## [${tags[$i]#v}] - $date"; echo
        if [ -n "$prev" ]; then git log --no-merges --format='- %s' "$prev..${tags[$i]}"
        else git log --no-merges --format='- %s' "${tags[$i]}"; fi
    done
}

for repo in "$@"; do
    [ -d "$repo/.git" ] || { echo "skip $repo: not a git checkout" >&2; continue; }
    (
        cd "$repo"
        if [ ! -f CHANGELOG.md ]; then backfill > CHANGELOG.md; echo "$repo: CHANGELOG.md backfilled"; fi
        mkdir -p .github/workflows
        cat > .github/workflows/release.yml <<'YML'
# Every push to main is a release: tags the version at the top of CHANGELOG.md
# and publishes it. The rule and the tagging live in StatusItemKit
# (scripts/release/, .github/workflows/menubarn-release.yml).
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write

concurrency: release

jobs:
  release:
    uses: nicholaspsmith/StatusItemKit/.github/workflows/menubarn-release.yml@main
YML
        git config --local core.hooksPath "$KIT/hooks"
        echo "$repo: workflow written, pre-push hook on"
    )
done

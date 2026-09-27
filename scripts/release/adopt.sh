#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

# Put a Menubarn app (or StatusItemKit, HotkeyKit) under the release rule:
# every push is a release.
#
#   scripts/release/adopt.sh [repo...]     default: every Menubarn app in ~/Code,
#                                          StatusItemKit and HotkeyKit
#   scripts/release/adopt.sh --hooks-only  just re-arm the pre-push hook in every
#                                          one of those that is cloned here (what
#                                          each app's install.sh and the macOS
#                                          setup suite run; changes no files)
#
# For each repo, idempotently:
#   - CHANGELOG.md, backfilled from its vX.Y.Z tags if it has none (commits
#     after the last tag go under [Unreleased]);
#   - .github/workflows/release.yml, which calls this repo's reusable
#     menubarn-release.yml to tag and publish each push to main;
#   - core.hooksPath (local to that repo) -> scripts/release/hooks, for the
#     pre-push check;
#   - branch protection on GitHub: main needs "release / check" to merge a PR.
# Local git config is per machine: re-run --hooks-only after cloning an app
# somewhere new.
# Nothing is committed; commit the first two with [no release] in the message.
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
APPS=(menubar-barn keylight-menubar vpn-dns-menubar MacOS_Process_Monitor battery-time-menubar
      claude-usage-menubar MacRecorder apollo-monitor-menubar media-tracking-killer-menubar
      download-recycler-menubar monitor-lizard-menubar home-assistant-menubar soundchain-menubar StatusItemKit HotkeyKit)
CODE="$(cd "$KIT/../../.." && pwd)"   # the directory StatusItemKit is cloned in
armed=()

if [ "${1:-}" = "--hooks-only" ]; then
    for app in "${APPS[@]}"; do
        [ -d "$CODE/$app/.git" ] || continue
        git -C "$CODE/$app" config --local core.hooksPath "$KIT/hooks"
        armed+=("$app")
    done
    echo "Menubarn release hook armed in ${#armed[@]} repos: ${armed[*]}"
    exit 0
fi
if [ $# -eq 0 ]; then
    set -- "${APPS[@]/#/$CODE/}"
fi

backfill() {
    local tags prev="" date
    echo "# Changelog"
    echo
    cat <<'HEAD'
Every push to `main` is a release. Before pushing, add a `## [X.Y.Z] - YYYY-MM-DD`
section at the top with `- ` entries (minor for features, patch for fixes); if an
`## [Unreleased]` section is waiting, turn it into that section. GitHub tags it
and publishes the section as the release notes; a push or pull request
without one is refused (`[no release]` in the tip commit is the only exception).
Versions follow [Semantic Versioning](https://semver.org/). The full rule:
[StatusItemKit — Releases](https://github.com/nicholaspsmith/StatusItemKit#releases-every-push-is-one).
HEAD
    tags=($(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' | sort -rV))
    if [ ${#tags[@]} -eq 0 ]; then
        echo; echo "## [Unreleased]"; echo
        git log --no-merges --format='- %s'
    elif [ -n "$(git log --no-merges --format=%h "${tags[0]}..HEAD")" ]; then
        echo; echo "## [Unreleased]"; echo
        git log --no-merges --format='- %s' "${tags[0]}..HEAD"
    fi
    for i in ${tags[@]+"${!tags[@]}"}; do
        prev="${tags[$((i + 1))]:-}"
        date="$(git log -1 --format=%cs "${tags[$i]}")"
        echo; echo "## [${tags[$i]#v}] - $date"; echo
        if [ -n "$prev" ]; then git log --no-merges --format='- %s' "$prev..${tags[$i]}"
        else git log --no-merges --format='- %s' "${tags[$i]}"; fi
    done
}

# Branch protection on main: a PR cannot merge until "release / check" (the
# workflow's pull_request job) passes, i.e. until it carries a new version or
# its tip says [no release]. Admins are not forced (enforce_admins false) so a
# direct push to main still works — that path is guarded by the pre-push hook
# and the push job — but merging a failing PR then needs `gh pr merge --admin`,
# which is never used for this.
protect() {
    local slug
    slug="$(git -C "$1" remote get-url origin | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"
    if ! command -v gh >/dev/null; then echo "$1: gh missing — branch protection not set" >&2; return; fi
    gh api -X PUT "repos/$slug/branches/main/protection" --silent --input - <<'JSON' \
        && echo "$1: main requires \"release / check\" to merge" \
        || echo "$1: could not set branch protection" >&2
{"required_status_checks": {"strict": false, "checks": [{"context": "release / check"}]},
 "enforce_admins": false, "required_pull_request_reviews": null, "restrictions": null}
JSON
}

for repo in "$@"; do
    [ -d "$repo/.git" ] || { echo "skip $repo: not a git checkout" >&2; continue; }
    (
        cd "$repo"
        if [ ! -f CHANGELOG.md ]; then backfill > CHANGELOG.md; echo "$repo: CHANGELOG.md backfilled"; fi
        mkdir -p .github/workflows
        cat > .github/workflows/release.yml <<'YML'
# Every push to main is a release: tags the version at the top of CHANGELOG.md
# and publishes it as "vX.Y.Z". Pull requests fail unless they carry that new
# version; a release made by hand is retitled to its tag. The rule and the
# tagging live in StatusItemKit (scripts/release/,
# .github/workflows/menubarn-release.yml).
name: Release

on:
  push:
    branches: [main]
  pull_request:
  release:
    types: [published]

permissions:
  contents: write

jobs:
  release:
    uses: nicholaspsmith/StatusItemKit/.github/workflows/menubarn-release.yml@main
YML
        git config --local core.hooksPath "$KIT/hooks"
        echo "$repo: workflow written, pre-push hook on"
        protect "$repo"
    )
done

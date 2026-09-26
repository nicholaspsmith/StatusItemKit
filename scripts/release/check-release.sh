#!/usr/bin/env bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

# Does a commit carry a new release? The one rule for every Menubarn app,
# shared by the local pre-push hook and the GitHub release workflow:
#
#   Every push is a release. The commit's CHANGELOG.md must open (below any
#   "## [Unreleased]") with a "## [X.Y.Z] - YYYY-MM-DD" section that has at
#   least one entry, and X.Y.Z must be newer than every vX.Y.Z tag and not
#   tagged yet.
#
#   scripts/release/check-release.sh <commit>          new release required
#   scripts/release/check-release.sh <commit> --tag vX.Y.Z
#                                                       the tag's own section
#
# Prints the version on success (so a caller can tag it); explains and exits 1
# otherwise. Run inside the app's repository, with its tags fetched.
set -euo pipefail

COMMIT="${1:?usage: check-release.sh <commit> [--tag vX.Y.Z]}"
TAG=""
[ "${2:-}" = "--tag" ] && TAG="${3:?--tag needs vX.Y.Z}"

fail() {
    {
        echo "✗ Menubarn release rule: $1"
        echo "  Every push to a Menubarn app is a release. Add a section to the top of"
        echo "  CHANGELOG.md, e.g.:"
        echo "      ## [1.3.0] - $(date +%F)"
        echo "      ### Changed"
        echo "      - What changed, for someone who uses the app."
        echo "  Minor for features, patch for fixes. GitHub tags it when it reaches main."
    } >&2
    exit 1
}

CHANGELOG="$(git show "$COMMIT:CHANGELOG.md" 2>/dev/null)" || fail "no CHANGELOG.md in $(git rev-parse --short "$COMMIT")."

# The body of the section headed [VERSION]: every line up to the next "## ".
section() {
    awk -v v="$1" '
        /^## \[/ { inside = (index($0, "## [" v "]") == 1); next }
        inside' <<<"$CHANGELOG"
}

if [ -n "$TAG" ]; then
    VERSION="${TAG#v}"
    grep -q "^## \[$VERSION\]" <<<"$CHANGELOG" || fail "tag $TAG has no \"## [$VERSION]\" section in CHANGELOG.md."
    grep -q '^- ' <<<"$(section "$VERSION")" || fail "the [$VERSION] section in CHANGELOG.md has no entries."
    echo "$VERSION"
    exit 0
fi

VERSION="$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' <<<"$CHANGELOG" | tr -d '#[] ')" \
    || fail "CHANGELOG.md has no \"## [X.Y.Z] - date\" section."
grep -qE "^## \[$VERSION\] - [0-9]{4}-[0-9]{2}-[0-9]{2}" <<<"$CHANGELOG" \
    || fail "the [$VERSION] heading needs a date: \"## [$VERSION] - YYYY-MM-DD\"."
grep -q '^- ' <<<"$(section "$VERSION")" || fail "the [$VERSION] section in CHANGELOG.md has no entries."

if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
    fail "v$VERSION is already released — this push needs a new version above it."
fi
LATEST="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' | sed 's/^v//' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)"
if [ -n "$LATEST" ] && [ "$(printf '%s\n%s\n' "$LATEST" "$VERSION" | sort -V | tail -1)" != "$VERSION" ]; then
    fail "[$VERSION] is older than the latest release, v$LATEST."
fi
echo "$VERSION"

#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

# Wrap a SwiftPM executable product into a signed .app bundle.
# Run from the consuming package's root (it reads ./Resources/Info.plist and
# writes ./build/<DisplayName>.app). The codesign step is REQUIRED:
# UNUserNotificationCenter silently drops requests from unsigned bundles.
#
# Signing identity, in order of preference:
#   1. $STATUSITEMKIT_SIGN_ID            (explicit override)
#   2. the "StatusItemKit Local Signing" self-signed identity, if installed
#      (scripts/setup-signing.sh) — gives a STABLE Designated Requirement so
#      TCC grants (Accessibility, etc.) survive rebuilds
#   3. ad-hoc ("-")                      — works, but every rebuild changes the
#      CDHash and invalidates TCC grants (must re-approve after each rebuild)
#
# Version: stamped from the consuming repo's nearest vX.Y.Z tag (required);
# see "Stamp the version" below and AppVersion.swift.
#
# Usage: scripts/make-app.sh <ProductName> [<BundleDisplayName>]
set -euo pipefail

PRODUCT="${1:?usage: make-app.sh <ProductName> [<BundleDisplayName>]}"
DISPLAY="${2:-$PRODUCT}"
APP_BUNDLE="build/${DISPLAY}.app"

echo "==> swift build -c release"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/${PRODUCT}"
if [ ! -x "$BIN" ]; then
    echo "Build did not produce executable at $BIN" >&2
    exit 1
fi

echo "==> Assembling ${APP_BUNDLE}"
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "$BIN" "${APP_BUNDLE}/Contents/MacOS/${PRODUCT}"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
# Optional extra bundle resources (icons, helper scripts) live in Resources/bundle/.
if [ -d Resources/bundle ]; then
    cp -R Resources/bundle/. "${APP_BUNDLE}/Contents/Resources/"
fi

# Stamp the version. The nearest vX.Y.Z tag is the release and the commit is
# the build, so every bundle says exactly what it was built from; whatever
# Resources/Info.plist says is overwritten. No semver tag, no build.
SEMVER_RE='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$'
if ! DESCRIBE="$(git describe --tags --long --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null)"; then
    echo "No vX.Y.Z tag reachable from HEAD. Tag a release first, e.g.:" >&2
    echo "    git tag -a v1.0.0 -m 1.0.0 && git push origin v1.0.0" >&2
    exit 1
fi
TAG="${DESCRIBE%-*-*}"                  # v1.2.0 (prerelease hyphens survive)
DISTANCE="${DESCRIBE#"$TAG"-}"
HASH="${DISTANCE#*-g}"
DISTANCE="${DISTANCE%%-*}"
if [[ ! "$TAG" =~ $SEMVER_RE ]]; then
    echo "Nearest tag '$TAG' is not semver (vMAJOR.MINOR.PATCH[-prerelease])." >&2
    exit 1
fi
VERSION="${TAG#v}"
DIRTY=""
git diff --quiet HEAD -- || DIRTY=".dirty"
if [ "$DISTANCE" != 0 ] || [ -n "$DIRTY" ]; then
    VERSION="${VERSION}+${DISTANCE}.g${HASH}${DIRTY}"
fi
PLIST="${APP_BUNDLE}/Contents/Info.plist"
# Finder and LaunchServices want bare MAJOR.MINOR.PATCH here; the full
# semver, prerelease and build metadata included, goes in StatusItemKitVersion.
plutil -replace CFBundleShortVersionString -string "$(echo "${TAG#v}" | cut -d- -f1)" "$PLIST"
plutil -replace CFBundleVersion -string "${HASH}${DIRTY}" "$PLIST"
plutil -replace StatusItemKitVersion -string "$VERSION" "$PLIST"
echo "==> Version ${VERSION}"

# Resolve the signing identity (see header). Prefer a stable self-signed
# identity so TCC grants survive rebuilds; fall back to ad-hoc.
SIGN_ID="${STATUSITEMKIT_SIGN_ID:-}"
if [ -z "$SIGN_ID" ]; then
    SIGN_ID="$(security find-identity -p codesigning 2>/dev/null \
        | awk '/StatusItemKit Local Signing/ {print $2; exit}')" || true
fi
SIGN_ID="${SIGN_ID:--}"

codesign --force --sign "$SIGN_ID" "${APP_BUNDLE}" >/dev/null
if [ "$SIGN_ID" = "-" ]; then
    echo "==> Ad-hoc signed (run scripts/setup-signing.sh for a stable identity"
    echo "    so TCC/Accessibility grants survive rebuilds)"
else
    echo "==> Signed with stable identity ${SIGN_ID}"
fi

echo "==> Built ${APP_BUNDLE}"
echo "Launch with: open ${APP_BUNDLE}"

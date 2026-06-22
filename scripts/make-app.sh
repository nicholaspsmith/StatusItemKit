#!/bin/bash
# Wrap a SwiftPM executable product into an ad-hoc-signed .app bundle.
# Run from the consuming package's root (it reads ./Resources/Info.plist and
# writes ./build/<DisplayName>.app). The ad-hoc codesign is REQUIRED:
# UNUserNotificationCenter silently drops requests from unsigned bundles.
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

# Ad-hoc sign so notifications/launch services treat this as a stable identity.
codesign --force --sign - "${APP_BUNDLE}" >/dev/null

echo "==> Built ${APP_BUNDLE}"
echo "Launch with: open ${APP_BUNDLE}"

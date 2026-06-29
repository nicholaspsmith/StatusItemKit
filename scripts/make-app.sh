#!/bin/bash
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

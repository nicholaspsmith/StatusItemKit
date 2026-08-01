#!/bin/bash
# Regenerate docs/meter-icons.png from the current MeterIcon source.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
swiftc -O scripts/render-meter-icons.swift Sources/StatusItemKit/MeterIcon.swift \
    -o "$TMP/render-meter-icons"
"$TMP/render-meter-icons" docs/meter-icons.png

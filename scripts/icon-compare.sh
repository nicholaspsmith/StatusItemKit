#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

# Show template icons drawn the old way and by IconLayer, side by side in the bar.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# Top-level code compiles only from a file named main.swift.
cp scripts/icon-compare.swift "$TMP/main.swift"
swiftc -O "$TMP/main.swift" Sources/StatusItemKit/IconLayer.swift Sources/StatusItemKit/IconBitmaps.swift \
    Sources/StatusItemKit/MeterIcon.swift -o "$TMP/icon-compare"
"$TMP/icon-compare"

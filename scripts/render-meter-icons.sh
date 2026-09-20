#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2026 Nicholas Smith

# Regenerate docs/meter-icons.png from the current MeterIcon source.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
swiftc -O scripts/render-meter-icons.swift Sources/StatusItemKit/MeterIcon.swift \
    -o "$TMP/render-meter-icons"
"$TMP/render-meter-icons" docs/meter-icons.png

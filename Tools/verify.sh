#!/bin/bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data="$(mktemp -d /tmp/ledcontrol-derived.XXXXXX)"
firmware_build="$(mktemp -d /tmp/ledcontrol-firmware.XXXXXX)"

cleanup() {
    find "$derived_data" -depth -delete
    find "$firmware_build" -depth -delete
}
trap cleanup EXIT

cd "$project_root"

if command -v swiftlint >/dev/null 2>&1; then
    swiftlint lint --strict
else
    echo "warning: SwiftLint is not installed; skipping lint"
fi

xcodebuild build \
    -project LedControl.xcodeproj \
    -scheme LedControl \
    -configuration Release \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO

xcodebuild test \
    -project LedControl.xcodeproj \
    -scheme LedControl \
    -destination 'platform=macOS' \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    -only-testing:LedControlTests

if command -v arduino-cli >/dev/null 2>&1; then
    arduino-cli compile \
        --fqbn arduino:avr:uno \
        --build-path "$firmware_build" \
        Firmware/LEDController
else
    echo "warning: arduino-cli is not installed; skipping firmware build"
fi

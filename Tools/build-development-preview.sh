#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
REPOSITORY_ROOT="${SCRIPT_DIRECTORY:h}"
XCODE_APPLICATION="${LEDCONTROL_XCODE_APPLICATION:-/Applications/Xcode-beta.app}"
DERIVED_DATA="${REPOSITORY_ROOT}/build/DevelopmentPreviewDerivedData"
DIST_DIRECTORY="${REPOSITORY_ROOT}/dist"
STAGING_DIRECTORY="${REPOSITORY_ROOT}/build/DevelopmentPreviewDMG"
APP_SOURCE="${DERIVED_DATA}/Build/Products/Release/LedControl.app"
APP_STAGED="${STAGING_DIRECTORY}/LED Control.app"
DMG_PATH="${DIST_DIRECTORY}/LED-Control-Development-Preview.dmg"
TEAM_ID="8N738727QB"
BUNDLE_IDENTIFIER="com.burakoskay.LedControl"

fail() {
    print -u2 -- "Development Preview build failed: $1"
    exit 1
}

[[ -d "${XCODE_APPLICATION}" ]] || fail "Xcode was not found at ${XCODE_APPLICATION}."
[[ -n "${REPOSITORY_ROOT}" && "${REPOSITORY_ROOT}" != "/" ]] || fail "Invalid repository root."
/usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -q "Apple Development:" || \
    fail "No valid Apple Development signing identity is installed."

export DEVELOPER_DIR="${XCODE_APPLICATION}/Contents/Developer"

/bin/rm -rf -- "${DERIVED_DATA}" "${STAGING_DIRECTORY}"
/bin/mkdir -p -- "${DIST_DIRECTORY}" "${STAGING_DIRECTORY}"
/bin/rm -f -- "${DMG_PATH}"

xcodebuild \
    -project "${REPOSITORY_ROOT}/LedControl.xcodeproj" \
    -scheme LedControl \
    -configuration Release \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "${DERIVED_DATA}" \
    -allowProvisioningUpdates \
    clean build

[[ -d "${APP_SOURCE}" ]] || fail "The Release app product was not created."
/usr/bin/ditto "${APP_SOURCE}" "${APP_STAGED}"

/usr/bin/codesign --verify --deep --strict --verbose=2 "${APP_STAGED}"
/usr/bin/codesign \
    --verify \
    --strict \
    -R="anchor apple generic and identifier \"${BUNDLE_IDENTIFIER}\" and certificate leaf[subject.OU] = \"${TEAM_ID}\"" \
    "${APP_STAGED}"

APP_IDENTIFIER=$(/usr/bin/codesign -dv "${APP_STAGED}" 2>&1 | /usr/bin/sed -n 's/^Identifier=//p')
APP_TEAM=$(/usr/bin/codesign -dv "${APP_STAGED}" 2>&1 | /usr/bin/sed -n 's/^TeamIdentifier=//p')
APP_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_STAGED}/Contents/Info.plist")
[[ "${APP_IDENTIFIER}" == "${BUNDLE_IDENTIFIER}" ]] || fail "Unexpected app identifier."
[[ "${APP_TEAM}" == "${TEAM_ID}" ]] || fail "Unexpected signing team."
[[ "${APP_VERSION}" == "0.2.0" ]] || fail "Unexpected app version."

/bin/ln -s /Applications "${STAGING_DIRECTORY}/Applications"
/usr/sbin/diskutil image create from \
    --volumeName "LED Control Development Preview" \
    --format UDZO \
    "${STAGING_DIRECTORY}" \
    "${DMG_PATH}"
/usr/bin/hdiutil verify "${DMG_PATH}"

print -- "Development Preview ready: ${DMG_PATH}"
/usr/bin/shasum -a 256 "${DMG_PATH}"

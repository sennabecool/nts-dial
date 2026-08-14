#!/bin/bash

set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <marketing-version> <build-version> <output-directory> <derived-data-directory>" >&2
    exit 64
fi

release_version="$1"
release_build_version="$2"
release_output_directory="$3"
release_derived_data_directory="$4"
release_archive_path="$release_output_directory/NTS Dial.xcarchive"
release_app_path="$release_archive_path/Products/Applications/NTS Dial.app"
release_dmg_path="$release_output_directory/NTS.Dial-$release_version.dmg"
release_staging_directory="$release_output_directory/dmg-root"
release_mount_directory="$release_output_directory/dmg-mount"

if [[ -e "$release_output_directory" ]]; then
    echo "Output directory already exists: $release_output_directory" >&2
    exit 1
fi

mkdir -p "$release_output_directory" "$release_derived_data_directory"

xcodebuild archive \
    -project "NTS Dial.xcodeproj" \
    -scheme "NTS Dial" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$release_archive_path" \
    -derivedDataPath "$release_derived_data_directory" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$release_version" \
    CURRENT_PROJECT_VERSION="$release_build_version" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    DEVELOPMENT_TEAM=

if [[ ! -d "$release_app_path" ]]; then
    echo "Archived app not found: $release_app_path" >&2
    exit 1
fi

sparkle_version_directory="$release_app_path/Contents/Frameworks/Sparkle.framework/Versions/B"
sparkle_framework="$release_app_path/Contents/Frameworks/Sparkle.framework"

for required_path in \
    "$sparkle_version_directory/XPCServices/Installer.xpc" \
    "$sparkle_version_directory/XPCServices/Downloader.xpc" \
    "$sparkle_version_directory/Autoupdate" \
    "$sparkle_version_directory/Updater.app"; do
    if [[ ! -e "$required_path" ]]; then
        echo "Required Sparkle component not found: $required_path" >&2
        exit 1
    fi
done

# Sign nested code first. Do not use --deep for signing; it can apply the wrong
# entitlements to Sparkle's sandbox helpers.
codesign --force --sign - --options runtime \
    "$sparkle_version_directory/XPCServices/Installer.xpc"
codesign --force --sign - --options runtime --preserve-metadata=entitlements \
    "$sparkle_version_directory/XPCServices/Downloader.xpc"
codesign --force --sign - --options runtime "$sparkle_version_directory/Autoupdate"
codesign --force --sign - --options runtime "$sparkle_version_directory/Updater.app"
codesign --force --sign - --options runtime "$sparkle_framework"
codesign --force --sign - --options runtime --preserve-metadata=entitlements \
    "$release_app_path"

codesign --verify --deep --strict --verbose=2 "$release_app_path"

release_info_plist="$release_app_path/Contents/Info.plist"
release_entitlements_plist="$release_output_directory/app-entitlements.plist"
release_architectures="$(lipo -archs "$release_app_path/Contents/MacOS/NTS Dial")"

for required_architecture in arm64 x86_64; do
    if [[ " $release_architectures " != *" $required_architecture "* ]]; then
        echo "Missing $required_architecture slice; found: $release_architectures" >&2
        exit 1
    fi
done

assert_plist_value() {
    local plist_path="$1"
    local plist_key="$2"
    local expected_value="$3"
    local actual_value
    actual_value="$(plutil -extract "$plist_key" raw -o - "$plist_path")"
    if [[ "$actual_value" != "$expected_value" ]]; then
        echo "$plist_key mismatch: expected '$expected_value', found '$actual_value'" >&2
        exit 1
    fi
}

assert_plist_value "$release_info_plist" CFBundleShortVersionString "$release_version"
assert_plist_value "$release_info_plist" CFBundleVersion "$release_build_version"
assert_plist_value "$release_info_plist" SUFeedURL \
    "https://github.com/sennabecool/nts-dial/releases/latest/download/appcast.xml"
assert_plist_value "$release_info_plist" SUPublicEDKey \
    "U/h5sCuAlyMBCqFwUTeOslqzpJxt6ywbnD33yF9WslU="
assert_plist_value "$release_info_plist" SUEnableAutomaticChecks true
assert_plist_value "$release_info_plist" SUAutomaticallyUpdate false
assert_plist_value "$release_info_plist" SUEnableInstallerLauncherService true
assert_plist_value "$release_info_plist" SURequireSignedFeed true
assert_plist_value "$release_info_plist" SUVerifyUpdateBeforeExtraction true

codesign --display --entitlements :- "$release_app_path" > "$release_entitlements_plist" 2>/dev/null
assert_plist_value "$release_entitlements_plist" 'com\.apple\.security\.app-sandbox' true
assert_plist_value "$release_entitlements_plist" 'com\.apple\.security\.cs\.disable-library-validation' true
assert_plist_value "$release_entitlements_plist" 'com\.apple\.security\.network\.client' true

if ! plutil -extract 'com\.apple\.security\.temporary-exception\.mach-lookup\.global-name' xml1 -o - \
    "$release_entitlements_plist" | grep -q "cbnns.NTS-Dial-spks"; then
    echo "Missing Sparkle status Mach service entitlement" >&2
    exit 1
fi

if ! plutil -extract 'com\.apple\.security\.temporary-exception\.mach-lookup\.global-name' xml1 -o - \
    "$release_entitlements_plist" | grep -q "cbnns.NTS-Dial-spki"; then
    echo "Missing Sparkle installer Mach service entitlement" >&2
    exit 1
fi

mkdir -p "$release_staging_directory"
ditto "$release_app_path" "$release_staging_directory/NTS Dial.app"
ln -s /Applications "$release_staging_directory/Applications"
hdiutil create \
    -volname "NTS Dial $release_version" \
    -srcfolder "$release_staging_directory" \
    -fs APFS \
    -format ULFO \
    -ov \
    "$release_dmg_path"

mkdir -p "$release_mount_directory"
release_device="$(
    hdiutil attach "$release_dmg_path" -nobrowse -readonly -mountpoint "$release_mount_directory" |
        awk '/^\/dev\// { print $1; exit }'
)"

detach_release_dmg() {
    if [[ -n "${release_device:-}" ]]; then
        hdiutil detach "$release_device" >/dev/null
    fi
}
trap detach_release_dmg EXIT

mounted_app="$release_mount_directory/NTS Dial.app"
codesign --verify --deep --strict --verbose=2 "$mounted_app"
assert_plist_value "$mounted_app/Contents/Info.plist" CFBundleVersion "$release_build_version"

launch_log="$release_output_directory/launch-smoke-test.log"
"$mounted_app/Contents/MacOS/NTS Dial" > "$launch_log" 2>&1 &
release_app_pid=$!
sleep 3
if ! kill -0 "$release_app_pid" 2>/dev/null; then
    echo "Packaged app exited during launch smoke test" >&2
    sed -n '1,160p' "$launch_log" >&2
    exit 1
fi
kill "$release_app_pid"
wait "$release_app_pid" 2>/dev/null || true

detach_release_dmg
release_device=""
trap - EXIT

echo "$release_dmg_path"

#!/usr/bin/env bash
# Export the iOS preset, archive it and upload it to App Store Connect for TestFlight:
# tools/testflight.sh <build directory> [--export-only].
#
# `just testflight` runs this (docs/exports.md "TestFlight"). It needs Xcode signed in to the Apple account of
# the Team ID the export carries, and an App Store Connect app record for the preset's bundle ID.
#
# - A working tree with changes is refused, so every upload maps to a commit.
# - The archive's build number is the commit count. Xcode raises it at upload when App Store Connect already
#   holds that number for the version, which a squash merge can cause.
# - --export-only signs the .ipa into <build directory>/ipa/ and uploads nothing.
# - ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID sign and upload with an App Store Connect API key instead of
#   the Xcode account. The release workflow runs it that way (docs/releases.md).
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 || ( $# -eq 2 && "$2" != "--export-only" ) ]]; then
	printf 'usage: tools/testflight.sh <build directory> [--export-only]\n' >&2
	exit 2
fi
dir="$1"
destination="upload"
if [[ $# -eq 2 ]]; then
	destination="export"
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
	printf 'testflight: commit or stash your changes first. An upload is built from a commit.\n' >&2
	git status --short >&2
	exit 1
fi

# Godot prints every packed file. The log keeps it out of the terminal unless the export fails.
mkdir -p "$dir"
if ! tools/export.sh --export-release iOS "$dir/ios/alex.xcodeproj" > "$dir/export-ios.log" 2>&1; then
	grep -E 'ERROR|error' "$dir/export-ios.log" >&2 || tail -20 "$dir/export-ios.log" >&2
	printf 'The full export log is %s/export-ios.log.\n' "$dir" >&2
	exit 1
fi
printf 'export: %s/ios/alex.xcodeproj\n' "$dir"

# The team the export actually carries, which is the preset's unless .godot/export_credentials.cfg overrides it.
team="$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM = \([A-Z0-9]*\);.*/\1/p' "$dir/ios/alex.xcodeproj/project.pbxproj" | head -1)"
if [[ -z "$team" ]]; then
	printf 'testflight: the iOS export names no team (docs/exports.md "Signing").\n' >&2
	exit 1
fi
build="$(git rev-list --count HEAD)"

# Without an App Store Connect API key, the account Xcode is signed in to signs the archive and the export.
#
# With one, the archive is unsigned and the export signs it with Apple's cloud-managed distribution
# certificate, so a machine with no signing identity can upload. The entitlements come out the same either way.
auth=()
archive_signing=(-allowProvisioningUpdates)
if [[ -n "${ASC_KEY_PATH:-}" ]]; then
	if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
		printf 'testflight: ASC_KEY_PATH needs ASC_KEY_ID and ASC_ISSUER_ID too.\n' >&2
		exit 2
	fi
	auth=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID"
		-authenticationKeyIssuerID "$ASC_ISSUER_ID")
	archive_signing=(CODE_SIGNING_ALLOWED=NO)
fi

archive="$dir/alex.xcarchive"
rm -rf "$archive"
printf 'testflight: archiving build %s for team %s\n' "$build" "$team"
if ! xcodebuild -project "$dir/ios/alex.xcodeproj" -scheme alex -configuration Release \
	-destination 'generic/platform=iOS' -archivePath "$archive" -derivedDataPath build/xcode-dd \
	"${archive_signing[@]}" CURRENT_PROJECT_VERSION="$build" archive \
	> "$dir/archive.log" 2>&1; then
	grep -E 'error:' "$dir/archive.log" | sort -u >&2 || tail -20 "$dir/archive.log" >&2
	printf 'testflight: the archive failed. The full log is %s/archive.log.\n' "$dir" >&2
	exit 1
fi

options="$dir/ExportOptions.plist"
cat > "$options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>$destination</string>
	<key>teamID</key>
	<string>$team</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<true/>
</dict>
</plist>
PLIST

out="$dir/ipa"
rm -rf "$out"
if [[ "$destination" == "upload" ]]; then
	printf 'testflight: uploading to App Store Connect\n'
fi
if ! xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out" -exportOptionsPlist "$options" \
	-allowProvisioningUpdates ${auth[@]+"${auth[@]}"} > "$dir/upload.log" 2>&1; then
	grep -iE 'error' "$dir/upload.log" | sort -u >&2 || tail -20 "$dir/upload.log" >&2
	printf 'testflight: the export failed. The full log is %s/upload.log.\n' "$dir" >&2
	exit 1
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$archive/Info.plist")"
if [[ "$destination" == "export" ]]; then
	printf 'testflight: signed %s (%s) into %s, nothing uploaded\n' "$version" "$build" "$out"
elif grep -q 'Upload succeeded' "$dir/upload.log"; then
	printf 'testflight: uploaded %s from commit %s. App Store Connect processes it for 10 to 30 minutes.\n' \
		"$version" "$(git rev-parse --short HEAD)"
else
	printf 'testflight: xcodebuild finished without reporting an upload. The full log is %s/upload.log.\n' "$dir" >&2
	exit 1
fi

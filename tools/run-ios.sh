#!/usr/bin/env bash
# Export the iOS preset, build it, install it on a paired iPhone or iPad and launch it with its log in this
# terminal: tools/run-ios.sh <build directory> [device].
#
# `just run-ios` runs this (docs/exports.md "Run on a device"). The device is a name or an identifier from
# `xcrun devicectl list devices`. With none given, the one paired physical device is used.
#
# - Pairing and Developer Mode need someone at the device, so the script checks them and prints the steps.
# - The build is signed for development by the Team ID the export carries. Xcode registers the device with
#   that team on first use.
# - Ctrl-C stops the log and the app.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
	printf 'usage: tools/run-ios.sh <build directory> [device]\n' >&2
	exit 2
fi
dir="$1"
wanted="${2:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

pairing_help() {
	cat >&2 <<'HELP'
To pair an iPhone or iPad over Wi-Fi (iOS 27 or later), once:
  1. Unlock it and join the same Wi-Fi network as this Mac.
  2. In Xcode, open Window > Device Hub, click +, choose Pair Nearby Device…, and enter the code it shows.
An older iOS needs a cable for the first pairing. Then run this again.
HELP
}

# One line per paired physical device: identifier, name, Developer Mode status, UDID.
devices="$(xcrun devicectl list devices --quiet --json-output - 2>/dev/null | python3 -c '
import json, sys
for d in json.load(sys.stdin)["result"]["devices"]:
    hardware = d.get("hardwareProperties", {})
    if hardware.get("reality") != "physical" or hardware.get("platform") not in ("iOS", "iPadOS"):
        continue
    if d.get("connectionProperties", {}).get("pairingState") != "paired":
        continue
    props = d.get("deviceProperties", {})
    print("\t".join([d["identifier"], props.get("name", ""), props.get("developerModeStatus", ""),
                     hardware.get("udid", "")]))
')"

if [[ -n "$wanted" ]]; then
	devices="$(awk -F '\t' -v w="$wanted" '$1 == w || $2 == w' <<< "$devices")"
fi
count="$(grep -c . <<< "$devices" || true)"
if [[ "$count" -eq 0 ]]; then
	printf 'run-ios: no paired iPhone or iPad%s.\n' "${wanted:+ named \"$wanted\"}" >&2
	pairing_help
	exit 1
fi
if [[ "$count" -gt 1 ]]; then
	printf 'run-ios: more than one paired device. Name one: just run-ios <name>\n' >&2
	cut -f2 <<< "$devices" | sed 's/^/  /' >&2
	exit 1
fi
IFS=$'\t' read -r device name devmode udid <<< "$devices"
if [[ "$devmode" != "enabled" ]]; then
	cat >&2 <<HELP
run-ios: Developer Mode is off on "$name". On the device, once:
  1. Settings > Privacy & Security > Developer Mode, switch it on and let it restart.
  2. Unlock it and tap Turn On.
HELP
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
project="$dir/ios/alex.xcodeproj"
bundle="$(sed -n 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = \([^;]*\);.*/\1/p' "$project/project.pbxproj" | head -1)"

printf 'run-ios: building for "%s"\n' "$name"
if ! xcodebuild -project "$project" -scheme alex -configuration Debug -destination "id=$udid" \
	-derivedDataPath build/xcode-dd -allowProvisioningUpdates build > "$dir/run-ios.log" 2>&1; then
	grep -E 'error:' "$dir/run-ios.log" | sort -u >&2 || tail -20 "$dir/run-ios.log" >&2
	printf 'run-ios: the build failed. The full log is %s/run-ios.log.\n' "$dir" >&2
	exit 1
fi

printf 'run-ios: installing\n'
xcrun devicectl device install app --quiet --device "$device" build/xcode-dd/Build/Products/Debug-iphoneos/alex.app

# iOS refuses to launch an app on a locked device. Wait up to two minutes for an unlock.
locked() {
	xcrun devicectl device info lockState --device "$device" --quiet --json-output - 2>/dev/null \
		| python3 -c 'import json, sys; sys.exit(0 if json.load(sys.stdin)["result"]["passcodeRequired"] else 1)'
}
if locked; then
	printf 'run-ios: unlock "%s" to launch the app.\n' "$name"
	for _ in $(seq 1 60); do
		sleep 2
		locked || break
	done
	if locked; then
		printf 'run-ios: "%s" stayed locked. The app is installed; open it on the device.\n' "$name" >&2
		exit 1
	fi
fi

printf 'run-ios: launching %s. Ctrl-C stops it.\n' "$bundle"
exec xcrun devicectl device process launch --device "$device" --terminate-existing --console "$bundle"

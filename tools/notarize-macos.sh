#!/usr/bin/env bash
# Sign the macOS export with a Developer ID, notarize it and staple the ticket: tools/notarize-macos.sh <build
# directory>. It replaces <build directory>/macos/alex.zip with the notarized app.
#
# The release workflow runs this (docs/releases.md). It needs:
#
# - A "Developer ID Application" identity in a keychain on the search list. MACOS_SIGN_IDENTITY overrides the
#   name codesign matches.
# - An App Store Connect API key: ASC_KEY_PATH (the .p8), ASC_KEY_ID and ASC_ISSUER_ID.
#
# Godot's ad-hoc export carries the entitlements the preset asks for. They are signed in again under the
# hardened runtime, without get-task-allow, which notarization refuses.
set -euo pipefail

if [[ $# -ne 1 || ! -f "$1/macos/alex.zip" ]]; then
	printf 'usage: tools/notarize-macos.sh <build directory holding macos/alex.zip>\n' >&2
	exit 2
fi
for var in ASC_KEY_PATH ASC_KEY_ID ASC_ISSUER_ID; do
	if [[ -z "${!var:-}" ]]; then
		printf 'notarize: %s is not set\n' "$var" >&2
		exit 2
	fi
done
identity="${MACOS_SIGN_IDENTITY:-Developer ID Application}"
zip="$(cd "$1/macos" && pwd)/alex.zip"

work="$(mktemp -d "${TMPDIR:-/tmp}/alex-notarize.XXXXXX")"
trap 'rm -rf "$work"' EXIT HUP INT TERM

ditto -x -k "$zip" "$work/out"
app="$work/out/Alex.app"
if [[ ! -d "$app" ]]; then
	printf 'notarize: no Alex.app in %s\n' "$zip" >&2
	exit 1
fi

entitlements="$work/entitlements.plist"
codesign -d --entitlements :- "$app" > "$entitlements" 2> /dev/null
/usr/libexec/PlistBuddy -c 'Delete :com.apple.security.get-task-allow' "$entitlements" 2> /dev/null || true

# Nested code first, then the bundle.
while IFS= read -r -d '' nested; do
	codesign --force --timestamp --options runtime --sign "$identity" "$nested"
done < <(find "$app/Contents" \( -name '*.dylib' -o -name '*.framework' \) -print0)
codesign --force --timestamp --options runtime --entitlements "$entitlements" --sign "$identity" "$app"
codesign --verify --strict --deep "$app"
printf 'notarize: signed as %s\n' "$(codesign -dvv "$app" 2>&1 | sed -n 's/^Authority=//p' | head -1)"

ditto -c -k --keepParent "$app" "$work/submit.zip"
printf 'notarize: submitting to Apple, which takes a few minutes\n'
result="$(xcrun notarytool submit "$work/submit.zip" --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" \
	--issuer "$ASC_ISSUER_ID" --wait --output-format json)"
status="$(plutil -extract status raw - <<< "$result" 2> /dev/null || true)"
if [[ "$status" != "Accepted" ]]; then
	id="$(plutil -extract id raw - <<< "$result" 2> /dev/null || true)"
	printf 'notarize: Apple answered %s\n' "${status:-nothing}" >&2
	if [[ -n "$id" ]]; then
		xcrun notarytool log "$id" --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" >&2 || true
	fi
	exit 1
fi

xcrun stapler staple "$app"
spctl --assess --type execute --verbose=2 "$app"

rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
printf 'notarize: %s\n' "$zip"

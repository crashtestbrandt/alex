#!/usr/bin/env bash
# Check what the exports under a build directory hold: tools/check-exports.sh build/<commit>.
#
# `just exports` runs this after every preset has exported (docs/exports.md). Each platform directory that
# exists is checked, and an empty build directory fails.
#
# - Every .pck mounts in Godot and passes tools/instr/pack_probe.gd: starter packs and styles load, and no
#   development file shipped.
# - The Android APK holds the starter packs, asks for the microphone, has no internet permission, and
#   supports every screen size. aapt2 comes from the Android SDK the export used.
# - The Play AAB holds the starter packs, asks for the microphone and has no internet permission.
# - The iOS and macOS bundles carry a microphone usage description, and the iOS project targets iPhone and
#   iPad.
# - The export for this machine boots headless for 300 frames with no error.
set -euo pipefail

if [[ $# -ne 1 || ! -d "$1" ]]; then
	printf 'usage: tools/check-exports.sh <build directory>\n' >&2
	exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$(cd "$1" && pwd)"
GODOT="$("$ROOT/tools/godot-bin.sh")"
PROBE="$ROOT/tools/instr/pack_probe.gd"

headless=(--headless)
if [[ "$(uname -s)" == "Darwin" ]]; then
	headless+=(--rendering-driver opengl3 --audio-driver Dummy)
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/alex-check-exports.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

status=0
checked=0
fail() {
	printf '  FAIL %s\n' "$1"
	status=1
}
pass() {
	printf '  ok   %s\n' "$1"
}

# A path as the report prints it, relative to the build directory or the unpacked copy.
label() {
	local path="${1#"$BUILD"/}"
	printf '%s' "${path#"$WORK"/}"
}

# Mount a .pck as res:// and run the pack probe. It runs from an empty directory, so res:// is the pack alone.
check_pack() {
	local pck="$1" log="$WORK/pack.log"
	if [[ ! -f "$pck" ]]; then
		fail "no pack at $(label "$pck")"
		return
	fi
	if (cd "$WORK" && "$GODOT" "${headless[@]}" --main-pack "$pck" --script "$PROBE") > "$log" 2>&1 \
		&& grep -q '^PACK-PROBE PASS' "$log"; then
		pass "$(label "$pck") passes the pack probe"
	else
		grep -E '^  |PACK-PROBE|ERROR' "$log" | sed 's/^/       /' || true
		fail "$(label "$pck") fails the pack probe"
	fi
}

# A plist key with a non-empty string value. Godot writes XML plists, so grep reads them on any host.
check_plist_text() {
	local plist="$1" key="$2" entry
	entry="$(grep -A1 "<key>$key</key>" "$plist" 2>/dev/null || true)"
	if grep -qE '<string>[^<]+</string>' <<< "$entry"; then
		pass "$key is set"
	else
		fail "$key is missing or empty in $(label "$plist")"
	fi
}

# Run an exported binary headless for 300 frames. Any error line fails it.
check_boot() {
	local bin="$1" log="$WORK/boot.log"
	if (cd "$WORK" && "$bin" --headless --audio-driver Dummy --quit-after 300) > "$log" 2>&1 \
		&& ! grep -qE 'ERROR|SCRIPT ERROR' "$log"; then
		pass "$(label "$bin") boots"
	else
		sed 's/^/       /' "$log" | tail -20
		fail "$(label "$bin") does not boot cleanly"
	fi
}

aapt2_bin() {
	local sdk dir
	for sdk in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"; do
		[[ -n "$sdk" && -d "$sdk/build-tools" ]] || continue
		dir="$(ls -d "$sdk"/build-tools/*/ 2>/dev/null | sort -V | tail -1)"
		if [[ -n "$dir" && -x "${dir}aapt2" ]]; then
			printf '%s' "${dir}aapt2"
			return 0
		fi
	done
	return 1
}

if [[ -d "$BUILD/android" ]]; then
	checked=$((checked + 1))
	echo "android"
	apk="$BUILD/android/alex.apk"
	listing="$(unzip -l "$apk" 2>/dev/null || true)"
	for json in "$ROOT"/starters/*.json; do
		name="starters/$(basename "$json")"
		if grep -q " assets/$name\$" <<< "$listing"; then
			pass "$name is in the APK"
		else
			fail "$name is not in the APK"
		fi
	done
	if grep -qE ' assets/(tests|tools|docs)/| assets/\.mcp\.json$' <<< "$listing"; then
		fail "a development file is in the APK"
	else
		pass "no development file is in the APK"
	fi
	if aapt2="$(aapt2_bin)"; then
		permissions="$("$aapt2" dump permissions "$apk" 2>/dev/null)"
		if grep -q "android.permission.RECORD_AUDIO" <<< "$permissions"; then
			pass "RECORD_AUDIO is declared"
		else
			fail "RECORD_AUDIO is not declared"
		fi
		if grep -q "android.permission.INTERNET" <<< "$permissions"; then
			fail "INTERNET is declared"
		else
			pass "INTERNET is not declared"
		fi
		badging="$("$aapt2" dump badging "$apk" 2>/dev/null)"
		if grep -q "^supports-screens: 'small' 'normal' 'large' 'xlarge'" <<< "$badging"; then
			pass "every screen size is supported"
		else
			fail "a screen size is not supported"
		fi
	else
		fail "no aapt2 under ANDROID_HOME, ANDROID_SDK_ROOT or the default SDK paths"
	fi
fi

if [[ -d "$BUILD/play" ]]; then
	checked=$((checked + 1))
	echo "play"
	aab="$BUILD/play/alex.aab"
	listing="$(unzip -l "$aab" 2>/dev/null || true)"
	for json in "$ROOT"/starters/*.json; do
		name="starters/$(basename "$json")"
		if grep -q "/assets/$name\$" <<< "$listing"; then
			pass "$name is in the AAB"
		else
			fail "$name is not in the AAB"
		fi
	done
	if grep -qE '/assets/(tests|tools|docs)/|/assets/\.mcp\.json$' <<< "$listing"; then
		fail "a development file is in the AAB"
	else
		pass "no development file is in the AAB"
	fi
	# The bundle's manifest is a protocol buffer. Permission names sit in it as plain strings.
	manifest="$(unzip -p "$aab" base/manifest/AndroidManifest.xml 2>/dev/null | strings || true)"
	if grep -q "android.permission.RECORD_AUDIO" <<< "$manifest"; then
		pass "RECORD_AUDIO is declared"
	else
		fail "RECORD_AUDIO is not declared"
	fi
	if grep -q "android.permission.INTERNET" <<< "$manifest"; then
		fail "INTERNET is declared"
	else
		pass "INTERNET is not declared"
	fi
fi

if [[ -d "$BUILD/ios" ]]; then
	checked=$((checked + 1))
	echo "ios"
	check_pack "$BUILD/ios/alex.pck"
	check_plist_text "$BUILD/ios/alex/alex-Info.plist" NSMicrophoneUsageDescription
	if grep -q 'TARGETED_DEVICE_FAMILY = "1,2";' "$BUILD/ios/alex.xcodeproj/project.pbxproj" 2>/dev/null; then
		pass "the project targets iPhone and iPad"
	else
		fail "the project does not target both iPhone and iPad"
	fi
fi

if [[ -d "$BUILD/macos" ]]; then
	checked=$((checked + 1))
	echo "macos"
	unzip -q -o "$BUILD/macos/alex.zip" -d "$WORK/macos"
	app="$WORK/macos/Alex.app"
	check_pack "$app/Contents/Resources/Alex.pck"
	check_plist_text "$app/Contents/Info.plist" NSMicrophoneUsageDescription
	if [[ "$(uname -s)" == "Darwin" ]]; then
		entitlements="$(codesign -d --entitlements - "$app" 2>/dev/null || true)"
		if grep -q 'com.apple.security.device.audio-input' <<< "$entitlements"; then
			pass "the audio-input entitlement is signed in"
		else
			fail "the audio-input entitlement is missing"
		fi
		check_boot "$app/Contents/MacOS/Alex"
	fi
fi

if [[ -d "$BUILD/windows" ]]; then
	checked=$((checked + 1))
	echo "windows"
	check_pack "$BUILD/windows/alex.pck"
fi

if [[ -d "$BUILD/linux" ]]; then
	checked=$((checked + 1))
	echo "linux"
	check_pack "$BUILD/linux/alex.pck"
	if [[ "$(uname -s)" == "Linux" && "$(uname -m)" == "x86_64" ]]; then
		check_boot "$BUILD/linux/alex.x86_64"
	fi
fi

if [[ "$checked" -eq 0 ]]; then
	printf 'check-exports: no platform directory under %s\n' "$BUILD" >&2
	exit 1
fi
if [[ "$status" -ne 0 ]]; then
	exit 1
fi
echo "Exports OK."

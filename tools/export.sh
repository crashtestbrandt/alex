#!/usr/bin/env bash
# Export one preset: tools/export.sh <--export-debug|--export-release> <preset name> <output path>.
#
# The `just export-*` recipes call this (docs/exports.md). It fails when Godot fails, and when Godot exits 0
# without writing the output.
#
# An Android debug export signs with GODOT_ANDROID_KEYSTORE_DEBUG_* when they are set. Otherwise it signs with
# ~/.android/debug.keystore, the key Android Studio uses, and makes that key with keytool on first use. One
# key per machine lets `adb install -r` replace an earlier build without losing the app's data.
#
# An Android release export signs with GODOT_ANDROID_KEYSTORE_RELEASE_*, and Godot fails without them.
#
# ALEX_VERSION, when set, is the version every preset exports with. The release workflow sets it from the tag.
# Without it a build carries project.godot's placeholder, 0.0.0.
#
# Both Android presets take the commit count as their version code, the build number iOS uses too.
#
# project.godot and export_presets.cfg are stamped for the length of the export and restored after it.
#
# The `Google Play` preset is a Gradle build. Godot installs the build template into android/, which git
# ignores, and Gradle fetches its dependencies on the first build.
set -euo pipefail

if [[ $# -ne 3 ]]; then
	printf 'usage: tools/export.sh <--export-debug|--export-release> <preset> <output>\n' >&2
	exit 2
fi
mode="$1"
preset="$2"
out="$3"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Headless Godot on macOS crashes inside MoltenVK unless it runs on opengl3 with no audio device (justfile).
headless=(--headless)
if [[ "$(uname -s)" == "Darwin" ]]; then
	headless+=(--rendering-driver opengl3 --audio-driver Dummy)
fi

keytool_bin() {
	if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/keytool" ]]; then
		printf '%s' "$JAVA_HOME/bin/keytool"
	else
		printf 'keytool'
	fi
}

if [[ "$preset" == "Android" && "$mode" == "--export-debug" && -z "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" ]]; then
	keystore="$HOME/.android/debug.keystore"
	if [[ ! -f "$keystore" ]]; then
		mkdir -p "$HOME/.android"
		"$(keytool_bin)" -genkeypair -noprompt -keystore "$keystore" -storepass android -keypass android \
			-alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -keysize 2048 \
			-validity 10000
	fi
	export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$keystore"
	export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
	export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
fi

# The output directory is emptied first, so a failed export cannot pass on an earlier one's files. It must
# sit under build/, which keeps the emptying away from anything else.
out_dir="$(dirname "$out")"
case "$out_dir" in
	build/?*) ;;
	*)
		printf 'export: the output must be inside a directory under build/, not %s\n' "$out" >&2
		exit 2
		;;
esac
rm -rf "$out_dir"
mkdir -p "$out_dir"
# build/ sits inside the project. The .gdignore keeps the editor from importing an export, such as the iOS
# project's icons.
touch build/.gdignore

stamped=()
restore() {
	local file
	for file in ${stamped[@]+"${stamped[@]}"}; do
		cp "$out_dir/$file.orig" "$file" && rm -f "$out_dir/$file.orig"
	done
}
trap restore EXIT
# stamp <file> <sed expression>: edit a project file until the export ends.
stamp() {
	cp "$1" "$out_dir/$1.orig"
	stamped+=("$1")
	sed -i.bak "$2" "$1"
	rm -f "$1.bak"
}

if [[ -n "${ALEX_VERSION:-}" ]]; then
	if [[ ! "$ALEX_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		printf 'export: ALEX_VERSION is "%s". It must be X.Y.Z.\n' "$ALEX_VERSION" >&2
		exit 2
	fi
	stamp project.godot "s/^config\/version=.*/config\/version=\"$ALEX_VERSION\"/"
	printf 'export: version %s\n' "$ALEX_VERSION"
fi

extra=()
if [[ "$preset" == "Android" || "$preset" == "Google Play" ]]; then
	code="$(git rev-list --count HEAD 2> /dev/null || echo 1)"
	stamp export_presets.cfg "s/^version\/code=.*/version\/code=$code/"
	printf 'export: version code %s\n' "$code"
fi
if [[ "$preset" == "Google Play" && ! -d android/build ]]; then
	extra+=(--install-android-build-template)
fi

tools/godot.sh "${headless[@]}" --path . ${extra[@]+"${extra[@]}"} "$mode" "$preset" "$out"

if [[ ! -e "$out" ]]; then
	printf 'export: Godot wrote no %s for the "%s" preset.\n' "$out" "$preset" >&2
	exit 1
fi
printf 'export: %s\n' "$out"

#!/usr/bin/env bash
# The export presets keep the rules docs/exports.md lists. No Godot; it reads export_presets.cfg as text.
#
# The editor rewrites the file with every option and no comments whenever a preset is changed in the Export
# dialog. This check is what holds the rules across that rewrite.
#
# Usage: tools/check-export-presets.sh [file]. The file defaults to the repository's export_presets.cfg.
set -euo pipefail

FILE="${1:-$(cd "$(dirname "$0")/.." && pwd)/export_presets.cfg}"
if [ ! -f "$FILE" ]; then
	echo "::error file=$FILE::check-export-presets: $FILE is missing"
	exit 1
fi

# One line per setting: preset name, key, value with surrounding quotes removed. Both [preset.N] and
# [preset.N.options] count as preset N. Continuation lines of a multi-line value are skipped.
FLAT="$(awk '
	/^\[preset\.[0-9]+(\.options)?\]$/ {
		section = $0
		gsub(/^\[preset\.|(\.options)?\]$/, "", section)
		next
	}
	/^\[/ { section = ""; next }
	section != "" && /^[A-Za-z0-9_\/.-]+=/ {
		eq = index($0, "=")
		key = substr($0, 1, eq - 1)
		value = substr($0, eq + 1)
		if (value ~ /^".*"$/) value = substr(value, 2, length(value) - 2)
		if (key == "name") names[section] = value
		n++; sec[n] = section; keys[n] = key; vals[n] = value
	}
	END { for (i = 1; i <= n; i++) printf "%s\t%s\t%s\n", names[sec[i]], keys[i], vals[i] }
' "$FILE")"

status=0
fail() {
	echo "::error file=$FILE::$1"
	status=1
}

# Prints the value of KEY in preset NAME, or nothing with a non-zero status when the key is absent.
get() {
	printf '%s\n' "$FLAT" | awk -F '\t' -v name="$1" -v key="$2" '
		$1 == name && $2 == key { print $3; found = 1; exit }
		END { exit !found }
	'
}

has_preset() {
	printf '%s\n' "$FLAT" | awk -F '\t' -v name="$1" '$1 == name { found = 1 } END { exit !found }'
}

expect() {
	local value
	if ! value="$(get "$1" "$2")"; then
		fail "\"$1\" has no $2. It must be $3."
	elif [ "$value" != "$3" ]; then
		fail "\"$1\" has $2=$value. It must be $3."
	fi
}

expect_not_true() {
	local value
	if value="$(get "$1" "$2")" && [ "$value" = "true" ]; then
		fail "\"$1\" has $2=true. It must be false."
	fi
}

expect_text() {
	local value
	if ! value="$(get "$1" "$2")" || [ -z "$value" ]; then
		fail "\"$1\" has no $2. The operating system refuses the microphone without it."
	fi
}

# The just export-* recipes name these presets.
PRESETS=("Android" "Google Play" "iOS" "macOS" "Windows Desktop" "Linux")
for name in "${PRESETS[@]}"; do
	if ! has_preset "$name"; then
		fail "No preset is named \"$name\". The justfile's export recipes name it."
	fi
done

# Starter packs are read with DirAccess, so nothing references them. The include keeps them in a build whose
# export mode is not "all resources".
while IFS= read -r name; do
	filter="$(get "$name" include_filter || true)"
	if ! printf '%s' "$filter" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -qx 'starters/\*\.json'; then
		fail "\"$name\" has no starters/*.json in include_filter."
	fi
done < <(printf '%s\n' "$FLAT" | awk -F '\t' '$2 == "name" { print $3 }')

# Phones and tablets, a microphone, and nothing that leaves the device.
for name in "Android" "Google Play"; do
	if has_preset "$name"; then
		expect "$name" permissions/record_audio true
		for size in small normal large xlarge; do
			expect "$name" "screen/support_$size" true
		done
		expect_not_true "$name" permissions/internet
		expect_not_true "$name" user_data_backup/allow
		# tools/export.sh stamps the commit count over this line, so it must be there.
		expect "$name" version/code 1
	fi
done
# The Play Store takes only an AAB, which needs the Gradle build.
if has_preset "Google Play"; then
	expect "Google Play" gradle_build/use_gradle_build true
	expect "Google Play" gradle_build/export_format 1
fi
if has_preset "iOS"; then
	expect "iOS" application/targeted_device_family 2
	expect_text "iOS" privacy/microphone_usage_description
fi
if has_preset "macOS"; then
	expect "macOS" codesign/entitlements/audio_input true
	expect_text "macOS" privacy/microphone_usage_description
fi

# Signing secrets come from the environment, never from this file.
while IFS=$'\t' read -r name key value; do
	case "$key" in
		*password | keystore/release | keystore/release_user | script_encryption_key)
			if [ -n "$value" ]; then
				fail "\"$name\" sets $key. Signing secrets come from environment variables (docs/exports.md)."
			fi
			;;
	esac
done <<< "$FLAT"

if [ "$status" -ne 0 ]; then
	exit 1
fi
echo "Export presets OK."

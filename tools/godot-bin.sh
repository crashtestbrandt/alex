#!/usr/bin/env bash
# Print the path of the Godot binary the repo's tooling runs, or say why there is none.
#
# A path rather than a wrapper, so a script that backgrounds Godot and later kills `$!` kills the engine
# and not a filter in front of it. The lookup, in order:
#   1. GODOT_BIN                       explicit
#   2. `godot` / `godot4` on PATH      the Linux and macOS convention
#   3. macOS: /Applications/Godot.app  the official download, unpacked and nothing else
set -u

resolve_godot() {
	if [[ -n "${GODOT_BIN:-}" ]]; then
		printf '%s' "$GODOT_BIN"
		return 0
	fi
	local name found
	for name in godot godot4; do
		if found="$(command -v "$name" 2>/dev/null)" && [[ -n "$found" ]]; then
			printf '%s' "$found"
			return 0
		fi
	done
	if [[ "$(uname -s)" == "Darwin" ]]; then
		found="/Applications/Godot.app/Contents/MacOS/Godot"
		if [[ -x "$found" ]]; then
			printf '%s' "$found"
			return 0
		fi
	fi
	return 1
}

if godot_binary="$(resolve_godot)" && [[ -n "$godot_binary" ]]; then
	printf '%s\n' "$godot_binary"
	exit 0
fi

{
	printf 'godot-bin: no Godot binary found.\n'
	printf '  Set GODOT_BIN to the executable, or put one on PATH as `godot`.\n'
	printf '  Looked for: GODOT_BIN, then `godot` and `godot4` on PATH, then /Applications/Godot.app on macOS.\n'
	printf '  See docs/dev-setup.md.\n'
} >&2
# 127 is what a missing command exits with.
exit 127

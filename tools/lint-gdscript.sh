#!/usr/bin/env bash
# GDScript lint: load the project headless and fail on any compiler or script error in the log.
#
# Godot's --check-only is per script and does not load autoloads, so a wrong call into `App` or
# `ProfileStore` passes it. Loading the project catches that, and the warnings project.godot promotes to
# errors fail the load.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT="${GODOT:-}"
if [ -z "$GODOT" ]; then
	GODOT="$("$ROOT/tools/godot-bin.sh")"
fi

TMPDIR="${TMPDIR:-/tmp}"
LOG_FILE="$(mktemp "${TMPDIR%/}/jessie-gdscript-lint.XXXXXX")"
trap 'rm -f "$LOG_FILE"' EXIT HUP INT TERM

if [ -d "$ROOT/build" ]; then
	touch "$ROOT/build/.gdignore"
fi

# macOS headless can crash inside MoltenVK during the --import pass. The project load pass still surfaces
# every script error, so on macOS the import is best-effort and runs on opengl3. Linux, the CI gate, keeps
# both passes fatal.
RENDER_ARGS=""
IMPORT_FATAL=1
if [ "$(uname)" = "Darwin" ]; then
	RENDER_ARGS="--rendering-driver opengl3 --audio-driver Dummy"
	IMPORT_FATAL=0
fi

run_godot() {
	fatal="$1"
	label="$2"
	shift 2
	printf '>> %s\n' "$label" >>"$LOG_FILE"
	set +e
	# shellcheck disable=SC2086
	"$GODOT" "$@" >>"$LOG_FILE" 2>&1
	status="$?"
	set -e
	if [ "$status" -ne 0 ]; then
		if [ "$fatal" -eq 1 ]; then
			printf 'Godot command failed during %s with exit code %s.\n\n' "$label" "$status"
			cat "$LOG_FILE"
			exit "$status"
		fi
		printf '   (non-fatal on this platform: %s exited %s; relying on the load pass for error detection)\n' "$label" "$status"
	fi
}

# shellcheck disable=SC2086
run_godot "$IMPORT_FATAL" "import / class registration" --headless --no-header $RENDER_ARGS --path "$ROOT" --import
# shellcheck disable=SC2086
run_godot 1 "main scene script load" --headless --no-header $RENDER_ARGS --path "$ROOT" --quit
# A probe is in no scene, so the pass above never loads one. This one loads every tools/instr script.
# shellcheck disable=SC2086
run_godot 1 "instrumentation script load" --headless --no-header $RENDER_ARGS --path "$ROOT" --script res://tools/lint-instr.gd

ERROR_PATTERN='SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|GDScript::reload'

if grep -E "$ERROR_PATTERN" "$LOG_FILE" >/dev/null; then
	printf 'GDScript lint failed. Matching diagnostics:\n\n'
	grep -E "$ERROR_PATTERN" "$LOG_FILE" || true
	printf '\nFull Godot log:\n\n'
	cat "$LOG_FILE"
	exit 1
fi

printf 'GDScript lint passed.\n'

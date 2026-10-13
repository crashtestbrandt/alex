#!/usr/bin/env bash
# Run the Godot that tools/godot-bin.sh resolves, passing every argument, stdout, stderr and the exit code
# through untouched. Every `just` recipe goes through here so GODOT_BIN is honored in one place.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
godot_binary="$("$SCRIPT_DIR/godot-bin.sh")" || exit $?
exec "$godot_binary" "$@"

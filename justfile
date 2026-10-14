set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set windows-shell := ["C:/Program Files/Git/bin/bash.exe", "-eu", "-o", "pipefail", "-c"]

# Every recipe runs Godot through this wrapper, which resolves GODOT_BIN, then `godot` on PATH, then the
# macOS app bundle (tools/godot-bin.sh).
godot := justfile_directory() / "tools" / "godot.sh"

# Headless Godot on macOS crashes inside MoltenVK unless it is pointed at opengl3 with no audio device. Linux
# and Windows need nothing.
headless := if os() == "macos" { "--headless --rendering-driver opengl3 --audio-driver Dummy" } else { "--headless" }

# Build outputs are namespaced by commit. A tree with no commit yet stamps `nocommit`.
commit := `git rev-parse --short=8 HEAD 2>/dev/null || echo nocommit`

default:
    @just --list

# What a fresh clone runs once: the import pass that registers every class_name. `just test` and every
# `--script` gate need it.
setup: reimport

editor:
    "{{godot}}" --editor --path .

run:
    "{{godot}}" --path .

# Open straight into one profile, skipping the picker. `just profiles` lists the ids.
run-profile ID:
    "{{godot}}" --path . -- --profile={{ID}}

# The profile ids in this machine's user:// directory (docs/profiles.md).
profiles:
    @dir="$(just _user-dir)/profiles"; ls "$dir" 2>/dev/null || echo "(no profiles yet under $dir)"

# Where Godot keeps user:// for this project on this host.
_user-dir:
    @if [ "{{os()}}" = "macos" ]; then echo "$HOME/Library/Application Support/Godot/app_userdata/Alex"; \
    elif [ "{{os()}}" = "windows" ]; then echo "$APPDATA/Godot/app_userdata/Alex"; \
    else echo "${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Alex"; fi

# Headless project load; fails on compiler or script errors (tools/lint-gdscript.sh).
lint:
    tools/lint-gdscript.sh

# The unit suites under tests/unit/, about a second. Needs one import pass first (`just setup`).
test:
    "{{godot}}" {{headless}} --path . --script tests/run_unit_tests.gd

# Only the suites that declare no Node, scene, server or asset needs.
test-pure:
    "{{godot}}" {{headless}} --path . --script tests/run_unit_tests.gd -- --without=all

reimport:
    "{{godot}}" {{headless}} --path . --import

doc-size-check:
    tools/check-doc-size.sh

# The room on a live scene tree: seed a profile, tap every spot, switch to the board (tools/instr/room_probe.gd).
room-probe:
    "{{godot}}" {{headless}} --path . tools/instr/room_probe.tscn

# The microphone on a real audio device: record ambient sound, save it, reload it (tools/instr/mic_probe.gd).
# Windowed, because the dummy audio driver has no capture; out of `check` for the same reason.
mic-probe:
    "{{godot}}" --path . tools/instr/mic_probe.tscn

# The README picture: open the room, swing the door, light the lamp, save docs/img/room.png
# (tools/instr/screenshot_probe.gd). Windowed. Re-run whenever the room changes.
screenshot:
    "{{godot}}" --path . tools/instr/screenshot_probe.tscn

# Everything the PR gate runs, in its order, then the headless scene probes.
check: doc-size-check lint test room-probe

# Desktop exports into build/<commit>/<platform>/. Each needs the matching 4.7 export template installed and
# a preset of that name in export_presets.cfg, which does not exist yet (README "Exports").
export-macos:
    mkdir -p build/{{commit}}/macos
    "{{godot}}" --headless --path . --export-release "macOS" build/{{commit}}/macos/alex.zip

export-linux:
    mkdir -p build/{{commit}}/linux
    "{{godot}}" --headless --path . --export-release "Linux" build/{{commit}}/linux/alex.x86_64

export-windows:
    mkdir -p build/{{commit}}/windows
    "{{godot}}" --headless --path . --export-release "Windows Desktop" build/{{commit}}/windows/alex.exe

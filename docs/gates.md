# Gates

## Unit tests versus probes

1. **Pure logic** (no `SceneTree`, no server) gets a `tests/unit/*_test.gd` suite: `extends UnitTest`,
   `test_*` methods, fixtures built directly. The whole set runs in about a second under `just test`.
   Logic on a `Node` is usually still unit-testable through `.new()` without `_ready()`.
2. **Something that genuinely needs a live scene, renderer or audio device** gets a `tools/instr/*_probe.gd`
   scene gate. A probe never runs on a pull request.

A suite declares what it needs (`needs()`: `NODES`, `SCENES`, `SERVERS`, `ASSETS`), and the runner checks
the declaration: a suite that declared nothing and left a Node alive fails by name. `setup()` and
`teardown()` bracket every method. A file-writing suite uses a temporary root under `user://` and removes it
in `teardown()` (`profile_repo_test.gd`).

Suites are hand-rolled, no GUT or GdUnit4. `tests/run_unit_tests.gd` discovers them.

## The PR gate

`.github/workflows/check.yml` runs on GitHub-hosted runners, in this order:

| Step | What |
| --- | --- |
| doc caps | `tools/check-doc-size.sh`, no Godot. |
| export presets | `tools/check-export-presets.sh`, no Godot. The rules are in docs/exports.md. |
| lint | `tools/lint-gdscript.sh`: import, then load the main scene; fail on any script error. |
| test | `tests/run_unit_tests.gd`. |
| exports | Linux, Windows and a debug-signed Android APK, checked by `tools/check-exports.sh`. |

A pull request restores the Godot and template caches and saves none, and uploads no artifact. A push to
`main` saves the caches. A `v*` tag runs the release workflow instead (docs/releases.md).

`just check` runs the first four locally, then the headless scene probes (`just room-probe`, which picks,
taps, walks the views and idles back; docs/geometry.md "Gates"). A probe stays out of the PR gate. `just lint` also loads every `tools/instr/*.gd` so a probe that does not compile fails
there rather than at a run.

`just exports` builds every export preset and checks what each one holds (docs/exports.md "Validation"). It
needs export templates and SDKs, so it stays out of `just check`.

## Doc size caps

`CLAUDE.md` at 40,000 bytes and `README.md` at 16,000. When one trips, move a section to `docs/` and leave a
pointer. Raising a cap is the owner's call.

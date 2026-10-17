# Alex — Claude Code context

`CLAUDE.md` is capped at 40,000 bytes and `README.md` at 16,000 by `tools/check-doc-size.sh` (`just
doc-size-check`). This file loads into every agent context on every session; it states durable rules and
nothing else. Each `docs/` page named below is the authority on its subject. When a section here grows,
move it into `docs/` and leave a one-line pointer. Do not raise a size cap to make a check pass.

## Writing for humans

Everything written for a human reader — PR titles, commit messages, issue and review comments, in-app
copy, code comments, chat replies, this file and every page under `docs/` — is **concise, bulleted and
aphorism-free**. State plainly what changed and what it now does.

**The rules hold on every surface.** A sentence that is hard to read on a button is hard to read in `docs/`
and in a comment.

- No metaphor, euphemism, or oblique stand-in for the thing you mean.
- No epigrams or rhetorical inversions ("A *X* is not a *Y*", "not *X*, but *Y*").
- No teaser clause joined by a colon to the real content.
- No emphatic capitalization, and no general truth standing in for the specific change.
- **Lead with the operative fact, in the main clause.** Conditions, exceptions and history come after it.
- **One idea per sentence.** A trailing clause carrying a caveat, a rationale or a cross-reference belongs in
  its own sentence or nowhere.
- **Cut rationale the reader cannot act on.** Why a default was chosen, how a mechanism works, and what the
  behavior used to be belong in the code comment or the issue.
- **Parallel things get parallel sentences** — one shape, the differing term swapped.
- **Refer to a thing by name, never by position** ("above", "below", "the buttons under the room"). Position
  breaks on every reorder.
- Short sections, bullets over paragraphs, tables for enumerations, identifiers in backticks.

The five rules in bold come from a measured rewrite of 64 strings in the spaceman repository (its PR #1029).

**A PR title is a release-notes line.** Form: `<type>(<area>) <plain description> (#issue)`, type one of
`feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build`, `chore`; area one of `profiles`, `rooms`, `style`,
`speech`, `child`, `ui`, `starters`, `geometry`, `tools`, `ci`, `docs`.

### What belongs on a control

The rules above hold here too. A button or a status line has room for one fact. A `docs/` page has room for
the rule set.

- **One sentence.**
- **A control describes itself.** "Hold the button, say it, let go" is the record button's job. Why a familiar
  voice matters is the README's.
- **The mechanism and the default's justification are both out.** The caregiver is pressing Keep, not reading
  about `AudioEffectRecord`.
- **An internal identifier in learner or caregiver text is a leak.** No ids, no enum names, no file names.
- **Units go in parentheses at the end** — `(seconds)`.
- **Judge a rewrite on what each word buys.** Words are worth spending on a boundary value's meaning, on the
  polarity of a switch stated outright, and on the second half of a rule that has two halves.

**In-app copy is read by tired parents and by clinicians.** Plain words, no jargon the NLA guide does not
use, and never a judgment of the child ("correct", "wrong", "score"). The learner's screen never shows the
app's name, no screen speaks it, and the app has no persona.

## Project

- A configurable app for children who are gestalt language processors. **Not one child's app**: nothing
  about a specific child is in code (docs/design.md, docs/profiles.md).
- **Godot 4.7-stable**, GDScript only (no C#); pass the `godot-docs` MCP `version: "4.7"`.
- **Mobile renderer** on every platform; phones and tablets are the targets; mouse emulates touch.
- **A `vX.Y.Z` tag on `main` releases every platform** (docs/releases.md). `just release X.Y.Z` tags it. The
  tag is the version; `project.godot` keeps `0.0.0`. A `vX.Y.Z-rc.N` tag goes to testers only.
- **A tag takes every store as far as it can go, with no step by hand.** A store step that needs a person is a
  gap to automate, not a release instruction.
- **Six export presets** (docs/exports.md): Android, Google Play, iOS, macOS, Windows, Linux. `just exports`
  builds and checks them.
- No ADRs. Record decisions in the README, a `docs/` page or a script header comment.

## Hard GDScript rules (`project.godot` promotes these warnings to errors)

- Every `var`, parameter and return type carries an explicit type annotation.
- `Array`/`Dictionary` always typed: `Array[Node]`, `Dictionary[String, int]`. `@export`/`@onready` vars typed.
- Do not pass a `Variant` to a typed constructor or `as`-cast it without an `is` check first. Assign it to a
  typed `var` instead.
- Prefer `%UniqueName` over `$Path/To/Node`, and enums over magic values. `@warning_ignore` is banned unless
  a comment explains the false positive.
- No Python idioms: `size()` not `len()`, `push_back()` not `append()`, `null` not `None`.
- Run `just lint` after GDScript or scene changes. On macOS the headless `--import` can crash in MoltenVK;
  the load step still validates scripts.
- The open editor overwrites Edit-tool changes to a scene. Close it first.

## Product rules (docs/design.md)

**The intent, in priority order:** approachable and low-risk for caregivers and learners; discoverable by
the learner alone; interesting enough to sustain interest; useful; harmless. The earlier wins a conflict.

- **The learner is never tested.** No questions, no right answers, no scores, no streaks, no timers, no
  rewards. A screen that adds one of these is wrong however well it is built.
- **Nothing the learner can reach deletes, buys, or leaves the device.** No network, no analytics.
- **No modals, confirmations or error text on the learner's screen.** Log it for the caregiver.
- **Nothing built to extend a session.** No notifications, feed, autoplay chain or "one more".
- **Repetition is unlimited and never interrupted.**
- **Rooms and spots are data** (`Room`, `Spot`), built from primitives by `ObjectRecipes` (docs/geometry.md).
  A new object kind is a `Spot.Kind` plus a recipe function, never an art asset.
- **A recipe is a union of rigid primitives, with no seed.** The mesh (`Mesher`) and the field (`Sdf`) are
  twins; a primitive or an operation exists in both or in neither. The same spot is the same object every time.
- **The learner's camera is perspective.** Front and Top are points on one clamped orbit, each with a clamped
  pan and pinch-zoom; Tilt stands at the room's center and turns in place with every wall up. `Room.camera`
  decides which buttons show. A tap on a view pill resets that view, and a moved view returns to Front after
  two minutes with nothing touched. Orthographic is for the editor.
- **A press is a tap, a hold or a drag by distance and time.** Movement past `DRAG_PX` cancels the hold and
  moves the view from wherever the press began, an object included. Release inside the threshold before the
  hold elapses is a tap.
- **The recording overlay writes nothing until Keep**, keeps the previous take, and closes itself when idle.
- **A familiar voice beats a synthetic one.** The OS text-to-speech voice is a placeholder until a
  recording exists. Never make the synthetic voice the better experience.
- **Gestalts are authored with `|` chunk marks** (`Gestalt.from_text`). The chunks are the mitigation
  model; a Stage 1 gestalt with no bar stays whole, on purpose.
- **A chunk's color is keyed by its text alone** (`ChunkColors`, docs/ui.md "Chunk colors"). It carries
  identity, never a judgment. Every chunk on screen is a `ChunkRow` pill, and its text keeps the preset's
  text color.
- **A stage is optional, informs the caregiver only, and never appears on the learner's screen.**
- **The learner's strip reads Explore and Words** (docs/ui.md "The mode strip"). Room and board titles stay
  in profile data and off the learner's screen. Words is the whole bank, as Palette tiles or as Build, a
  strip filled from chunk beginnings and endings (`ChunkBank`), chunk-first and never word-first.
- **Adult screens sit behind a `HoldButton`.** A stray tap never leaves the board.
- **Motion respects the style's `motion` setting.** Every tween multiplies by `Style.motion_scale()` and
  skips at zero.
- **Touch targets honor `StylePreset.tile_min_size`.** 160 px is the floor. In the room, picking takes the
  nearest object within half the floor when the ray misses. The view buttons are secondary and take seven
  tenths of the floor, never under 96 px.
- **Screen-space graphics are distance fields** (docs/ui.md). A button, panel, tile or bar is an `SdfShape`,
  an icon is an `SdfGlyph` figure, text is MSDF. Corners are concentric, bars are pills, relief comes from the
  style preset. No `StyleBoxFlat`, no image, no `_draw` polyline on anything a user sees. A new control
  extends `SdfButton` or `SdfPanel`; a new icon is a figure in `glyph.gdshader` plus a `SdfGlyph.Figure`.

## Data rules (docs/profiles.md)

- **A profile is the unit of configuration**: `user://profiles/<id>/profile.json` plus `media/`. A family's
  recordings never enter the repository.
- **`Profile.SCHEMA_VERSION` changes with the on-disk shape**, and `from_dict` reads only its own version.
  A migration is a function that takes the old dictionary and returns the new one, with a unit test.
- **A bad row is skipped, never fatal.** One malformed gestalt does not lose a profile.
- **Starter packs are JSON under `starters/`**, written for non-developers. `starter_test.gd` checks every
  board names gestalts the pack holds. Every export preset includes `starters/*.json` and `PRIVACY.md`
  (`tools/check-export-presets.sh`).
- **A profile adds a pack as a scene** (`Starter.add_to`, docs/profiles.md "Adding a scene"). Copied ids are
  prefixed with the pack id, a phrase the bank already says is reused rather than copied, and a pack is
  added once. The profile never reads the pack again.
- **Removing a scene keeps every recorded phrase** (`Profile.remove_scene`, docs/profiles.md "Removing a
  scene"). Explore opens on the profile's `entry` scene.
- **Style presets are `.tres` under `styles/`.** `Style.apply` builds the Theme; there is no theme file. A
  preset also carries the room's materials (`wood`, `cloth`, `metal`, `glass`, `water`, `floor_color`,
  `wall_color`) and the `chunk_palette`. A palette color carries `text` at 4.5:1 (`style_preset_test.gd`).

## Gates (docs/gates.md)

- **Pure logic gets a `tests/unit/*_test.gd` suite** (`extends UnitTest`, `test_*` methods). A suite declares
  what it needs through `needs()`; the runner fails a suite that declared nothing and left a Node alive.
- **Something that genuinely needs a live scene gets a probe under `tools/instr/`**, never on a PR.
- `just check` is the PR gate: doc caps, export presets, lint, unit suites. Deterministic, no clock.
- A file-writing test uses a temporary root under `user://` and removes it in `teardown()`.

## Licensing

**MIT OR Apache-2.0**, dual-licensed, `LICENSE` is the authority. Contributions are dual-licensed the same way;
no CLA. A dependency is added together with a `THIRD_PARTY.md` row carrying its license, in the same commit.
Anything not MIT, Apache-2.0, BSD or MPL-2.0 needs a conversation first.

## Ask before doing

- Adding an addon to `addons/`.
- Touching the `project.godot` input map, autoloads or renderer.
- Adding a deploy target, a signing key, or a secret. Signing secrets come from environment variables.
- Adding any AI or network call. The app is offline and local by design; an AI seam, if one comes, is
  adult-facing only and never talks to the child.
- Raising either doc size cap.

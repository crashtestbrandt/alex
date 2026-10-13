# Jessie

A room to explore, that speaks in voices you love.

Jessie is a small app for children who acquire language in whole chunks: autistic children, children with
developmental delays, and any child whose first speech is echolalia. It is not a clinical tool and not a
substitute for one. It is something a learner can pick up and discover on their own, after a caregiver spends a
few minutes setting it up.

## What the learner sees

A room. A door, a lamp, a window, a ball, a cup, a bed, a pair of shoes, a tub. Touch the door and it swings
open as a familiar voice says "Let's go outside." Touch it again and it closes: "Let's go inside." The lamp
lights, the ball bounces, the cup wobbles. While each phrase plays, its chunks float above the object and light
up one after another, so the learner sees where a phrase comes apart without being told.

There are no questions, no right answers, no scores, no timers and no rewards. Touching the same thing forty
times is fine. Nothing on the learner's screen can delete anything, buy anything, or leave the device.

## What a caregiver does

1. **Make a profile.** A name, a starter pack, a look. One minute.
2. **Record the phrases in your own voice.** Hold any object for two seconds, hold the big button, say the
   phrase, let go, hear it back, keep it. Until you do, the device's own voice fills in.
3. **Hand it over.**

Everything stays on the device. There is no account, no network and no analytics.

## Why it is built this way

Learners who process language in gestalts are harmed by drilling, flashcards and question-heavy teaching, and
helped by hearing short, natural phrases in familiar voices attached to real things. The phrases ship in chunks
an adult can recombine ("Let's go" + "outside", "Let's go" + "in the car"), which is the move from echoing a
phrase to owning its parts. The thinking, and the rules that follow from it, are in
[`docs/design.md`](docs/design.md). The framework behind the chunks is Natural Language Acquisition (Blanc).

Nothing about one child is in the code. A profile, a starter pack and a style preset carry everything, so one
install serves a family, a classroom or a caseload ([`docs/profiles.md`](docs/profiles.md)).

## Status

Early and usable. One room with eight objects, a plain board for phrases with no object, three looks, and
recording in your own voice. Coming: more rooms and reactions, the learner's own songs and clips, a remix board
that offers chunk beginnings beside chunk endings, and a bank view for caregivers. Desktop only until an export
preset exists; the target device is a tablet.

## For developers

**Godot 4.7**, GDScript only, strict typing promoted to errors. Organized around a `justfile`.

```sh
just setup     # the import pass that registers every class; run once after cloning
just editor    # open the project
just run       # profile picker, then the room
just lint      # headless project load; fails on script errors
just test      # the unit suites, about a second
just check     # doc caps, lint, tests, the room probe
```

Godot is found through `GODOT_BIN`, then `godot` on PATH, then `/Applications/Godot.app` on macOS.
[`docs/dev-setup.md`](docs/dev-setup.md) has the rest, including the Claude Code hook and MCP servers.

| Path | Holds |
| --- | --- |
| `scenes/` | `main.tscn`, the adults' `ui/profile_picker.tscn` and `ui/record_overlay.tscn`, the learner's `child/home.tscn`, `child/room_view.tscn` and `child/gestalt_tile.tscn`. |
| `scripts/profiles/` | The data model: `Profile`, `Gestalt`, `Room`, `Spot`, `Board`, `NlaStage`, `Starter`, `JsonValue`, `ProfileRepo`, the `ProfileStore` autoload. |
| `scripts/style/` | `StylePreset` (a resource) and the `Style` autoload that turns one into a Theme. |
| `scripts/speech/` | `Speaker` (a recording, else OS text to speech) and `Recorder` (the microphone). |
| `scripts/child/` | The learner's screens: `ChildHome`, `RoomView`, `SpotView`, `GestaltTile`. |
| `scripts/ui/` | Adult-facing screens and shared controls: `ProfilePicker`, `RecordOverlay`, `HoldButton`. |
| `starters/` | Starter packs as JSON. `blank` and `home_routines` ship. |
| `styles/` | Style presets as `.tres`. `calm`, `bold` and `quiet` ship. |
| `tests/unit/` | Hand-rolled suites, one per pure class. `tools/instr/` holds the scene probes. |
| `docs/` | [`design.md`](docs/design.md), [`profiles.md`](docs/profiles.md), [`dev-setup.md`](docs/dev-setup.md), [`gates.md`](docs/gates.md). |

`CLAUDE.md` carries the durable rules for anyone, person or agent, working in the repository. This README is
capped at 16 kB by `tools/check-doc-size.sh`; depth lives in `docs/`.

### Adding a room

A room is JSON in a starter pack: spots with a `kind` (what it looks like), a `reaction` (what it does), a
position, a size, and the gestalt it says. No art is needed; every kind is drawn from primitives. The fields are
listed in [`docs/profiles.md`](docs/profiles.md). A new kind of object is a `Spot.Kind` value and a `_draw`
arm in `SpotView`.

### Exports

No `export_presets.cfg` is committed yet. The preset must include `*.json` in its export filter, or a shipped
build has no starter packs, and the iOS and Android presets need a microphone permission.

## License

**MIT OR Apache-2.0**, at your option. See [LICENSE](LICENSE). Contributions are dual-licensed the same way.
Inbound equals outbound; no CLA.

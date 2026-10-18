# Alex

Scenes to explore and phrases to tap, spoken in voices the learner knows.

Alex Language EXplorer is a small app for children who acquire language in whole chunks: autistic
children, children with developmental delays, and any child whose first speech is echolalia. It is not a
clinical tool and not a substitute for one. It is something a learner can pick up and discover on their own,
after a caregiver spends a few minutes setting it up.

![The bedroom in the Bold style: the door swung open on the left wall as "Let's go outside" floats in chunks, a lamp, a bed under the window, a cup on the nightstand, a rug with a ball on it, and shoes by the door](docs/img/room.png)

## Contents

- [What the learner sees](#what-the-learner-sees)
- [What a caregiver does](#what-a-caregiver-does)
- [Why it is built this way](#why-it-is-built-this-way)
- [Status](#status)
- [Get Alex](#get-alex)
- [For developers](#for-developers)
- [Glossary](#glossary)
- [Research](#research)
- [Privacy](#privacy)
- [License](#license)

## What the learner sees

The learner moves between two modes, Explore and Words.

- **Explore** is a 3D scene of everyday objects. Touching an object plays its reaction and says its phrase
  in a familiar voice.
- **Words** holds every phrase. Palette is a column of phrase tiles, and tapping a tile says its phrase.
  Build offers the beginnings of phrases beside their endings. Tapping a chunk puts it on a strip and says
  it, and tapping the strip says the whole. The chunks your phrases say next carry a border.
- **Chunks** show on colored pills while a phrase plays, and each is marked as it is spoken. A chunk keeps
  its color everywhere it appears, so "Let's go" looks the same on every tile and caption.
- **Views** look at the scene from the front and from above, and a drag or a pinch moves in closer. A
  caregiver can add a third view that stands the learner in the middle of the room to look around, or
  remove all of them. A tap on a view's button puts it back, and a room left alone returns to the front.

Four scene packs ship. The bedroom's door opens to "Let's go outside" and closes to "Let's go inside"; the
bathroom's tub fills to "Water on"; the playroom says single words; the kitchen says short sentences. A
profile starts with one pack and adds others from the adults' screen. Scenes, objects and phrases are data
in a pack, so a pack can describe any place.

There are no questions, no right answers, no scores, no timers and no rewards. Touching the same thing forty
times is fine. Nothing on the learner's screen can delete anything, buy anything, or leave the device.

## What a caregiver does

1. **Make a profile.** A name, a starter pack, a look.
2. **Record the phrases in your own voice.** Hold any object or phrase for two seconds, then hold the big button
   and speak.
3. **Record the name.** Hold the profile name.
4. **Hand it over.** The app reopens this profile next time.

The **Caregiver guide** on the profile picker covers everything else, from reaching caregiver mode to recording
each part of a phrase and deleting a profile. The same text is [GUIDE.md](GUIDE.md).

![The recording overlay: the phrase as pills, whole and by chunk, a round microphone button, and "Hold the button, say it, let go."](docs/img/record.png)

New recordings get local noise reduction, quiet-end trimming, and volume balancing before preview.

Everything stays on the device. There is no account, no network and no analytics.

## Why it is built this way

Echolalia is communication, not noise. Repeated phrases carry requests, protests, turn-taking and
self-regulation [[1]](#research), [[2]](#research). Questions and demands draw more echoing and less original
speech from autistic children than comments do, which is why the app asks nothing and only offers
[[3]](#research). Whether echolalia should be reduced at all is contested, and the reviews find little evidence
for the interventions that try [[4]](#research), [[5]](#research). Alex does not try: it plays the learner's
phrases back in familiar voices, attached to things they can act on, and lets repetition run.

The phrases ship in chunks an adult can recombine ("Let's go" + "outside", "Let's go" + "in the car"). That idea
comes from the Natural Language Acquisition framework [[6]](#research), [[7]](#research), which describes
language growing from whole gestalts to flexible sentences. The framework's clinical claims are debated and its
protocol has no empirical evaluation yet [[8]](#research), [[9]](#research), [[10]](#research). Alex uses the
chunking as a design heuristic for making seams visible, not as a treatment, and nothing in the app depends on
the stage model being right. The thinking, and the rules that follow from it, are in
[`docs/design.md`](docs/design.md).

Nothing about one child is in the code. A profile, a starter pack and a style preset carry everything, so one
install serves a family, a classroom or a caseload ([`docs/profiles.md`](docs/profiles.md)).

## Status

Early and usable.

- **Ships:** four scene packs, a bedroom, a bathroom, a playroom and a kitchen, that a profile can add,
  remove and open on, a Words palette and a chunk builder, three looks, and recording in your own voice, by
  phrase or by chunk.
- **Coming:** moving between a profile's rooms, more objects and reactions, the learner's own songs and
  clips, and a bank view for caregivers.
- **Runs on:** Android and iOS phones and tablets, macOS, Windows and Linux. Recording is tried on an Android
  phone and an iPhone.

## Get Alex

- **Linux, Windows, macOS and an Android APK** are on the
  [releases page](https://github.com/crashtestbrandt/alex/releases/latest).
- **Google Play** is in a closed test. To join it on Android:
  1. Join the [alex-testers group](https://groups.google.com/g/alex-testers) with your phone's Google account.
  2. Open the [testing page](https://play.google.com/apps/testing/io.github.crashtestbrandt.alex) and choose
     **Become a tester**.
  3. Install [Alex from Google Play](https://play.google.com/store/apps/details?id=io.github.crashtestbrandt.alex).
- **iPhone and iPad** builds are in a TestFlight beta. Open the [TestFlight link](https://testflight.apple.com/join/2AYBxYbr)
  on the device and accept. A new build arrives in the TestFlight app.

## For developers

**Godot 4.7**, GDScript only, strict typing promoted to errors. Organized around a `justfile`.

```sh
git lfs pull   # application artwork
just setup     # the import pass that registers every class; run once after cloning
just editor    # open the project
just run       # profile picker, then the learner's screen
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
| `scripts/style/` | `StylePreset` (a resource), the `Style` autoload that turns one into a Theme, and `ChunkColors`. |
| `scripts/speech/` | `Speaker` (the whole take, else chunk takes, else OS text to speech), `Recorder` (the microphone) and `ChunkTakes` (a take per chunk, keyed by text). |
| `scripts/geometry/` | Objects as recipes and the camera math: `Sdf`, `Mesher`, `Primitive`, `Recipe`, `RecipeBuilder`, `ObjectRecipes`, `Picker`, `CameraFraming`, `RoomSpace`. |
| `scripts/child/` | The learner's screens: `ChildHome`, `RoomView`, `SpotBody`, `ViewWidget`, `GestaltTile`. |
| `scripts/ui/` | Adult-facing screens and the field-drawn controls: `ProfilePicker`, `RecordOverlay`, `TakePill`, `SdfShape`, `SdfGlyph`, `SdfButton`, `SdfPanel`, `PillBar`, `HoldButton`, `CaregiverGate`, `ChunkRow`, `UiGeometry`. |
| `shaders/ui/` | `shape.gdshader` and `glyph.gdshader`, the two fields every control is drawn from. |
| `starters/` | Starter packs as JSON. `blank`, `home_routines`, `bath_time`, `play_room` and `snack_time` ship. |
| `styles/` | Style presets as `.tres`. `calm`, `bold` and `quiet` ship. |
| `tests/unit/` | Hand-rolled suites, one per pure class. `tools/instr/` holds the scene probes. |
| `store/` | The Google Play and App Store listings and their images. `just store-graphics` renders the images. |
| `docs/` | [`design.md`](docs/design.md), [`geometry.md`](docs/geometry.md), [`ui.md`](docs/ui.md), [`profiles.md`](docs/profiles.md), [`dev-setup.md`](docs/dev-setup.md), [`gates.md`](docs/gates.md), [`exports.md`](docs/exports.md), [`releases.md`](docs/releases.md). |

`CLAUDE.md` carries the durable rules for anyone, person or agent, working in the repository. This README is
capped at 16 kB by `tools/check-doc-size.sh`; depth lives in `docs/`.

### Adding content

A starter pack is JSON under `starters/`. No art and no code are needed.

- **Gestalts** are the phrases, authored with `|` chunk marks.
- **A room** is the Explore scene: spots with a `kind` (what it looks like), a `reaction` (what it does), a
  wall or a place on the floor, a size, and the gestalt it says.
- **Boards** list the gestalts Words shows.

Every object kind is built from primitives, with a distance field as its twin for picking and, later,
editing ([`docs/geometry.md`](docs/geometry.md)). The fields are listed in
[`docs/profiles.md`](docs/profiles.md). A new kind of object is a `Spot.Kind` value and a recipe function in
`ObjectRecipes`.

### Exports

```sh
just export-android   # one preset into build/<commit>/android/; also -play, -ios, -macos, -windows, -linux
just exports          # every preset, then check what each export holds
just run-ios          # export iOS and run it on the paired iPhone or iPad
just testflight       # export iOS, archive it and upload it for TestFlight
just release X.Y.Z    # tag main as vX.Y.Z; CI builds, signs and publishes it
```

Each needs the Godot export templates of the same version. Android also needs a JDK and an Android SDK, and iOS
needs Xcode and an Apple Developer Team ID. [`docs/exports.md`](docs/exports.md) has the setup, the signing and
the checks. [`docs/releases.md`](docs/releases.md) has the release workflow and its secrets.

## Glossary

The words the app, this README and the docs use, from "gestalt" and "chunk" to "take" and "look", are defined in
[GLOSSARY.md](GLOSSARY.md). The app shows the same text under **Glossary** on the profile picker.

## Research

What the claims above rest on. Peer-reviewed unless noted. The debate in 8 to 10 is live, and a reader deciding
how much weight to give the stage model should read both sides.

1. Prizant, B. M., & Duchan, J. F. (1981). The functions of immediate echolalia in autistic children. *Journal
   of Speech and Hearing Disorders*, 46(3), 241–249. [doi:10.1044/jshd.4603.241](https://doi.org/10.1044/jshd.4603.241)
2. Prizant, B. M., & Rydell, P. J. (1984). Analysis of functions of delayed echolalia in autistic children.
   *Journal of Speech and Hearing Research*, 27(2), 183–192. [doi:10.1044/jshr.2702.183](https://doi.org/10.1044/jshr.2702.183)
3. Rydell, P. J., & Mirenda, P. (1994). Effects of high and low constraint utterances on the production of
   immediate and delayed echolalia in young children with autism. *Journal of Autism and Developmental
   Disorders*, 24(6), 719–735. [doi:10.1007/BF02172282](https://doi.org/10.1007/BF02172282)
4. Blackburn, C., Tueres, M., Sandanayake, N., Roberts, J., & Sutherland, R. (2023). A systematic review of
   interventions for echolalia in autistic children. *International Journal of Language & Communication
   Disorders*, 58(6), 1977–1993. [doi:10.1111/1460-6984.12931](https://doi.org/10.1111/1460-6984.12931)
5. Cohn, E. G., McVilly, K. R., Harrison, M. J., & Stiegler, L. N. (2022). Repeating purposefully: Empowering
   educators with functional communication models of echolalia in autism. *Autism & Developmental Language
   Impairments*, 7. [doi:10.1177/23969415221091928](https://doi.org/10.1177/23969415221091928)
6. Peters, A. M. (1983). *The Units of Language Acquisition.* Cambridge University Press. The source of the
   gestalt versus analytic distinction in typical language development.
7. Blanc, M. (2012). *Natural Language Acquisition on the Autism Spectrum: The Journey from Echolalia to
   Self-Generated Language.* Communication Development Center. Not peer-reviewed; the origin of the six stages.
8. Haydock, A., Harrison, L., Baldwin, K., & Leadbitter, K. (2024). Embracing gestalt language development as a
   fundamental neurodiversity-affirmative practice. *Autism*, 28(5), 1055–1059.
   [doi:10.1177/13623613241234598](https://doi.org/10.1177/13623613241234598). For the framework; see the
   response by Venker and Lorang (2025) in the same journal, [doi:10.1177/13623613241287577](https://doi.org/10.1177/13623613241287577).
9. Hutchins, T. L., Knox, S. E., & Fletcher, E. C. (2024). Natural language acquisition and gestalt language
   processing: A critical analysis of their application to autism and speech language therapy. *Autism &
   Developmental Language Impairments*, 9. Against the framework's theoretical footing.
10. Bryant, L., Bowen, C., Grove, R., Dixon, G., Beals, K., Shane, H., & Hemsley, B. (2024). Systematic review
    of interventions based on gestalt language processing and natural language acquisition (GLP/NLA): Clinical
    implications of absence of evidence and cautions for clinicians and parents. *Current Developmental
    Disorders Reports*, 12(2). [doi:10.1007/s40474-024-00312-z](https://doi.org/10.1007/s40474-024-00312-z).
    Found no empirical study of the protocol's effectiveness.
11. Stiegler, L. N. (2015). Examining the echolalia literature: Where do speech-language pathologists stand?
    *American Journal of Speech-Language Pathology*, 24(4), 750–762.
    [doi:10.1044/2015_AJSLP-14-0166](https://doi.org/10.1044/2015_AJSLP-14-0166). A survey of the disagreements.

## Privacy

Alex collects no personal data, and nothing leaves the device. See [PRIVACY.md](PRIVACY.md). In the app,
choose **Privacy policy** on the profile picker. The app shows the same file, offline.

## License

**MIT OR Apache-2.0**, at your option. See [LICENSE](LICENSE). Contributions are dual-licensed the same way.
Inbound equals outbound; no CLA.

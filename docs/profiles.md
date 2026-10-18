# Profiles, starters and styles

The configurability model. Nothing about one child is in code; it is all here.

## A profile on disk

```
user://profiles/<id>/
  profile.json     the Profile dictionary (Profile.to_dict)
  media/           whole-phrase recordings, named by Gestalt.recording
  media/chunks/    one take per chunk, named by Profile.chunk_takes
  media/name/      the name recording
```

`user://profiles/last_profile` holds the id of the profile opened last, which launch reopens.

`user://` is the app's data directory on the device. A family's recordings never leave it, and never enter
this repository.

| Field | Meaning |
| --- | --- |
| `schema` | `Profile.SCHEMA_VERSION`. `from_dict` migrates versions 1 to 6 forward before reading. |
| `id` | Directory name. `ProfileRepo.new_id()` makes one from the time plus a random suffix. |
| `display_name` | What the child's screen shows. |
| `name_recording` | Relative audio path for the name, or empty for OS speech. Added in schema 2. |
| `stage` | `NlaStage`, 0 for not staged. Every object says the phrase pair written for this stage (`Profile.says`). Edit sets it. |
| `scene_stages` | A scene's own stage, keyed by scene id, for a scene that does not follow the profile's. Edit pins it. Added in schema 7. |
| `notes` | Free text the adults keep with the profile. Edit sets it. Never on the learner's screen. Added in schema 6. |
| `style` | A preset id under `styles/`. |
| `starter` | The pack this profile was seeded from, for the record. |
| `scenes` | Every pack the profile holds, the starter first, in the order added. Added in schema 3. |
| `entry` | The scene Explore opens on, or empty for the first room. Added in schema 4. |
| `gestalts` | The bank. See below. |
| `rooms` | Explorable screens of spots. The first is the learner's Explore. See below. |
| `boards` | Lists of gestalt ids. Together they are the learner's Words tiles (docs/ui.md "The mode strip"). |
| `chunk_takes` | A take per chunk, keyed by the chunk's text (`ChunkTakes.key`), as a path under `media/chunks/`. Added in schema 5. |

A gestalt row:

| Field | Meaning |
| --- | --- |
| `id` | Unique within the profile. |
| `text` | Authored form with `|` chunk marks. `Gestalt.set_text` derives `chunks`. |
| `source` | Free text: a show, a song, a person. |
| `function` | `request`, `protest`, `comment`, `regulation`, `greeting`, `routine`, or `unknown`. |
| `stage` | The stage the gestalt models, 0 for unstaged. |
| `recording` | The whole-phrase take, a file under `media/`, or empty. `wav`, `ogg` or `mp3`. |

A room row holds `id`, `title`, `camera` and `spots`. `camera` is `fixed` (no view buttons), `views` (Front
and Top, with a pan and a zoom; the default) or `tilt` (adds Tilt, a look around from the room's center).
`orbit` in an older file reads as `tilt`. A room's and a board's `title` is for the adults. The learner's
strip reads Explore and Words. A spot row:

| Field | Meaning |
| --- | --- |
| `id` | Unique within the room. |
| `kind` | What it looks like: `door`, `light`, `window`, `ball`, `bed`, `cup`, `shoes`, `tub`, `star`, `table`, `circle`. Built from primitives (docs/geometry.md). |
| `reaction` | What it does when touched: `bounce`, `open`, `glow`, `spin`, `wobble`, `grow`. |
| `wall` | `none` for the floor (the default), or `back`, `left`, `right`. |
| `x` | Across the room for a floor spot, along the wall for a wall spot. 0 to 1. |
| `y` | Back to front for a floor spot, 0 at the back wall. Ignored on a wall. |
| `height` | The base of the object as a fraction of the room's height, 0 to 0.9: up a wall, or on top of something on the floor. A table's top is at 0.9 of its `size`. |
| `size` | The object's longest extent as a fraction of the room's width, 0.05 to 0.6. The camera pulls in a little when the smallest spot would fall under the touch floor, and picking honors the floor regardless. |
| `gestalt` | What it says. `alt_gestalt` is what it says toggled on. The pair every stage falls back to. |
| `stages` | A pair per stage, keyed `"1"` to `"6"`: `{"3": {"gestalt": "go_out", "alt_gestalt": "come_in"}}`. The spot says the pair written for the nearest stage at or below the scene's (`Spot.gestalt_at`). |
| `alt_gestalt` | What it says when toggled on (door open, light on). Optional. |

**A bad row is skipped, never fatal.** One malformed gestalt, spot or room does not lose a profile.

**A schema change is a migration function with a unit test**, taking the old dictionary to the new one.
Bump `SCHEMA_VERSION`, add the function, and have `from_dict` route older versions through it.

## Starter packs

JSON under `starters/`, one file per pack, the same gestalt and board rows as a profile:

```json
{
  "schema": 1,
  "id": "home_routines",
  "title": "Home routines",
  "description": "Shown in the picker.",
  "gestalts": [{"id": "lets_go_outside", "text": "Let's go | outside", "function": "routine", "stage": 1}],
  "boards": [{"id": "home", "title": "Home", "gestalts": ["lets_go_outside"]}]
}
```

A profile **copies** the pack at creation (`Starter.seed`) and never reads it again. Editing a pack changes
nothing for an existing child. `starter_test.gd` checks every shipped pack parses and that every board names
gestalts the pack holds.

`blank` and four scenes ship. A pack with at least one gestalt is a scene the adults' screen offers.

| Pack | Room | Starts with |
| --- | --- | --- |
| `home_routines` | A bedroom | Everyday routines |
| `bath_time` | A bathroom | The routine around a bath |
| `play_room` | A playroom | Playtime, and the single words a child says alone |
| `snack_time` | A kitchen | Mealtime |

Every spot in every pack carries a phrase pair for stages 3 and 4 beside the pair it starts with, so the
profile's stage changes what each object says (docs/design.md "Progression"). `starter_test.gd` fails a
spot without them.

Every row in a scene carries the `stage` of language it models (docs/design.md "Progression"). The stage
informs the adults and gates nothing. A pack author sets it by this rule, reading the pack in row order:

| Row | Stage |
| --- | --- |
| A phrase learned whole, with bars so it can be split later (`Let's go \| outside`), or with none (`All done`) | 1 |
| A phrase that reuses a beginning or an ending a stage 1 or 2 row before it holds (`Let's go \| in the car` after `Let's go \| outside`) | 2 |
| One or two single-word chunks (`Juice`, `More \| juice`) | 3 |
| A sentence of three or more single-word chunks (`I \| want \| more \| juice`) | 4 |

- `starter_test.gd` fails a scene row with no stage, a stage 1 row that reuses a chunk, a stage 2 row that
  reuses nothing, a stage 3 row with more than two chunks or a chunk of several words, and a stage 4 row
  with fewer than three chunks or a chunk of several words.
- A pack holds one row per spoken phrase. A stage 3 pair and a stage 4 pair are their own rows, each at
  that stage.

### Adding a scene

Edit on the adults' screen lists every shipped scene with Add. `Starter.add_to` copies the pack into the
profile and records its id in `scenes`:

- Every copied gestalt, room and board id is prefixed with the pack id: `bath_time.lets_get_in_the_tub`.
  A gestalt id names a recording file, so the separator is a dot.
- A phrase the bank already says, by its chunk key, is not copied. The pack's spots, at every stage, and
  its boards point at the bank's own gestalt, so one recording serves every scene that says the phrase.
- An added scene follows the profile's stage until Edit pins it.
- A pack is added once. A second Add changes nothing.
- A pack carries no recordings. A family's recordings never enter the repository.
- The bank is the union, so every added scene's phrases are in Words and in Build.

### Removing a scene

Edit shows Remove beside every scene the profile holds. `Profile.remove_scene` takes the scene out:

- Its rooms and boards are removed.
- Its phrases are removed unless another scene's room or board names them.
- Its stage pin is removed.
- A phrase with a recording stays in the bank. Adding the scene again reuses it, recording and all.
- The starter is a scene like any other and can be removed.
- `Profile.scene_of` names the scene behind an id. A scoped id is its pack's. Every other id is the starter's.

### The entry scene

Explore opens on the entry scene's first room (`Profile.explore_room`).

- Edit shows Start here beside every held scene with a room. The entry reads Starts here.
- With no entry, Explore opens on the profile's first room.
- Removing the entry scene clears the entry.

Packs are read with `DirAccess` at runtime. **Every export preset includes `starters/*.json`**, so a build
ships the packs under any export mode (docs/exports.md).

## Style presets

`.tres` resources under `styles/`, authored in the editor against `StylePreset`:

| Field | Meaning |
| --- | --- |
| `background`, `surface`, `accent`, `text` | The four interface colors. |
| `chunk_palette` | The fills a chunk's pill draws from, keyed by the chunk's text (docs/ui.md "Chunk colors"). Each must carry `text` at 4.5:1. |
| `wood`, `cloth`, `metal`, `glass`, `water`, `floor_color`, `wall_color` | What a room and its objects are made of. |
| `font_scale` | Multiplies every font size. |
| `motion` | `FULL`, `REDUCED` or `NONE`. Every tween multiplies by `Style.motion_scale()`; zero skips it. |
| `corner_radius` | Tile and panel corners. |
| `tile_min_size` | The smallest tile, in pixels. 160 is the floor. |
| `relief` | How far every shape stands off the screen, 0 flat to 1. The lit rim and the shadow (docs/ui.md). |

`Style.apply` builds a Theme from the preset at runtime and sets it on the root window. There is no theme
file to keep in step. `calm`, `bold` and `quiet` ship; a fourth is a new `.tres`.

- **New profile** opens the creation form. With no saved profiles, the form opens directly.
- Use **Look** in an existing profile's row to edit its saved style. Style pills preview immediately. **Save** updates that profile and opens it.
- **Back** or Escape discards the preview and restores the preceding screen style. Other profiles and recordings are unchanged.

## Recordings

Hold any spot, tile, Build chunk or the Build strip for two seconds to open the recording overlay. The
overlay shows the phrase as its pills: one for the whole phrase, and one per chunk when there is more than
one. A tap on a pill picks what the big button records. The whole is picked on open. Hold the big button,
say it, let go, hear it back, press Keep. Keep saves the picked pill and leaves the overlay open on the
phrase. Back closes it. Nothing is written before Keep, and the overlay closes itself after twenty idle
seconds.

| Hold on | Opens the recorder on |
| --- | --- |
| An object in Explore | The phrase the object said last. |
| A tile in Palette | That tile's phrase. |
| A chunk in Build | That one chunk, with no other pills. |
| The strip in Build | The strip's chunks. A strip that is a bank phrase opens on that phrase. |

- A whole-phrase take is `media/<gestalt id>.wav` (`Recorder.save`), with the previous take beside it as
  `<gestalt id>.prev.wav`. `Gestalt.recording` names it.
- A chunk take is `media/chunks/<key letters>-<key hash>.wav` (`ChunkTakes.save`), with the previous take
  beside it. `Profile.chunk_takes` maps the chunk's key to it. The key is the chunk's text, lowercased and
  trimmed, the same key as its color, so one take serves every phrase the chunk appears in and every strip
  Build assembles.
- A pill with a take carries a microphone mark. Picking it shows **Hold to remove this recording**. The
  hold removes the take and its previous take, and the OS voice says that part again.
- `Speaker` plays the whole-phrase take when one exists. Otherwise it plays each chunk's take in order with
  a short gap, and the OS voice for a chunk with no take. A phrase with no take at all is said whole by the
  OS voice for the device's language.
- Build plays a chunk's take as it lands on the strip, and the whole-phrase take when the strip is a bank
  phrase.
- A pack carries no takes. Version 3 profiles migrate with an empty take map and their whole-phrase
  recordings kept.

The microphone needs `audio/driver/enable_input` (on in `project.godot`). The Android, iOS and macOS presets
declare it, and iOS records under the Play and Record audio session (docs/exports.md). macOS asks the first
time.

### Name and recording cleanup

- Tap the profile name to hear it. Hold it for two seconds to record it.
- Name takes use `media/name/name.wav` and `name.prev.wav`, separate from the phrase bank.
- Version 1 profiles migrate without changing existing phrases, rooms or recordings.
- Holding a room object records its last spoken phrase. Before the first tap, it records the first phrase.
- New takes are cleaned before preview. Keep saves exactly the previewed audio.
- Cleanup removes low-frequency rumble and reduces steady background noise using a quiet part of the take.
- Continuous speech without a quiet interval skips noise estimation. This is not voice isolation; other speakers and changing background sounds can remain.
- Only leading and trailing quiet are trimmed, with 100 ms padding. Internal pauses remain.
- Speech levels are balanced with a 4× gain limit and peak headroom. Short edge fades prevent clicks.
- Stereo capture uses the stronger channel and saves mono, so inverted channels cannot cancel the voice.
- Silent takes are rejected. Existing recordings are changed only after Keep.

### Permanent deletion

- Open the caregiver profile picker, choose Edit beside the profile, then hold “Hold 3 seconds to delete”.
- The three-second hold removes the entire profile directory, including phrases, rooms, boards, name recordings, previous takes and hidden files.
- There is no Trash entry or undo. Other profiles are unchanged.
- Deleting the active profile also discards its loaded screen, recorder and playback references.
- The last deletion opens the new-profile form. A failed deletion stays on the edit screen with an error; the profile metadata is removed last so a media failure can be retried.
- Deletion accepts only a single profile directory name and never follows directory links.

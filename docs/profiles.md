# Profiles, starters and styles

The configurability model. Nothing about one child is in code; it is all here.

## A profile on disk

```
user://profiles/<id>/
  profile.json     the Profile dictionary (Profile.to_dict)
  media/           recordings, named by Gestalt.recording
```

`user://` is the app's data directory on the device. A family's recordings never leave it, and never enter
this repository.

| Field | Meaning |
| --- | --- |
| `schema` | `Profile.SCHEMA_VERSION`. `from_dict` migrates version 1 to version 2 before reading. |
| `id` | Directory name. `ProfileRepo.new_id()` makes one from the time plus a random suffix. |
| `display_name` | What the child's screen shows. |
| `name_recording` | Relative audio path for the name, or empty for OS speech. Added in schema 2. |
| `stage` | `NlaStage`, 0 for not staged. Informs the adults; gates nothing. |
| `style` | A preset id under `styles/`. |
| `starter` | The pack this profile was seeded from, for the record. |
| `gestalts` | The bank. See below. |
| `rooms` | Explorable screens of spots. See below. |
| `boards` | Plain screens of gestalt ids. |

A gestalt row:

| Field | Meaning |
| --- | --- |
| `id` | Unique within the profile. |
| `text` | Authored form with `|` chunk marks. `Gestalt.set_text` derives `chunks`. |
| `source` | Free text: a show, a song, a person. |
| `function` | `request`, `protest`, `comment`, `regulation`, `greeting`, `routine`, or `unknown`. |
| `stage` | The stage the gestalt models, 0 for unstaged. |
| `recording` | A file under `media/`, or empty. `wav`, `ogg` or `mp3`. |

A room row holds `id`, `title`, `camera` and `spots`. `camera` is `fixed` (no view buttons), `views` (Front
and Top, with a pan and a zoom; the default) or `tilt` (adds Tilt, a look around from the room's center).
`orbit` in an older file reads as `tilt`. A spot row:

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
| `gestalt` | What it says. |
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

Packs are read with `DirAccess` at runtime. **Every export preset includes `starters/*.json`**, so a build
ships the packs under any export mode (docs/exports.md).

## Style presets

`.tres` resources under `styles/`, authored in the editor against `StylePreset`:

| Field | Meaning |
| --- | --- |
| `background`, `surface`, `accent`, `text` | The four interface colors. |
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

Hold any spot or tile for two seconds to open the recording overlay for its gestalt. Hold the big button,
say the phrase, let go, hear it back, press Keep. `Recorder.save` writes `media/<gestalt id>.wav`, keeps the
previous take as `media/<gestalt id>.prev.wav`, and sets `Gestalt.recording`; the profile is saved. Nothing
is written before Keep, and the overlay closes itself after twenty idle seconds.

Until a recording exists, `Speaker` voices the gestalt with the OS text-to-speech voice for the device's
language.

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

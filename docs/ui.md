# Screen-space graphics

Everything drawn on the screen that is not the 3D room is a distance field: every button, panel, tile and bar
is `shaders/ui/shape.gdshader`, every icon is `shaders/ui/glyph.gdshader`, and text is the default font
rendered as a multichannel distance field (`gui/theme/default_font_multichannel_signed_distance_field`). No
StyleBoxFlat is drawn anywhere a user looks, and no image is loaded.

## Why a field

A field is evaluated per pixel, so an edge covers exactly its share of every pixel it crosses at every size and
scale, and a stroke thinner than a pixel draws at its own coverage instead of being floored up to one. The
coverage law is the one spaceman's HUD uses: `clamp(0.5 - sd / fw, 0, 1)` against the pixel's footprint. The
rim and the shadow are the same field read at an offset, not extra geometry.

## The geometry language

The shapes follow where platform interfaces have moved: rounded, concentric and floating. Three rules, all in
`UiGeometry` and pure:

- **Concentric corners.** A control inside a bar or a panel takes the outer radius minus the padding between
  them (`UiGeometry.concentric`), so the two curves share a center.
- **Pills.** A bar and the buttons in it are pills: the radius is half the shorter side.
- **Relief.** Every shape stands off the screen by a lit rim at its top edge and a soft shadow below. The
  style preset's `relief` scales both; `quiet` is nearly flat. Translucency and refraction are left out on
  purpose: they cost contrast, and contrast is what a learner with a visual or motor difference needs most.

## Floating over the room

The room renders edge to edge, and the chrome floats over it: the title, the mode strip and the profiles
button at the top, the view pill at the bottom right. The camera frames the room's objects into the band the
floating controls leave (`RoomView.safe_rect`, `CameraFraming.points_extent`, `CameraFraming.center_offset`),
so the walls may run under a control and an object never does. The frame includes each object's bounds and the floor footprint. Perspective depth and the camera offset are included in the fit.
`just room-probe` checks the full bounds inside the band.

Containers above the room are `MOUSE_FILTER_IGNORE`, so a tap between controls reaches the room; a pill bar
is `PASS`, so a tap on its padding does not.

## The mode strip

- The learner's strip has two pills, Explore and Words, in that order.
- Explore shows the profile's first room.
- Words shows the whole bank: the boards' phrases first, in board order, then the rest in bank order
  (`Profile.words_gestalts`). A room's phrases are in the bank, so they are in Words.
- A mode with nothing to show has no pill. With one pill, the strip hides.
- Room and board titles stay in profile data and never reach the learner's screen.
- Room choice inside Explore and a caregiver label for Explore wait until a profile has a second room.

## Words

Words has two modes on a glyph widget floating at the bottom right, like the room's view widget
(`WordsWidget`, a `GlyphBar`). The columns under it leave its height clear, so their last row scrolls above
it. Words reopens in the mode the learner last used.

- **Palette** is every phrase in the bank as a tile in a scrolling column. Tap says it. Hold records it.
- **Build** is a strip and two columns (`BuildView`). The left column holds the bank's beginnings, the first
  chunk of every phrase; the right holds its endings, every later chunk; each once by its color key
  (`ChunkBank`). Every chunk is a `ChunkButton` in its own color, at the tile floor.
- A tap on a chunk lands it on the strip and says it. A tap on the strip says the whole. A tap on a chunk in
  the strip takes it off. There is no send button and no clear button.
- A strip that says a phrase the bank holds is that phrase (`ChunkBank.find`), so it plays in the
  caregiver's voice. Any other strip is said as itself, by the OS voice until per-chunk takes exist (#24).
- The strip keeps what the learner built until they change it, across Explore and back.

## Chunk colors

- Every chunk has one color, keyed by its text. "Let's go" is the same color on every tile, caption and pack.
- The key is the chunk lowercased and trimmed.
- `ChunkColors` hashes the key into the style preset's `chunk_palette`. The hash is FNV-1a with the murmur3
  finalizer, 32 bits, pinned in `chunk_colors_test.gd`.
- Two chunks can share a color, about one pair in ten with a 10-color palette. A large bank makes that certain.
- The color fills a pill behind the chunk. The text keeps the preset's text color.
- Every palette color carries the text at 4.5:1 or better, at rest and brightened (`style_preset_test.gd`).
- A color carries identity only. Nothing about a chunk's function, stage or use picks it.
- The chunk being spoken grows by a tenth, times `Style.motion_scale()`. At motion NONE it brightens instead
  and keeps its size.
- The tile in Words and the caption in the room are both a `ChunkRow`.
- A caption has no card behind it. Its pills take the style's relief, so they stand off the room.
- A tile's pills sit flat on the tile.

## The controls

| Control | Extends | What it is |
| --- | --- | --- |
| `SdfShape` | `Control` | The field itself: fill, border, rim, shadow. Never takes input. |
| `SdfGlyph` | `Control` | One figure of the glyph shader: front, side, top, tilt, dots, microphone, palette, build. |
| `SdfButton` | `Button` | A Button with empty style boxes and an `SdfShape` behind its text. Hover adds a border, a press pulls the shape in, active fills with the accent. `shape` is rounded, pill or circle. `quiet` is a bar item. `danger` uses red with white text across styles. |
| `SdfPanel` | `PanelContainer` | A panel with an `SdfShape` behind its content, a larger radius, and `inner_radius()` for what sits in it. |
| `PillBar` | `MarginContainer` | A floating pill of quiet pill buttons in one toggle group: the mode strip. |
| `GlyphBar` | `PillBar` | A pill bar of glyph buttons, one of them the current state: the view widget, the Words widget. A glyph button is seven tenths of the tile floor, never under 96 px, and emits on every tap so the current one can reset. |
| `ChunkButton` | `SdfButton` | A chunk the learner taps in Build: a pill in its chunk's color at the tile floor, text in the style's text color. |
| `SdfField` | `LineEdit` | A text field with an `SdfShape` behind it; focus adds the accent border. |
| `HoldButton` | `SdfButton` | Fires only after a hold. Every adult screen sits behind one. |
| `ChunkRow` | `HFlowContainer` | A gestalt's chunks as wrapping pills, each an `SdfShape` in its chunk color. `play` marks each chunk in turn. `floating` gives the pills the style's relief. |

The background quad an `SdfShape` paints is the control grown by `SdfShape.PAD_PX` on each side, so the
shadow has room. It is drawn with `draw_texture_rect` over a white texture because a plain rect carries no UVs
for the shader to read.

## The profile picker

- The first screen lists profile rows. The name opens the profile; an inline Edit action opens its style and deletion controls.
- New profile opens a separate form. An empty profile list opens that form directly.
- The name is an `SdfField`. Starter and style choices use pill bars. Create or Save is the form's primary action.
- Hold the delete button for three seconds to permanently remove the selected profile and all recordings. Releasing early, scrolling, leaving the button or losing focus cancels the hold.
- Style pills preview immediately. Back discards the preview. Saving a look changes only the selected profile.
- Labels sit beside choices when their measured widths fit, and stack otherwise. Tall forms and lists scroll.
- Nothing on the picker is drawn by a theme style box.

## Gates

`ui_geometry_test.gd` covers the pure numbers. The shaders have no headless gate; `just screenshot` renders
`docs/img/room.png` (the Bold style, one object triggered), `docs/img/record.png` and `docs/img/picker.png`,
which is where they are checked. The picker image uses the probe's isolated fixture. It is ignored by git and stays local.

## Responsive layout

- `Main` preserves the window's aspect ratio. `UiGeometry.canvas_size` keeps its shorter logical side at least 640 units.
- Handheld devices can rotate. Small windows keep large controls without inheriting a landscape layout.
- Android and iOS use `DisplayServer.get_display_safe_area()`. `SafeArea` converts native window pixels through the inverse canvas transform once.
- Mobile layouts also reserve 6% of the shorter window side at each edge for rounded corners. Native insets and this minimum overlap; they are not added together.
- Headers, boards, profile forms, recording sheets, view controls, captions, and room objects stay inside those bounds. Backgrounds and the room viewport remain edge to edge.
- Insets refresh on resize, focus, and every 250 ms on mobile. A 180° turn or a system-bar change can update them without resizing.
- Desktop layouts use the full window and their existing control padding.
- Canvas scaling is uniform. Circular controls and view icons stay square; the 3D viewport keeps the display area's aspect ratio.
- The profile title truncates within the header. The mode strip wraps onto a separate row in narrow portrait windows.
- Mode and view bars select exactly one item. Keyboard focus has a visible border.
- Board columns follow the available width and the style's touch floor. Rows balance across columns.
- Long phrases wrap within tiles. Larger boards scroll without reducing touch targets. Swipes beginning on buttons reach their scroll container.
- `SdfSheet` centers caregiver forms, limits their line length, and scrolls tall content. `SdfScroll` draws its scrollbar with `SdfShape`.
- Recording actions wrap. Back and Create stay reachable after rotation and with long content.
- Profile rows keep their Look action inline. Creation and look editing have separate forms.
- Keyboard focus stays inside the recording overlay. Back and Escape restore focus to the initiating control.
- A scroll or lost window focus cancels a caregiver hold. Losing focus also cancels an unfinished recording.
- The current phrase has one caption. Repeated taps replace it; view changes clear it.
- Shadows remain dark in every style. Glyphs change color while pressed. Chunk text keeps the text color on its pill.

## Visual sweep

- `just layout-probe` checks six viewport shapes in all three styles, all four camera views, caption bounds, tile bounds, and scrolling.
- The sizes are 390×844, 844×390, 768×1024, 1280×800, 1920×1080, and 640×640.
- Profile forms also run at 1280×360, 800×240, 640×360, 390×280, and 640×640 in every style. Native wheel input must reach the bottom actions after resizing.
- Simulated phone and tablet bounds cover a portrait notch, camera island, left/right landscape cutouts, rounded corners, and gesture areas in every style. Probe-only masks make the exclusions visible in captures. Physical-device validation remains separate.
- A 320×568 stress case checks a long profile name, long room and board titles kept off the strip, a 30-phrase board, ten additional profiles, native wheel and drag scrolling, scroll-cancelled holds, and recording focus.
- `just visual-probe` saves room, caption, board, recording, review, and picker screenshots under `user://visual_probe_captures/`.
- Pass `--capture=<directory>` to the probe to choose a different screenshot directory.
- The probe uses an isolated profile repository and deletes its fixtures. It never records audio.
- These probes run locally. CI keeps its deterministic lint and unit-test gates.

## Words and application identity

- Words tiles keep a bounded width and their content height. They wrap into rows in a vertically scrolling column.
- The profile name is a hold-capable button: tap for speech, hold for recording.
- Its hit area fits the displayed name with 4 px padding. Long names truncate within the space left by the other header controls.
- Boot and native application artwork live in `assets/brand/`; see [branding.md](branding.md) for generation prompts.
- The room uses 4× MSAA and a 4096 px directional shadow map with medium soft filtering on desktop and mobile.
- Shadow filtering is configured separately from geometry anti-aliasing; see [Godot's project settings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-rendering-lights-and-shadows-directional-shadow-soft-shadow-filter-quality).

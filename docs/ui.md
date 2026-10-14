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

The room renders edge to edge, and the chrome floats over it: the title, the place pill and the profiles
button at the top, the view pill at the bottom right. The camera frames the room's objects into the band the
floating controls leave (`RoomView.safe_rect`, `CameraFraming.points_extent`, `CameraFraming.center_offset`),
so the walls may run under a control and an object never does. The frame includes each object's bounds and the floor footprint. Perspective depth and the camera offset are included in the fit.
`just room-probe` checks the full bounds inside the band.

Containers above the room are `MOUSE_FILTER_IGNORE`, so a tap between controls reaches the room; a pill bar
is `PASS`, so a tap on its padding does not.

## The controls

| Control | Extends | What it is |
| --- | --- | --- |
| `SdfShape` | `Control` | The field itself: fill, border, rim, shadow. Never takes input. |
| `SdfGlyph` | `Control` | One figure of the glyph shader: front, side, top, turn, dots, microphone. |
| `SdfButton` | `Button` | A Button with empty style boxes and an `SdfShape` behind its text. Hover adds a border, a press pulls the shape in, active fills with the accent. `shape` is rounded, pill or circle. `quiet` is a bar item. |
| `SdfPanel` | `PanelContainer` | A panel with an `SdfShape` behind its content, a larger radius, and `inner_radius()` for what sits in it. |
| `PillBar` | `MarginContainer` | A floating pill of quiet pill buttons in one toggle group: the place strip, the view widget. A view button is seven tenths of the tile floor, never under 96 px. |
| `SdfField` | `LineEdit` | A text field with an `SdfShape` behind it; focus adds the accent border. |
| `HoldButton` | `SdfButton` | Fires only after a hold. Every adult screen sits behind one. |

The background quad an `SdfShape` paints is the control grown by `SdfShape.PAD_PX` on each side, so the
shadow has room. It is drawn with `draw_texture_rect` over a white texture because a plain rect carries no UVs
for the shader to read.

## The profile picker

- The first screen lists profile rows. The name opens the profile; an inline Look action edits its style.
- New profile opens a separate form. An empty profile list opens that form directly.
- The name is an `SdfField`. Starter and style choices use pill bars. Create or Save is the form's primary action.
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
- The profile title truncates within the header. Place choices wrap onto a separate row in narrow portrait windows.
- Place and view bars select exactly one item. Keyboard focus has a visible border.
- Board columns follow the available width and the style's touch floor. Rows balance across columns.
- Long phrases wrap within tiles. Larger boards scroll without reducing touch targets. Swipes beginning on buttons reach their scroll container.
- `SdfSheet` centers caregiver forms, limits their line length, and scrolls tall content. `SdfScroll` draws its scrollbar with `SdfShape`.
- Recording actions wrap. Back and Create stay reachable after rotation and with long content.
- Profile rows keep their Look action inline. Creation and look editing have separate forms.
- Keyboard focus stays inside the recording overlay. Back and Escape restore focus to the initiating control.
- A scroll or lost window focus cancels a caregiver hold. Losing focus also cancels an unfinished recording.
- The current phrase has one opaque caption panel. Repeated taps replace it; view changes clear it.
- Shadows remain dark in every style. Glyphs and tile text change color while pressed.

## Visual sweep

- `just layout-probe` checks six viewport shapes in all three styles, all four camera views, caption bounds, tile bounds, and scrolling.
- The sizes are 390×844, 844×390, 768×1024, 1280×800, 1920×1080, and 640×640.
- Profile forms also run at 1280×360, 800×240, 640×360, 390×280, and 640×640 in every style. Native wheel input must reach the bottom actions after resizing.
- Simulated phone and tablet bounds cover a portrait notch, camera island, left/right landscape cutouts, rounded corners, and gesture areas in every style. Probe-only masks make the exclusions visible in captures. Physical-device validation remains separate.
- A 320×568 stress case checks a long profile name, long place titles, a 30-phrase board, ten additional profiles, native wheel and drag scrolling, scroll-cancelled holds, and recording focus.
- `just visual-probe` saves room, caption, board, recording, review, and picker screenshots under `user://visual_probe_captures/`.
- Pass `--capture=<directory>` to the probe to choose a different screenshot directory.
- The probe uses an isolated profile repository and deletes its fixtures. It never records audio.
- These probes run locally. CI keeps its deterministic lint and unit-test gates.

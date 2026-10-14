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

## The controls

| Control | Extends | What it is |
| --- | --- | --- |
| `SdfShape` | `Control` | The field itself: fill, border, rim, shadow. Never takes input. |
| `SdfGlyph` | `Control` | One figure of the glyph shader: front, side, top, turn, dots, microphone. |
| `SdfButton` | `Button` | A Button with empty style boxes and an `SdfShape` behind its text. Hover adds a border, a press pulls the shape in, active fills with the accent. `shape` is rounded, pill or circle. `quiet` is a bar item. |
| `SdfPanel` | `PanelContainer` | A panel with an `SdfShape` behind its content, a larger radius, and `inner_radius()` for what sits in it. |
| `PillBar` | `MarginContainer` | A floating pill of quiet pill buttons in one toggle group: the place strip, the view widget. |
| `HoldButton` | `SdfButton` | Fires only after a hold. Every adult screen sits behind one. |

The background quad an `SdfShape` paints is the control grown by `SdfShape.PAD_PX` on each side, so the
shadow has room. It is drawn with `draw_texture_rect` over a white texture because a plain rect carries no UVs
for the shader to read.

## What stays stock

`LineEdit`, `OptionButton`, `ItemList` and `HSeparator` on the profile picker keep the theme's style boxes.
They are adult-facing, used once at setup, and each would need its own field-drawn control to replace. They
are the only rasterized shapes left.

## Gates

`ui_geometry_test.gd` covers the pure numbers. The shaders have no headless gate; `just screenshot` renders
`docs/img/room.png` and `docs/img/record.png`, which is where they are checked.

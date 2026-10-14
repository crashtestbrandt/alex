# Geometry and views

How a room is built and seen: the room box, objects as recipes, the distance field that is each recipe's
twin, tap picking, and the camera. Everything here is `scripts/geometry/` plus `RoomView`, `SpotBody` and
`ViewWidget` under `scripts/child/`.

## The room

A room is a three-walled box, open at the front (`RoomView._build_shell`). Wall slabs surround the openings
defined by door and window recipes. The numbers live in `RoomSpace`:

| Constant | Value |
| --- | --- |
| `WIDTH` | 4.0 m across |
| `DEPTH` | 3.0 m front to back |
| `HEIGHT` | 2.6 m |
| `WALL` | 0.06 m thick |

The floor is `y = 0`, the back wall is at `-Z`, the open front faces `+Z`. The drawn shell is bigger than the
box: the floor and the side walls run `APRON` past the open front toward the camera, and every wall rises
`WALL_RISE` past the room's height, so the world reaches every edge of the screen instead of stopping at the
box. Spots and the camera's framing use the box; only the shell uses the apron and the rise. A spot's `x`, `y` and `height`
are fractions of this box, so a starter pack never names a meter. `RoomSpace.place` turns a spot into a
transform: a floor spot stands at `x` across and `y` back to front; a wall spot hangs on its wall at `x` along
it with its base at `height`, turned to face into the room. A wall hides while the camera stands outside it
(`RoomSpace.wall_hidden`), so the side view looks in.

Colors come from the style preset: `floor_color`, `wall_color`, and for the objects `wood`, `cloth`, `metal`,
`glass`, `water` beside the existing `accent`, `surface` and `text`.

## Objects are recipes

A `Spot.Kind` names a recipe, and `ObjectRecipes.make(kind, size_m, preset)` builds it. A `Recipe` is a list
of `Primitive`s grouped into named parts, each part with a pivot. The body is the part with the empty name.
`RecipeBuilder.build` turns a recipe into a `Node3D` with one `MeshInstance3D` per part at its pivot, so a
reaction can swing the `leaf` of a door by rotating one node.

Every object is built the way the thing is made, which is what makes a no-artist art path work (the idea is
spaceman's Forge and rivets' structures):

| Primitive | Mesh | Covers |
| --- | --- | --- |
| `REVOLVE` | a closed (radius, height) profile lathed around Y, with a crease rule | cup, lamp base and shade, ball, rug |
| `EXTRUDE` | a polygon in XY pushed along Z | door frame, star |
| `BOX` | hard, or every edge rounded | window bars, bed, tub walls, mattress, pillow, soles |
| `CAPSULE` | a lathe too | lamp stem, shoe uppers, faucet |
| `SPHERE` | a lathe too | bulb, knob, tub feet |
| `TORUS_ARC` | a tube swept along an arc, ends capped round | cup handle, ball seam |

Rules:

- **A recipe is a union.** Primitives overlap; nothing is subtracted or blended. That is the set of operations
  the mesh and the field both support today (below).
- **Transforms are rigid.** Rotation and translation only. A scaled primitive would put the mesh and the field
  out of step.
- **Nothing is random.** The same spot is the same object every time. Spaceman and rivets vary a build by
  seed; here sameness is the feature, so there is no seed.
- **One material.** Every mesh carries vertex colors and shares `RecipeBuilder.make_material()`. A glow part
  gets a duplicate with emission.
- **Base at `y = 0`, facing `+Z`.** A wall object has its back at `z = 0`.
- **`Recipe.height`** is where captions hang; `shown_when_on` names parts visible only while the spot is on
  (the tub's water); `glow_parts` names what a GLOW reaction lights.

Adding a kind is a `Spot.Kind` value, a `_<kind>` function in `ObjectRecipes`, and nothing else:
`object_recipes_test.gd` runs every kind through its checks.

## The field is the twin

Every primitive has an exact signed distance in `Sdf`, and `Primitive.distance` applies the inverse transform
and calls it. `Recipe.distance(p, part_transforms)` takes the minimum over primitives with each part where it
is right now, so an open door's leaf is found where it swung to. `mesher_test.gd` checks every primitive's
mesh vertices lie on its field's zero set, which is what keeps the two in step.

The field is used for:

- **Tap picking** (`Picker`). A ray from the camera is sphere-traced through each body's field and the nearest
  hit wins. When the ray hits nothing, `RoomView.pick_at` takes the nearest body whose center is within half
  the style's `tile_min_size`, so the touch floor holds even where the camera could not make an object that
  large.
- **An editor, later.** Plan and elevation views over a field, with drag-and-drop primitives, is the Tinkercad
  model. It is adult-facing, sits behind a hold, previews by raymarching the one object being edited, and
  writes nothing until Keep. Subtraction and smooth union arrive with it, baked to a mesh with surface nets the
  way spaceman bakes an asteroid, for the objects that use them.

Raymarching every object on the learner's screen was weighed and set aside: it costs per pixel, a cheap
tablet in a lap for an hour needs to run cool, and meshes get lighting, shadows and picking for free.

## Views

The learner's camera is always perspective. A room seen in perspective reads as a room; an orthographic front
view flattens it back into a picture. Orthographic projection stays in the framing math for the editor's plan
and elevation views.

`ViewWidget` offers up to three buttons, each seven tenths of `tile_min_size` square, with a 96-unit floor.
The bar wraps if needed. The camera reserves its height so objects stay clear of it. The pressed button is
the current view, and a tap on it resets that view. The room's `camera` field decides what shows:

| `camera` | Buttons | Drag | Pinch |
| --- | --- | --- | --- |
| `fixed` | none | nothing | nothing |
| `views` | Front, Top | pans | zooms |
| `tilt` | Front, Top, Tilt | pans, or turns in Tilt | zooms, or narrows in Tilt |

Front and Top are points on one orbit (`CameraFraming.view_angles`): Front at azimuth 0, Top at the
elevation limit. On either, zoom runs from the fit (`ZOOM_MIN`) to `ZOOM_MAX`, and the pan is clamped so the
visible frame never leaves the fitted frame (`clamp_pan`). A pinch zooms about the point under the fingers
(`zoom_about`). Tilt stands at `RoomSpace.tilt_origin`, the room's center at eye height, raised over any
floor object under it. Its yaw is free, its pitch is clamped (`clamp_tilt`), and its zoom is a field-of-view
change (`tilt_fov`). The camera is inside the box, so `RoomSpace.wall_hidden` keeps every wall in place. A
moved view returns to Front after `RoomView.IDLE_RESET_SECONDS` with nothing touched. At motion NONE a view
change is a cut.

Input rules (`RoomView._gui_input`):

- A tap on an object reacts and speaks. A two-second hold on an object opens the recorder.
- Movement past `DRAG_PX` cancels the hold and moves the view from wherever the press began, an object
  included. Release inside the threshold before the hold elapses is a tap.
- A second finger starts a pinch, which cancels the press. The pinch zooms by the fingers' distance and pans
  by their midpoint. On a desktop, the trackpad's magnify and pan gestures and the scroll wheel do the same.
- A room with `camera: fixed` moves nothing.

Framing (`CameraFraming`, pure):

- Native mobile safe bounds constrain the object frame, captions, and view widget. A side cutout shifts the camera frame horizontally. The full-screen viewport keeps its aspect ratio.
- `points_extent` fits the eight corners of every object's bounds and the floor footprint into the visible band.
- The calculation includes perspective depth, the asymmetric screen-space band, and the camera's horizontal and vertical offsets.
- Object bounds take priority over projected touch size. The nearest-object picking radius supplies the touch floor.
- `perspective_distance` turns the extent into a camera distance. `camera_transform` uses a continuous up vector through the orbit.
- Orthographic silhouette helpers remain available for a future editor.

## Openings and exterior

- `ObjectRecipes.opening` defines a clear rectangle behind each door and window frame.
- `RoomSpace.wall_sections` splits a wall into nonoverlapping rectangles around all openings. It clips edge openings and merges overlapping holes by repeated partitioning.
- The door swings outward into the garden. Its leaf keeps the same mesh and picking field.
- The window pane retains its picking field and uses a translucent material without casting an opaque shadow.
- A floor, path, and fixed arrangement of trees provide depth through the openings. The exterior uses the same primitive builders and style materials as the room.
- Upper wall extensions prevent a sky seam in portrait views. They do not cast shadows into the room.
- Changing rooms rebuilds the shell and its openings. Hiding a side wall hides all its sections together.

## Gates

| Suite | Checks |
| --- | --- |
| `sdf_test.gd` | every distance at known points, the axis rule, rounding never grows a box |
| `mesher_test.gd` | every mesh is closed, fronts outward, unit normals, vertices on the field, deterministic |
| `object_recipes_test.gd` | every kind builds, stands on the floor, fits its size, within the triangle budget, same fingerprint twice |
| `picker_test.gd` | nearest hit, the gap between objects, a swung part |
| `camera_framing_test.gd` | fit, zoom and pan limits, zoom about a point, Tilt's limits and basis, a continuous up vector |
| `room_space_test.gd` | placement per wall, facing, wall hiding, the smallest spot, where Tilt stands |

`just room-probe` picks every spot through its own screen point, taps it twice, walks the views, pans and
zooms past their limits, drags from an object, taps a pill to reset, turns Tilt past its limits, idles back
to the front, and switches to the board. `just screenshot` renders `docs/img/room.png`.

Fingerprints are compared within one run, not pinned across platforms: the builders use float trigonometry,
and a pinned hash would fail on a different libm rather than on a real change.

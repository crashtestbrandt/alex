extends RefCounted
class_name ObjectRecipes
## The recipe for each [Spot.Kind] (docs/geometry.md "Objects"). Every object is built the way the thing is
## made: a cup and a lamp shade are lathed, a door frame and a star are extruded, a mattress is a rounded
## box. Proportions come from the kind and `size_m`, the object's longest extent, and colors come from the
## style preset. Nothing is random: the same spot is the same object every time, which for this audience is
## the point.
##
## Every object stands with its base at y = 0 and faces +Z. A wall object has its back at z = 0.
##
## Adding a kind is a `Spot.Kind`, a `_<kind>` function here, and a row in `object_recipes_test.gd`.

static func make(kind: Spot.Kind, size_m: float, preset: StylePreset) -> Recipe:
	var r: Recipe = Recipe.new()
	r.name = Spot.kind_name(kind).capitalize()
	var s: float = maxf(size_m, 0.05)
	match kind:
		Spot.Kind.DOOR:
			_door(r, s, preset)
		Spot.Kind.LIGHT:
			_light(r, s, preset)
		Spot.Kind.WINDOW:
			_window(r, s, preset)
		Spot.Kind.BALL:
			_ball(r, s, preset)
		Spot.Kind.BED:
			_bed(r, s, preset)
		Spot.Kind.CUP:
			_cup(r, s, preset)
		Spot.Kind.SHOES:
			_shoes(r, s, preset)
		Spot.Kind.TUB:
			_tub(r, s, preset)
		Spot.Kind.STAR:
			_star(r, s, preset)
		Spot.Kind.TABLE:
			_table(r, s, preset)
		_:
			_circle(r, s, preset)
	return r

## The clear opening behind the frame, with a small overlap hidden by its bars.
static func opening(kind: Spot.Kind, size_m: float) -> Rect2:
	match kind:
		Spot.Kind.DOOR:
			return Rect2(-0.195 * size_m, 0.0, 0.39 * size_m, 0.97 * size_m)
		Spot.Kind.WINDOW:
			return Rect2(-0.40 * size_m, 0.05 * size_m, 0.80 * size_m, 0.80 * size_m)
		_:
			return Rect2()

static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))

static func _at_rotated(axis: Vector3, angle: float, x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(axis, angle), Vector3(x, y, z))

## A round rug: a thin lathed disc.
static func _circle(r: Recipe, s: float, preset: StylePreset) -> void:
	var radius: float = s / 2.0
	var thick: float = 0.02
	var profile: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(radius, 0.0), Vector2(radius, thick), Vector2(0.0, thick)])
	r.add(Primitive.revolve(profile, Transform3D.IDENTITY, preset.cloth))
	r.height = thick

## A door: an extruded U frame, a leaf hung on a hinge at the left jamb, a knob. `size` is the height.
static func _door(r: Recipe, s: float, preset: StylePreset) -> void:
	var width: float = 0.45 * s
	var jamb: float = 0.04 * s
	var depth: float = 0.06 * s
	var half_w: float = width / 2.0
	var frame: PackedVector2Array = PackedVector2Array([
		Vector2(-half_w, 0.0), Vector2(-half_w + jamb, 0.0), Vector2(-half_w + jamb, s - jamb),
		Vector2(half_w - jamb, s - jamb), Vector2(half_w - jamb, 0.0), Vector2(half_w, 0.0),
		Vector2(half_w, s), Vector2(-half_w, s)])
	r.add(Primitive.extrude(frame, depth, _at(0.0, 0.0, depth / 2.0), preset.wood))
	var leaf_w: float = width - 2.0 * jamb - 0.01 * s
	var leaf_h: float = s - jamb - 0.01 * s
	var hinge_x: float = -half_w + jamb
	r.set_pivot("leaf", Vector3(hinge_x, 0.0, depth / 2.0))
	r.add(Primitive.box(Vector3(leaf_w, leaf_h, depth * 0.5), _at(hinge_x + leaf_w / 2.0, leaf_h / 2.0 + 0.005 * s, depth / 2.0),
		preset.wood.lightened(0.12))).in_part("leaf")
	r.add(Primitive.box(Vector3(leaf_w * 0.6, leaf_h * 0.3, depth * 0.56), _at(hinge_x + leaf_w / 2.0, leaf_h * 0.72, depth / 2.0),
		preset.wood.darkened(0.1))).in_part("leaf")
	r.add(Primitive.box(Vector3(leaf_w * 0.6, leaf_h * 0.3, depth * 0.56), _at(hinge_x + leaf_w / 2.0, leaf_h * 0.28, depth / 2.0),
		preset.wood.darkened(0.1))).in_part("leaf")
	r.add(Primitive.sphere(0.022 * s, _at(hinge_x + leaf_w - 0.07 * s, 0.48 * s, depth / 2.0 + depth * 0.25 + 0.015 * s),
		preset.metal)).in_part("leaf")
	r.height = s

## A floor lamp: a lathed base, a stem, a hollow lathed shade, a bulb. `size` is the height.
static func _light(r: Recipe, r_s: float, preset: StylePreset) -> void:
	var s: float = r_s
	var base: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.1 * s, 0.0), Vector2(0.1 * s, 0.015 * s), Vector2(0.03 * s, 0.03 * s), Vector2(0.0, 0.03 * s)])
	r.add(Primitive.revolve(base, Transform3D.IDENTITY, preset.metal))
	r.add(Primitive.capsule(0.012 * s, 0.78 * s, _at(0.0, 0.41 * s, 0.0), preset.metal))
	var rb: float = 0.17 * s
	var rt: float = 0.1 * s
	var yb: float = 0.76 * s
	var yt: float = 1.0 * s
	var t: float = 0.012 * s
	var shade: PackedVector2Array = PackedVector2Array([
		Vector2(rb, yb), Vector2(rt, yt), Vector2(rt - t, yt), Vector2(rb - t, yb)])
	r.add(Primitive.revolve(shade, Transform3D.IDENTITY, preset.cloth)).in_part("shade")
	r.add(Primitive.sphere(0.045 * s, _at(0.0, 0.85 * s, 0.0), preset.surface)).in_part("bulb")
	r.glow_parts = PackedStringArray(["bulb", "shade"])
	r.height = s

## A window: four frame bars, a sill, a pane with a cross of mullions. `size` is the sill's width.
static func _window(r: Recipe, s: float, preset: StylePreset) -> void:
	var w: float = 0.92 * s
	var h: float = 0.9 * s
	var bar: float = 0.06 * s
	var depth: float = 0.05 * s
	var wood: Color = preset.wood
	r.add(Primitive.box(Vector3(w, bar, depth), _at(0.0, bar / 2.0, depth / 2.0), wood))
	r.add(Primitive.box(Vector3(w, bar, depth), _at(0.0, h - bar / 2.0, depth / 2.0), wood))
	r.add(Primitive.box(Vector3(bar, h, depth), _at(-w / 2.0 + bar / 2.0, h / 2.0, depth / 2.0), wood))
	r.add(Primitive.box(Vector3(bar, h, depth), _at(w / 2.0 - bar / 2.0, h / 2.0, depth / 2.0), wood))
	r.add(Primitive.box(Vector3(s, bar * 0.5, depth * 1.8), _at(0.0, bar * 0.25, depth * 0.9), wood))
	r.add(Primitive.box(Vector3(w - 2.0 * bar, h - 2.0 * bar, depth * 0.2), _at(0.0, h / 2.0, depth * 0.3), preset.glass)).in_part("pane")
	r.add(Primitive.box(Vector3(bar * 0.4, h - 2.0 * bar, depth * 0.6), _at(0.0, h / 2.0, depth / 2.0), wood))
	r.add(Primitive.box(Vector3(w - 2.0 * bar, bar * 0.4, depth * 0.6), _at(0.0, h / 2.0, depth / 2.0), wood))
	r.glow_parts = PackedStringArray(["pane"])
	r.height = h

## A ball with one seam ring. `size` is the diameter.
static func _ball(r: Recipe, s: float, preset: StylePreset) -> void:
	var radius: float = s / 2.0
	r.add(Primitive.sphere(radius, _at(0.0, radius, 0.0), preset.accent))
	var tilt: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(62.0)) * Basis(Vector3.BACK, deg_to_rad(20.0)), Vector3(0.0, radius, 0.0))
	r.add(Primitive.torus_arc(radius * 0.985, radius * 0.035, TAU, tilt, preset.surface))
	r.height = s

## A bed along X: a wooden base and headboard, a rounded mattress, a pillow, a blanket. `size` is the length.
static func _bed(r: Recipe, s: float, preset: StylePreset) -> void:
	var w: float = 0.55 * s
	var base_h: float = 0.14 * s
	r.add(Primitive.box(Vector3(s, base_h, w), _at(0.0, base_h / 2.0, 0.0), preset.wood))
	r.add(Primitive.box(Vector3(0.04 * s, 0.42 * s, w), _at(-s / 2.0 + 0.02 * s, 0.21 * s, 0.0), preset.wood))
	var mat_h: float = 0.1 * s
	r.add(Primitive.box(Vector3(s * 0.96, mat_h, w * 0.96), _at(0.0, base_h + mat_h / 2.0, 0.0), preset.cloth, 0.03 * s))
	var top: float = base_h + mat_h
	r.add(Primitive.box(Vector3(0.22 * s, 0.05 * s, w * 0.45), _at(-s / 2.0 + 0.17 * s, top + 0.025 * s, 0.0), preset.surface, 0.02 * s))
	r.add(Primitive.box(Vector3(s * 0.6, 0.035 * s, w * 0.98), _at(0.16 * s, top + 0.0175 * s, 0.0), preset.accent, 0.015 * s))
	r.height = 0.42 * s

## A cup: a hollow lathe and a handle that is an arc of a torus. `size` is the height.
static func _cup(r: Recipe, s: float, preset: StylePreset) -> void:
	var radius: float = 0.38 * s
	var wall: float = 0.06 * s
	var bottom: float = 0.08 * s
	var profile: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(radius * 0.9, 0.0), Vector2(radius, 0.1 * s), Vector2(radius, s), Vector2(radius - wall, s),
		Vector2(radius - wall, bottom), Vector2(0.0, bottom)])
	r.add(Primitive.revolve(profile, Transform3D.IDENTITY, preset.surface))
	var major: float = 0.2 * s
	var arc: float = deg_to_rad(200.0)
	var reach: float = major * absf(cos(arc / 2.0))
	var handle: Transform3D = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(radius - wall / 2.0 + reach, s / 2.0, 0.0))
	r.add(Primitive.torus_arc(major, 0.045 * s, arc, handle, preset.surface))
	r.height = s

## A pair of shoes side by side, toes toward +Z: a rounded sole and a capsule upper each. `size` is the
## pair's width.
static func _shoes(r: Recipe, s: float, preset: StylePreset) -> void:
	var shoe_w: float = 0.42 * s
	var length: float = 0.95 * s
	var sole_h: float = 0.07 * s
	var dark: Color = preset.text.lerp(preset.wood, 0.4)
	for side: int in [-1, 1]:
		var x: float = side * (shoe_w / 2.0 + 0.04 * s)
		r.add(Primitive.box(Vector3(shoe_w, sole_h, length), _at(x, sole_h / 2.0, 0.0), dark, 0.025 * s))
		var upper_r: float = 0.17 * s
		r.add(Primitive.capsule(upper_r, length * 0.45, _at_rotated(Vector3.RIGHT, PI / 2.0, x, sole_h + upper_r * 0.75, -0.02 * s), preset.accent))
		r.add(Primitive.capsule(0.14 * s, 0.08 * s, _at(x, sole_h + 0.2 * s, -0.3 * s), preset.accent))
	r.height = 0.38 * s

## A tub: a floor, four rounded walls, feet, a faucet, and water that shows while it is on. `size` is the
## length.
static func _tub(r: Recipe, s: float, preset: StylePreset) -> void:
	var w: float = 0.45 * s
	var h: float = 0.32 * s
	var t: float = 0.045 * s
	var feet: float = 0.04 * s
	var shell: Color = preset.surface
	r.add(Primitive.box(Vector3(s, 0.05 * s, w), _at(0.0, feet + 0.025 * s, 0.0), shell))
	r.add(Primitive.box(Vector3(s, h, t), _at(0.0, feet + h / 2.0, w / 2.0 - t / 2.0), shell, t * 0.4))
	r.add(Primitive.box(Vector3(s, h, t), _at(0.0, feet + h / 2.0, -w / 2.0 + t / 2.0), shell, t * 0.4))
	r.add(Primitive.box(Vector3(t, h, w), _at(s / 2.0 - t / 2.0, feet + h / 2.0, 0.0), shell, t * 0.4))
	r.add(Primitive.box(Vector3(t, h, w), _at(-s / 2.0 + t / 2.0, feet + h / 2.0, 0.0), shell, t * 0.4))
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			r.add(Primitive.sphere(feet, _at(sx * (s / 2.0 - 0.1 * s), feet, sz * (w / 2.0 - 0.08 * s)), preset.metal))
	r.add(Primitive.capsule(0.014 * s, 0.1 * s, _at(s / 2.0 - 0.08 * s, feet + h + 0.05 * s, 0.0), preset.metal))
	r.add(Primitive.capsule(0.014 * s, 0.08 * s, _at_rotated(Vector3.BACK, PI / 2.0, s / 2.0 - 0.12 * s, feet + h + 0.1 * s, 0.0), preset.metal))
	r.add(Primitive.box(Vector3(s - 2.0 * t, 0.02 * s, w - 2.0 * t), _at(0.0, feet + h * 0.72, 0.0), preset.water)).in_part("water")
	r.shown_when_on = PackedStringArray(["water"])
	r.height = feet + h

## A five-point star, extruded, standing on one tip. `size` is the width.
static func _star(r: Recipe, s: float, preset: StylePreset) -> void:
	var outer: float = s / 2.0
	r.add(Primitive.extrude(Mesher.star(5, outer, outer * 0.42), 0.1 * s, _at(0.0, outer, 0.0), preset.accent))
	r.height = s

## A small table: a top on four legs. `size` is the width; the top stands at 0.9 of it, which is the `height`
## a cup on it takes.
static func _table(r: Recipe, s: float, preset: StylePreset) -> void:
	var depth: float = 0.7 * s
	var top_y: float = 0.9 * s
	var thick: float = 0.05 * s
	var leg: float = 0.06 * s
	r.add(Primitive.box(Vector3(s, thick, depth), _at(0.0, top_y - thick / 2.0, 0.0), preset.wood, 0.01 * s))
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			r.add(Primitive.box(Vector3(leg, top_y - thick, leg), _at(sx * (s / 2.0 - leg), (top_y - thick) / 2.0, sz * (depth / 2.0 - leg)), preset.wood.darkened(0.1)))
	r.height = top_y

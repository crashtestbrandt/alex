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
## Adding a kind is a `Spot.Kind`, a `_<kind>` function here, covered automatically by `object_recipes_test.gd`.

static func make(kind: Spot.Kind, size_m: float, preset: StylePreset) -> Recipe:
	var r: Recipe = Recipe.new()
	r.name = Spot.kind_name(kind).capitalize()
	var s: float = maxf(size_m, 0.05)
	match kind:
		Spot.Kind.DOOR:
			_door(r, s, preset)
		Spot.Kind.LIGHT:
			_light(r, s, preset)
		Spot.Kind.PRIVACY_WINDOW:
			_privacy_window(r, s, preset)
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
		Spot.Kind.DINING_TABLE:
			_dining_table(r, s, preset)
		Spot.Kind.TABLE:
			_table(r, s, preset)
		Spot.Kind.SINK:
			_sink(r, s, preset)
		Spot.Kind.TOWEL:
			_towel(r, s, preset)
		Spot.Kind.SHELF:
			_shelf(r, s, preset)
		Spot.Kind.BOOK:
			_book(r, s, preset)
		Spot.Kind.SOFA:
			_sofa(r, s, preset)
		Spot.Kind.BOWL:
			_bowl(r, s, preset)
		Spot.Kind.CHAIR:
			_chair(r, s, preset)
		Spot.Kind.PLANT:
			_plant(r, s, preset)
		Spot.Kind.WALL_LIGHT:
			_wall_light(r, s, preset)
		_:
			_circle(r, s, preset)
	return r

## The clear opening behind the frame, with a small overlap hidden by its bars.
static func opening(kind: Spot.Kind, size_m: float) -> Rect2:
	match kind:
		Spot.Kind.DOOR:
			return Rect2(-0.195 * size_m, 0.0, 0.39 * size_m, 0.97 * size_m)
		Spot.Kind.WINDOW, Spot.Kind.PRIVACY_WINDOW:
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
	r.add(Primitive.torus_arc(radius * 0.88, 0.006, TAU, _at(0.0, thick, 0.0), preset.surface))
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
	# A folded edge and footboard give the bedding a readable silhouette.
	r.add(Primitive.box(Vector3(0.07 * s, 0.045 * s, w * 0.98), _at(-0.1 * s, top + 0.027 * s, 0.0), preset.accent.lightened(0.22), 0.012 * s))
	r.add(Primitive.box(Vector3(0.035 * s, 0.24 * s, w), _at(0.48 * s, 0.12 * s, 0.0), preset.wood, 0.008 * s))
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
		# Three broad straps distinguish the upper from the sole.
		for strap: int in 3:
			r.add(Primitive.box(Vector3(0.26 * s, 0.018 * s, 0.045 * s), _at(x, 0.33 * s, -0.12 * s + strap * 0.09 * s), preset.surface, 0.006 * s))
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
	# Aprons connect the legs beneath the top.
	for side: int in [-1, 1]:
		r.add(Primitive.box(Vector3(s - leg * 2.0, 0.09 * s, leg * 0.6), _at(0.0, top_y - 0.09 * s, side * (depth / 2.0 - leg)), preset.wood.darkened(0.06)))
	r.height = top_y

## A vanity with an open basin, a faucet and two cabinet doors. Size is its height.
static func _sink(r: Recipe, s: float, p: StylePreset) -> void:
	r.add(Primitive.box(Vector3(0.76, 0.64, 0.48) * s, _at(0, 0.32 * s, 0), p.wood, 0.015 * s))
	for side: int in [-1, 1]:
		r.add(Primitive.box(Vector3(0.35, 0.51, 0.025) * s, _at(side * 0.185 * s, 0.34 * s, 0.25 * s), p.wood.lightened(0.12)))
		r.add(Primitive.capsule(0.012 * s, 0.09 * s, _at(side * 0.06 * s, 0.42 * s, 0.28 * s), p.metal))
	r.add(Primitive.box(Vector3(0.86, 0.055, 0.58) * s, _at(0, 0.66 * s, 0), p.surface, 0.015 * s))
	for side: int in [-1, 1]:
		r.add(Primitive.box(Vector3(0.86, 0.10, 0.055) * s, _at(0, 0.73 * s, side * 0.26 * s), p.surface, 0.015 * s))
		r.add(Primitive.box(Vector3(0.055, 0.10, 0.52) * s, _at(side * 0.4 * s, 0.73 * s, 0), p.surface, 0.015 * s))
	r.add(Primitive.capsule(0.023 * s, 0.22 * s, _at(0, 0.86 * s, -0.20 * s), p.metal))
	r.add(Primitive.capsule(0.023 * s, 0.17 * s, _at_rotated(Vector3.RIGHT, PI / 2, 0, 0.97 * s, -0.12 * s), p.metal))
	r.add(Primitive.box(Vector3(0.73, 0.012, 0.44) * s, _at(0, 0.70 * s, 0), p.water)).in_part("water")
	r.shown_when_on = PackedStringArray(["water"])
	r.height = s

## A folded towel hanging over a wall rail. Its back sits at z = 0.
static func _towel(r: Recipe, s: float, p: StylePreset) -> void:
	for side: int in [-1, 1]:
		r.add(Primitive.box(Vector3(0.06, 0.06, 0.10) * s, _at(side * 0.44 * s, 0.71 * s, 0.05 * s), p.metal))
	r.add(Primitive.capsule(0.025 * s, 0.88 * s, _at_rotated(Vector3.BACK, PI / 2, 0, 0.71 * s, 0.10 * s), p.metal))
	r.add(Primitive.box(Vector3(0.65, 0.72, 0.065) * s, _at(0, 0.36 * s, 0.13 * s), p.cloth, 0.025 * s))
	for stripe: int in 2:
		r.add(Primitive.box(Vector3(0.60, 0.025, 0.008) * s, _at(0, (0.07 + stripe * 0.05) * s, 0.166 * s), p.accent))
	r.height = 0.75 * s

## A low bookcase with three shelves and visible book spines.
static func _shelf(r: Recipe, s: float, p: StylePreset) -> void:
	r.add(Primitive.box(Vector3(0.90, 1.0, 0.035) * s, _at(0, 0.5 * s, -0.14 * s), p.wood.darkened(0.13)))
	for side: int in [-1, 1]:
		r.add(Primitive.box(Vector3(0.055, 1.0, 0.32) * s, _at(side * 0.43 * s, 0.5 * s, 0), p.wood))
	for level: int in 4:
		r.add(Primitive.box(Vector3(0.90, 0.045, 0.32) * s, _at(0, (0.025 + level * 0.315) * s, 0), p.wood))
		if level == 3:
			continue
		for book: int in 4:
			var h: float = (0.20 + 0.02 * ((book + level) % 3)) * s
			var color: Color = p.accent if book % 2 == 0 else p.cloth
			var x: float = (-0.30 + book * 0.16) * s
			r.add(Primitive.box(Vector3(0.10 * s, h, 0.23 * s), _at(x, (0.05 + level * 0.315) * s + h / 2, 0.015 * s), color))
			r.add(Primitive.box(Vector3(0.065, 0.015, 0.008) * s, _at(x, (0.10 + level * 0.315) * s, 0.134 * s), p.surface))
	r.height = s

## An open picture book, with a spine, two page blocks and simple printed shapes.
static func _book(r: Recipe, s: float, p: StylePreset) -> void:
	r.add(Primitive.box(Vector3(1.0, 0.035, 0.66) * s, _at(0, 0.0175 * s, 0), p.accent, 0.01 * s))
	for side: int in [-1, 1]:
		r.add(Primitive.box(Vector3(0.46, 0.055, 0.60) * s, _at(side * 0.245 * s, 0.06 * s, 0), p.surface, 0.01 * s))
		r.add(Primitive.box(Vector3(0.24, 0.006, 0.20) * s, _at(side * 0.245 * s, 0.091 * s, -0.09 * s), p.cloth))
		for line: int in 3:
			r.add(Primitive.box(Vector3(0.28, 0.006, 0.012) * s, _at(side * 0.245 * s, 0.091 * s, (0.10 + line * 0.05) * s), p.accent))
	r.height = 0.10 * s

## A sofa with separate seat cushions, arms and short wooden feet.
static func _sofa(r: Recipe, s: float, p: StylePreset) -> void:
	for side: int in [-1, 1]:
		for end: int in [-1, 1]:
			r.add(Primitive.box(Vector3(0.07, 0.10, 0.07) * s, _at(side * 0.41 * s, 0.05 * s, end * 0.18 * s), p.wood))
	r.add(Primitive.box(Vector3(1.0, 0.16, 0.52) * s, _at(0, 0.17 * s, 0), p.cloth, 0.04 * s))
	r.add(Primitive.box(Vector3(0.98, 0.40, 0.12) * s, _at(0, 0.36 * s, -0.20 * s), p.cloth, 0.04 * s))
	for side: int in [-1, 1]:
		r.add(Primitive.box(Vector3(0.12, 0.28, 0.50) * s, _at(side * 0.44 * s, 0.30 * s, 0), p.cloth, 0.035 * s))
		r.add(Primitive.box(Vector3(0.36, 0.09, 0.38) * s, _at(side * 0.19 * s, 0.285 * s, 0.04 * s), p.cloth.lightened(0.10), 0.025 * s))
	r.add(Primitive.box(Vector3(0.22, 0.20, 0.09) * s, _at_rotated(Vector3.BACK, -0.15, -0.23 * s, 0.42 * s, -0.08 * s), p.accent, 0.025 * s))
	r.height = 0.56 * s

## A shallow hollow bowl with a rolled rim.
static func _bowl(r: Recipe, s: float, p: StylePreset) -> void:
	var profile: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(0.27, 0), Vector2(0.48, 0.25), Vector2(0.48, 0.28),
		Vector2(0.43, 0.28), Vector2(0.24, 0.06), Vector2(0, 0.06)])
	for i: int in profile.size():
		profile[i] *= s
	r.add(Primitive.revolve(profile, Transform3D.IDENTITY, p.surface))
	r.add(Primitive.torus_arc(0.455 * s, 0.025 * s, TAU, _at(0, 0.28 * s, 0), p.accent))
	r.height = 0.305 * s

## A dining chair with an open slatted back.
static func _chair(r: Recipe, s: float, p: StylePreset) -> void:
	for side: int in [-1, 1]:
		for end: int in [-1, 1]:
			var h: float = s if end == -1 else 0.48 * s
			r.add(Primitive.box(Vector3(0.055 * s, h, 0.055 * s), _at(side * 0.25 * s, h / 2, end * 0.23 * s), p.wood))
	r.add(Primitive.box(Vector3(0.60, 0.07, 0.56) * s, _at(0, 0.48 * s, 0), p.wood, 0.015 * s))
	r.add(Primitive.box(Vector3(0.50, 0.04, 0.46) * s, _at(0, 0.535 * s, 0), p.cloth, 0.015 * s))
	for slat: int in 2:
		r.add(Primitive.box(Vector3(0.50, 0.10, 0.045) * s, _at(0, (0.76 + slat * 0.16) * s, -0.23 * s), p.wood, 0.01 * s))
	r.height = s

## A potted plant with broad, rigid leaves.
static func _plant(r: Recipe, s: float, p: StylePreset) -> void:
	var profile: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(0.17, 0), Vector2(0.23, 0.34), Vector2(0, 0.34)])
	for i: int in profile.size():
		profile[i] *= s
	r.add(Primitive.revolve(profile, Transform3D.IDENTITY, p.wood))
	r.add(Primitive.capsule(0.018 * s, 0.55 * s, _at(0, 0.62 * s, 0), p.wood.darkened(0.2)))
	var leaf: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0.22), Vector2(0.25, 0.30), Vector2(0.22, 0.09)])
	for i: int in leaf.size():
		leaf[i] *= s
	for i: int in 5:
		var xf: Transform3D = Transform3D(Basis(Vector3.UP, i * 2.4), Vector3(0, (0.39 + i * 0.065) * s, 0))
		r.add(Primitive.extrude(leaf, 0.018 * s, xf, p.accent.lerp(p.cloth, 0.35)))
	r.height = s

## A wall sconce with a mounting plate and a frosted shade.
static func _wall_light(r: Recipe, s: float, p: StylePreset) -> void:
	r.add(Primitive.box(Vector3(0.50, 0.84, 0.06) * s, _at(0, 0.50 * s, 0.03 * s), p.metal, 0.02 * s))
	r.add(Primitive.box(Vector3(0.65, 1.0, 0.27) * s, _at(0, 0.50 * s, 0.18 * s), p.surface, 0.06 * s)).in_part("shade")
	r.glow_parts = PackedStringArray(["shade"])
	r.height = s

## Opaque frosted glazing with shallow flutes. It never receives the clear window's alpha material.
static func _privacy_window(r: Recipe, s: float, p: StylePreset) -> void:
	_window(r, s, p)
	for i: int in 7:
		r.add(Primitive.box(Vector3(0.012, 0.76, 0.008) * s, _at((-0.33 + i * 0.11) * s, 0.45 * s, 0.025 * s), p.glass.lightened(0.15))).in_part("pane")

## A dining table has a lower top than the narrow bedside table, at seated elbow height.
static func _dining_table(r: Recipe, s: float, p: StylePreset) -> void:
	var top: float = 0.62 * s
	r.add(Primitive.box(Vector3(1.0, 0.05, 0.70) * s, _at(0, top - 0.025 * s, 0), p.wood, 0.015 * s))
	for x: int in [-1, 1]:
		for z: int in [-1, 1]:
			r.add(Primitive.box(Vector3(0.06 * s, top - 0.05 * s, 0.06 * s), _at(x * 0.43 * s, (top - 0.05 * s) / 2.0, z * 0.28 * s), p.wood.darkened(0.08)))
	for side: int in [-1, 1]:
		r.add(Primitive.box(Vector3(0.88, 0.08, 0.04) * s, _at(0, top - 0.09 * s, side * 0.28 * s), p.wood))
	r.height = top

extends UnitTest
## [ObjectRecipes]: every kind builds, stands on the floor, stays inside its triangle budget, names the parts
## its reactions move, and builds the same object every time.

## The most triangles one object may carry. Rooms run on the mobile renderer on a tablet.
const TRIANGLE_BUDGET: int = 6000

var _preset: StylePreset = null

func setup() -> void:
	_preset = StylePreset.new()

func test_every_kind_builds_within_budget() -> void:
	for k: int in Spot.Kind.values():
		var kind: Spot.Kind = k as Spot.Kind
		var r: Recipe = ObjectRecipes.make(kind, 1.0, _preset)
		var label: String = Spot.kind_name(kind)
		assert_true(r.primitives.size() > 0, "%s has primitives" % label)
		var tris: int = r.triangle_count()
		assert_true(tris > 0 and tris <= TRIANGLE_BUDGET, "%s within budget (%d)" % [label, tris])
		var box: AABB = r.aabb()
		assert_true(box.position.y > -0.001, "%s stands on the floor (min y %.3f)" % [label, box.position.y])
		var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
		assert_true(longest <= 1.05, "%s longest extent is its size (%s)" % [label, box.size])
		assert_true(r.height > 0.0 and r.height <= 1.001, "%s reports a height" % label)

func test_size_scales_the_object() -> void:
	var small: AABB = ObjectRecipes.make(Spot.Kind.CUP, 0.5, _preset).aabb()
	var large: AABB = ObjectRecipes.make(Spot.Kind.CUP, 1.0, _preset).aabb()
	assert_almost_eq(large.size.y / small.size.y, 2.0, 0.01, "twice the size is twice the height")

func test_reaction_parts_exist() -> void:
	var door: Recipe = ObjectRecipes.make(Spot.Kind.DOOR, 2.0, _preset)
	assert_true(door.parts().has("leaf"), "a door has a leaf")
	assert_true(door.pivots.has("leaf"), "the leaf has a hinge")
	assert_true(door.pivot("leaf").x < 0.0, "the hinge is on the left jamb")
	var light: Recipe = ObjectRecipes.make(Spot.Kind.LIGHT, 1.7, _preset)
	for part: String in light.glow_parts:
		assert_true(light.parts().has(part), "lamp glow part %s exists" % part)
	var tub: Recipe = ObjectRecipes.make(Spot.Kind.TUB, 1.7, _preset)
	for part: String in tub.shown_when_on:
		assert_true(tub.parts().has(part), "tub on-only part %s exists" % part)

func test_a_part_moves_with_its_transform() -> void:
	var door: Recipe = ObjectRecipes.make(Spot.Kind.DOOR, 2.0, _preset)
	var closed: Dictionary[String, Transform3D] = {}
	var pivot: Vector3 = door.pivot("leaf")
	var swung: Dictionary[String, Transform3D] = {"leaf": Transform3D(Basis(Vector3.UP, -PI / 2.0), pivot)}
	# A point in front of the door, a leaf's width out from the hinge: air when closed, leaf when open.
	var probe: Vector3 = pivot + Vector3(0.0, 1.0, 0.6)
	assert_true(door.distance(probe, closed) > 0.05, "closed: the point in the room is air")
	assert_true(door.distance(probe, swung) < 0.02, "open: the leaf swung into the room")

func test_same_recipe_same_fingerprint() -> void:
	for k: int in Spot.Kind.values():
		var kind: Spot.Kind = k as Spot.Kind
		var a: String = ObjectRecipes.make(kind, 0.8, _preset).fingerprint()
		var b: String = ObjectRecipes.make(kind, 0.8, _preset).fingerprint()
		assert_eq(a, b, "%s builds the same twice" % Spot.kind_name(kind))

func test_colors_come_from_the_preset() -> void:
	var other: StylePreset = StylePreset.new()
	other.accent = Color.MAGENTA
	var ball: Recipe = ObjectRecipes.make(Spot.Kind.BALL, 0.5, other)
	assert_eq(ball.primitives[0].color, Color.MAGENTA, "the ball takes the accent")

extends UnitTest
## [Picker]: a ray through a recipe's field hits the nearest object, misses the gap between two, and sees a
## part where it is now rather than where it rests.

func _target(recipe: Recipe, at: Vector3) -> Picker.Target:
	var t: Picker.Target = Picker.Target.new()
	t.recipe = recipe
	t.transform = Transform3D(Basis.IDENTITY, at)
	var box: AABB = recipe.aabb()
	t.center = at + box.get_center()
	t.radius = box.size.length() / 2.0 + 0.05
	return t

func _ball(radius: float) -> Recipe:
	var r: Recipe = Recipe.new()
	r.add(Primitive.sphere(radius, Transform3D(Basis.IDENTITY, Vector3(0.0, radius, 0.0)), Color.WHITE))
	return r

func test_ray_sphere() -> void:
	var span: Vector2 = Picker.ray_sphere(Vector3(0, 0, 5), Vector3(0, 0, -1), Vector3.ZERO, 1.0)
	assert_almost_eq(span.x, 4.0, 0.0001, "entry")
	assert_almost_eq(span.y, 6.0, 0.0001, "exit")
	assert_eq(Picker.ray_sphere(Vector3(0, 3, 5), Vector3(0, 0, -1), Vector3.ZERO, 1.0).x, INF, "miss")
	assert_eq(Picker.ray_sphere(Vector3(0, 0, -5), Vector3(0, 0, -1), Vector3.ZERO, 1.0).x, INF, "behind the ray")

func test_hits_the_nearest_object() -> void:
	var near: Picker.Target = _target(_ball(0.5), Vector3(0.0, 0.0, 0.0))
	var far: Picker.Target = _target(_ball(0.5), Vector3(0.0, 0.0, -3.0))
	var targets: Array[Picker.Target] = [far, near]
	var origin: Vector3 = Vector3(0.0, 0.5, 5.0)
	assert_eq(Picker.pick(origin, Vector3(0, 0, -1), targets), 1, "the near ball")
	var t: float = Picker.march(origin, Vector3(0, 0, -1), near)
	assert_almost_eq(t, 4.5, 0.01, "at its front surface")

func test_misses_between_objects() -> void:
	var left: Picker.Target = _target(_ball(0.5), Vector3(-2.0, 0.0, 0.0))
	var right: Picker.Target = _target(_ball(0.5), Vector3(2.0, 0.0, 0.0))
	var targets: Array[Picker.Target] = [left, right]
	assert_eq(Picker.pick(Vector3(0.0, 0.5, 5.0), Vector3(0, 0, -1), targets), -1, "the gap is air")
	assert_eq(Picker.pick(Vector3(2.0, 0.5, 5.0), Vector3(0, 0, -1), targets), 1, "the right ball")

func test_a_moved_part_is_hit_where_it_is() -> void:
	var door: Recipe = ObjectRecipes.make(Spot.Kind.DOOR, 2.0, StylePreset.new())
	var target: Picker.Target = _target(door, Vector3.ZERO)
	target.radius += 1.0
	var pivot: Vector3 = door.pivot("leaf")
	# A ray straight down onto the floor in front of the door, a leaf's width out from the hinge.
	var origin: Vector3 = pivot + Vector3(0.0, 3.0, 0.6)
	var targets: Array[Picker.Target] = [target]
	assert_eq(Picker.pick(origin, Vector3.DOWN, targets), -1, "closed: nothing in front of the door")
	target.parts = {"leaf": Transform3D(Basis(Vector3.UP, -PI / 2.0), pivot)}
	assert_eq(Picker.pick(origin, Vector3.DOWN, targets), 0, "open: the leaf is there")

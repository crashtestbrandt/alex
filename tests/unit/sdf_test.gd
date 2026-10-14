extends UnitTest
## [Sdf]: every primitive's exact distance at known points, inside and out, including the axis rule a revolve
## needs and the box rounding that must never grow the box.

const EPS: float = 0.0001

func test_sphere() -> void:
	assert_almost_eq(Sdf.sphere(Vector3(2.0, 0.0, 0.0), 1.0), 1.0, EPS, "outside")
	assert_almost_eq(Sdf.sphere(Vector3.ZERO, 1.0), -1.0, EPS, "center")
	assert_almost_eq(Sdf.sphere(Vector3(0.0, 1.0, 0.0), 1.0), 0.0, EPS, "surface")

func test_box_hard() -> void:
	var half: Vector3 = Vector3(1.0, 2.0, 3.0)
	assert_almost_eq(Sdf.box(Vector3(3.0, 0.0, 0.0), half, 0.0), 2.0, EPS, "face distance")
	assert_almost_eq(Sdf.box(Vector3.ZERO, half, 0.0), -1.0, EPS, "center is the nearest face away")
	assert_almost_eq(Sdf.box(Vector3(2.0, 3.0, 0.0), half, 0.0), sqrt(2.0), EPS, "edge distance")

func test_box_rounding_never_grows() -> void:
	var half: Vector3 = Vector3(1.0, 1.0, 1.0)
	assert_almost_eq(Sdf.box(Vector3(1.0, 0.0, 0.0), half, 0.3), 0.0, EPS, "face center stays on the surface")
	assert_true(Sdf.box(Vector3(1.0, 1.0, 1.0), half, 0.3) > 0.0, "the corner is carved away")
	assert_almost_eq(Sdf.box(Vector3(1.0, 1.0, 1.0), half, 0.3), sqrt(3.0) * 0.3 - 0.3, EPS, "corner by the rounding radius")
	assert_almost_eq(Sdf.box(Vector3.ZERO, half, 5.0), -1.0, EPS, "rounding is clamped to the half extent")

func test_capsule() -> void:
	assert_almost_eq(Sdf.capsule(Vector3(0.0, 0.5, 0.0), 0.25, 0.5), -0.25, EPS, "on the axis inside the straight part")
	assert_almost_eq(Sdf.capsule(Vector3(0.0, 1.0, 0.0), 0.25, 0.5), 0.25, EPS, "beyond the cap")
	assert_almost_eq(Sdf.capsule(Vector3(1.0, 0.0, 0.0), 0.25, 0.5), 0.75, EPS, "beside the straight part")

func test_torus_arc() -> void:
	assert_almost_eq(Sdf.torus_arc(Vector3(1.0, 0.0, 0.0), 1.0, 0.2, TAU), -0.2, EPS, "tube center of a ring")
	assert_almost_eq(Sdf.torus_arc(Vector3(-1.0, 0.0, 0.0), 1.0, 0.2, TAU), -0.2, EPS, "the ring goes all the way round")
	assert_almost_eq(Sdf.torus_arc(Vector3(-1.0, 0.0, 0.0), 1.0, 0.2, PI), sqrt(2.0) - 0.2, EPS, "a half arc ends at the sides")
	assert_almost_eq(Sdf.torus_arc(Vector3(0.0, 0.0, 1.0), 1.0, 0.2, PI), -0.2, EPS, "the half arc reaches +Z")

func test_polygon() -> void:
	var square: PackedVector2Array = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	assert_almost_eq(Sdf.polygon(Vector2.ZERO, square), -1.0, EPS, "center")
	assert_almost_eq(Sdf.polygon(Vector2(2.0, 0.0), square), 1.0, EPS, "outside a side")
	assert_almost_eq(Sdf.polygon(Vector2(2.0, 2.0), square), sqrt(2.0), EPS, "outside a corner")
	var reversed: PackedVector2Array = square.duplicate()
	reversed.reverse()
	assert_almost_eq(Sdf.polygon(Vector2.ZERO, reversed), -1.0, EPS, "either winding")
	assert_eq(Sdf.polygon(Vector2.ZERO, PackedVector2Array([Vector2.ZERO, Vector2.ONE])), INF, "a degenerate polygon is INF")

func test_revolve_ignores_the_axis_edge() -> void:
	# A solid cylinder of radius 1, height 2, as a profile that closes along the axis.
	var cylinder: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 2), Vector2(0, 2)])
	assert_almost_eq(Sdf.revolve(Vector3(0.0, 1.0, 0.0), cylinder), -1.0, EPS, "the axis is deep inside, not a surface")
	assert_almost_eq(Sdf.revolve(Vector3(0.0, 3.0, 0.0), cylinder), 1.0, EPS, "above the top cap")
	assert_almost_eq(Sdf.revolve(Vector3(0.0, 1.0, 2.0), cylinder), 1.0, EPS, "outside the wall, any direction")

func test_revolve_hollow_cup() -> void:
	var cup: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 2), Vector2(0.8, 2), Vector2(0.8, 0.2), Vector2(0, 0.2)])
	assert_true(Sdf.revolve(Vector3(0.0, 1.0, 0.0), cup) > 0.0, "the inside of the cup is air")
	assert_almost_eq(Sdf.revolve(Vector3(0.0, 1.0, 0.0), cup), 0.8, EPS, "air up to the inner wall")
	assert_almost_eq(Sdf.revolve(Vector3(0.9, 1.0, 0.0), cup), -0.1, EPS, "inside the wall")

func test_extrude() -> void:
	var square: PackedVector2Array = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	assert_almost_eq(Sdf.extrude(Vector3.ZERO, square, 0.5), -0.5, EPS, "center, nearest the caps")
	assert_almost_eq(Sdf.extrude(Vector3(0.0, 0.0, 1.5), square, 0.5), 1.0, EPS, "in front of the cap")
	assert_almost_eq(Sdf.extrude(Vector3(2.0, 0.0, 0.0), square, 0.5), 1.0, EPS, "beside a side")

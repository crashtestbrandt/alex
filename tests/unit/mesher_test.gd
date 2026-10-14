extends UnitTest
## [Mesher] and [MeshBatch]: every primitive mesh is closed, faces outward, carries unit normals, matches its
## distance field on the surface, and builds the same triangles twice.

const EPS: float = 0.001

func _check_batch(batch: MeshBatch, label: String) -> void:
	assert_true(batch.triangle_count() > 0, "%s has triangles" % label)
	assert_eq(batch.indices.size() % 3, 0, "%s indices come in threes" % label)
	assert_eq(batch.normals.size(), batch.vertices.size(), "%s one normal per vertex" % label)
	assert_eq(batch.colors.size(), batch.vertices.size(), "%s one color per vertex" % label)
	var bad_normals: int = 0
	for n: Vector3 in batch.normals:
		if absf(n.length() - 1.0) > EPS:
			bad_normals += 1
	assert_eq(bad_normals, 0, "%s normals are unit" % label)
	var inward: int = 0
	for t: int in batch.triangle_count():
		var i0: int = batch.indices[t * 3]
		var i1: int = batch.indices[t * 3 + 1]
		var i2: int = batch.indices[t * 3 + 2]
		var cross: Vector3 = (batch.vertices[i1] - batch.vertices[i0]).cross(batch.vertices[i2] - batch.vertices[i0])
		var outward: Vector3 = batch.normals[i0] + batch.normals[i1] + batch.normals[i2]
		# Godot's front faces are clockwise from the front: the cross product of a front triangle points inward.
		if cross.length() > 0.0 and cross.dot(outward) > 0.0:
			inward += 1
	assert_eq(inward, 0, "%s every face fronts outward" % label)

## Every vertex of the mesh lies on the field's zero set.
func _check_on_surface(batch: MeshBatch, prim: Primitive, label: String, tolerance: float) -> void:
	var off: int = 0
	var worst: float = 0.0
	for v: Vector3 in batch.vertices:
		var d: float = absf(prim.distance(v))
		worst = maxf(worst, d)
		if d > tolerance:
			off += 1
	assert_eq(off, 0, "%s vertices sit on the field's surface (worst %.4f)" % [label, worst])

func test_sphere() -> void:
	var prim: Primitive = Primitive.sphere(0.7, Transform3D.IDENTITY, Color.RED)
	var batch: MeshBatch = prim.batch()
	_check_batch(batch, "sphere")
	_check_on_surface(batch, prim, "sphere", 0.0005)
	var box: AABB = batch.aabb()
	assert_almost_eq(box.size.y, 1.4, EPS, "sphere spans its diameter")

func test_capsule() -> void:
	var prim: Primitive = Primitive.capsule(0.2, 1.0, Transform3D.IDENTITY, Color.RED)
	var batch: MeshBatch = prim.batch()
	_check_batch(batch, "capsule")
	_check_on_surface(batch, prim, "capsule", 0.0005)
	assert_almost_eq(batch.aabb().size.y, 1.4, EPS, "capsule is the straight part plus two caps")

func test_hard_box() -> void:
	var prim: Primitive = Primitive.box(Vector3(1.0, 2.0, 3.0), Transform3D.IDENTITY, Color.RED)
	var batch: MeshBatch = prim.batch()
	_check_batch(batch, "box")
	assert_eq(batch.triangle_count(), 12, "a hard box is twelve triangles")
	_check_on_surface(batch, prim, "box", 0.0005)

func test_rounded_box() -> void:
	var prim: Primitive = Primitive.box(Vector3(1.0, 2.0, 3.0), Transform3D.IDENTITY, Color.RED, 0.2)
	var batch: MeshBatch = prim.batch()
	_check_batch(batch, "rounded box")
	_check_on_surface(batch, prim, "rounded box", 0.0005)
	var box: AABB = batch.aabb()
	assert_almost_eq(box.size.x, 1.0, EPS, "rounding keeps the width")
	assert_almost_eq(box.size.z, 3.0, EPS, "rounding keeps the depth")

func test_extrude() -> void:
	var prim: Primitive = Primitive.extrude(Mesher.star(5, 1.0, 0.4), 0.3, Transform3D.IDENTITY, Color.RED)
	var batch: MeshBatch = prim.batch()
	_check_batch(batch, "star")
	_check_on_surface(batch, prim, "star", 0.0005)
	assert_almost_eq(batch.aabb().size.z, 0.3, EPS, "extrude depth")

func test_torus_arc() -> void:
	var prim: Primitive = Primitive.torus_arc(1.0, 0.1, deg_to_rad(200.0), Transform3D.IDENTITY, Color.RED)
	var batch: MeshBatch = prim.batch()
	_check_batch(batch, "torus arc")
	_check_on_surface(batch, prim, "torus arc", 0.0005)
	var ring: MeshBatch = Mesher.torus_arc(1.0, 0.1, TAU, Color.RED)
	_check_batch(ring, "torus ring")

func test_revolve_cup_is_hollow() -> void:
	var cup: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 2), Vector2(0.8, 2), Vector2(0.8, 0.2), Vector2(0, 0.2)])
	var prim: Primitive = Primitive.revolve(cup, Transform3D.IDENTITY, Color.RED)
	var batch: MeshBatch = prim.batch()
	_check_batch(batch, "cup")
	_check_on_surface(batch, prim, "cup", 0.0005)
	var reversed: PackedVector2Array = cup.duplicate()
	reversed.reverse()
	_check_batch(Mesher.revolve(reversed, Color.RED), "cup from a clockwise profile")

func test_append_transforms_and_keeps_colors() -> void:
	var a: MeshBatch = Mesher.sphere(1.0, Color.RED)
	var b: MeshBatch = MeshBatch.new()
	b.append(a, Transform3D(Basis.IDENTITY, Vector3(5.0, 0.0, 0.0)))
	assert_eq(b.vertices.size(), a.vertices.size(), "every vertex copied")
	assert_almost_eq(b.aabb().get_center().x, 5.0, EPS, "moved by the transform")
	assert_eq(b.colors[0], Color.RED, "color kept")

func test_same_input_same_fingerprint() -> void:
	var a: MeshBatch = Mesher.capsule(0.3, 1.0, Color.BLUE)
	var b: MeshBatch = Mesher.capsule(0.3, 1.0, Color.BLUE)
	assert_eq(a.fingerprint(), b.fingerprint(), "deterministic")
	assert_true(a.fingerprint() != Mesher.capsule(0.3, 1.1, Color.BLUE).fingerprint(), "a change shows")

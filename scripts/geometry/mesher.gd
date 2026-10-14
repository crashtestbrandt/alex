extends RefCounted
class_name Mesher
## Direct meshes for the primitive set, the twin of [Sdf] (docs/geometry.md). Every function is a pure
## function of its arguments and returns a [MeshBatch] in the primitive's local space, so one recipe builds
## the same triangles on every device. No RNG, no time, no asset.
##
## The lathe is the core, as it is in spaceman's Forge: a closed (radius, height) profile revolved around Y
## covers a cup, a lamp shade, a tub, a ball and a disc, and a sphere or a capsule is a profile too. The
## crease rule shades a bend sharper than `CREASE_RAD` as a hard edge and anything gentler as smooth.

const SEGMENTS: int = 24
const CREASE_RAD: float = 0.6
const AXIS_EPS: float = Sdf.AXIS_EPS

## Revolve a closed (radius, height) profile around Y. Either winding is accepted; the profile may touch the
## axis, and an edge that runs along the axis is skipped.
static func revolve(profile: PackedVector2Array, color: Color, segments: int = SEGMENTS) -> MeshBatch:
	var batch: MeshBatch = MeshBatch.new()
	var pts: PackedVector2Array = _ccw(profile)
	var count: int = pts.size()
	if count < 3:
		return batch
	# Per-edge outward normals in profile space; an axis or zero-length edge gets a null entry.
	var edge_normals: Array[Vector2] = []
	var edge_real: Array[bool] = []
	for k: int in count:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[(k + 1) % count]
		var e: Vector2 = b - a
		var real: bool = e.length_squared() > 0.0 and not (absf(a.x) < AXIS_EPS and absf(b.x) < AXIS_EPS)
		edge_real.push_back(real)
		edge_normals.push_back(Vector2(e.y, -e.x).normalized() if real else Vector2.ZERO)
	for k: int in count:
		if not edge_real[k]:
			continue
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[(k + 1) % count]
		var na: Vector2 = _vertex_normal(edge_normals, edge_real, count, k, k, a)
		var nb: Vector2 = _vertex_normal(edge_normals, edge_real, count, k, (k + 1) % count, b)
		var ring_a: PackedInt32Array = _ring(batch, a, na, color, segments)
		var ring_b: PackedInt32Array = _ring(batch, b, nb, color, segments)
		var a_on_axis: bool = absf(a.x) < AXIS_EPS
		var b_on_axis: bool = absf(b.x) < AXIS_EPS
		for s: int in segments:
			if a_on_axis:
				batch.add_face(ring_a[s], ring_b[s], ring_b[s + 1])
			elif b_on_axis:
				batch.add_face(ring_a[s], ring_b[s], ring_a[s + 1])
			else:
				batch.add_quad(ring_a[s], ring_b[s], ring_b[s + 1], ring_a[s + 1])
	return batch

static func sphere(radius: float, color: Color, segments: int = SEGMENTS) -> MeshBatch:
	return revolve(semicircle(radius, Vector2.ZERO, segments / 2), color, segments)

## A capsule along Y: a cylinder `half_height` long between two hemispheres of `radius`.
static func capsule(radius: float, half_height: float, color: Color, segments: int = SEGMENTS) -> MeshBatch:
	var steps: int = maxi(segments / 4, 3)
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in steps + 1:
		var angle: float = -PI / 2.0 + (PI / 2.0) * i / steps
		pts.push_back(Vector2(cos(angle) * radius, sin(angle) * radius - half_height))
	for i: int in steps + 1:
		var angle: float = (PI / 2.0) * i / steps
		pts.push_back(Vector2(cos(angle) * radius, sin(angle) * radius + half_height))
	return revolve(pts, color, segments)

## A box of half extents `half`. With `round` above zero every edge is rounded: a sphere is built and each
## vertex is pushed out to its octant, which is exactly the surface [method Sdf.box] describes.
static func box(half: Vector3, round: float, color: Color) -> MeshBatch:
	var r: float = clampf(round, 0.0, minf(half.x, minf(half.y, half.z)))
	if r <= 0.0:
		return _hard_box(half, color)
	var batch: MeshBatch = sphere(r, color, 16)
	var inner: Vector3 = half - Vector3(r, r, r)
	for i: int in batch.vertices.size():
		var n: Vector3 = batch.normals[i]
		batch.vertices[i] = n * r + Vector3(_snap_sign(n.x) * inner.x, _snap_sign(n.y) * inner.y, _snap_sign(n.z) * inner.z)
	return batch

## A closed polygon in XY, extruded `half_depth` each way along Z. Either winding.
static func extrude(poly: PackedVector2Array, half_depth: float, color: Color) -> MeshBatch:
	var batch: MeshBatch = MeshBatch.new()
	var pts: PackedVector2Array = _ccw(poly)
	var count: int = pts.size()
	if count < 3:
		return batch
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
	if tris.is_empty():
		push_error("Mesher.extrude: the polygon does not triangulate")
		return batch
	var front: PackedInt32Array = PackedInt32Array()
	var back: PackedInt32Array = PackedInt32Array()
	for p: Vector2 in pts:
		front.push_back(batch.add_vertex(Vector3(p.x, p.y, half_depth), Vector3.BACK, color))
		back.push_back(batch.add_vertex(Vector3(p.x, p.y, -half_depth), Vector3.FORWARD, color))
	for t: int in tris.size() / 3:
		batch.add_face(front[tris[t * 3]], front[tris[t * 3 + 1]], front[tris[t * 3 + 2]])
		batch.add_face(back[tris[t * 3]], back[tris[t * 3 + 1]], back[tris[t * 3 + 2]])
	for i: int in count:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % count]
		var e: Vector2 = b - a
		if e.length_squared() <= 0.0:
			continue
		var n: Vector3 = Vector3(e.y, -e.x, 0.0).normalized()
		var i0: int = batch.add_vertex(Vector3(a.x, a.y, half_depth), n, color)
		var i1: int = batch.add_vertex(Vector3(a.x, a.y, -half_depth), n, color)
		var i2: int = batch.add_vertex(Vector3(b.x, b.y, -half_depth), n, color)
		var i3: int = batch.add_vertex(Vector3(b.x, b.y, half_depth), n, color)
		batch.add_quad(i0, i1, i2, i3)
	return batch

## An arc of a torus in the XZ plane, centered on +X, `arc` radians wide, ends capped round as the field caps
## them. TAU is a ring.
static func torus_arc(major: float, minor: float, arc: float, color: Color, segments: int = SEGMENTS) -> MeshBatch:
	var batch: MeshBatch = MeshBatch.new()
	var closed: bool = arc >= TAU - AXIS_EPS
	var sweep: float = TAU if closed else arc
	var along: int = maxi(roundi(segments * sweep / TAU), 4)
	var around: int = maxi(segments / 2, 6)
	var rings: Array[PackedInt32Array] = []
	for i: int in along + 1:
		var phi: float = -sweep / 2.0 + sweep * i / along
		var u: Vector3 = Vector3(cos(phi), 0.0, sin(phi))
		var c: Vector3 = u * major
		var ring: PackedInt32Array = PackedInt32Array()
		for j: int in around + 1:
			var psi: float = TAU * j / around
			var n: Vector3 = u * cos(psi) + Vector3.UP * sin(psi)
			ring.push_back(batch.add_vertex(c + n * minor, n, color))
		rings.push_back(ring)
	for i: int in along:
		for j: int in around:
			batch.add_quad(rings[i][j], rings[i + 1][j], rings[i + 1][j + 1], rings[i][j + 1])
	if not closed:
		_torus_cap(batch, major, minor, -sweep / 2.0, -1.0, color, around, rings[0])
		_torus_cap(batch, major, minor, sweep / 2.0, 1.0, color, around, rings[along])
	return batch

## The right half of a circle as a (radius, height) profile, `steps` edges from the bottom pole to the top.
static func semicircle(radius: float, center: Vector2, steps: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = maxi(steps, 2)
	for i: int in n + 1:
		var angle: float = -PI / 2.0 + PI * i / n
		pts.push_back(center + Vector2(cos(angle) * radius, sin(angle) * radius))
	return pts

## A regular star in XY, `points` tips, tips at `outer` and valleys at `inner` from the center.
static func star(points: int, outer: float, inner: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in points * 2:
		var r: float = outer if i % 2 == 0 else inner
		var angle: float = PI / 2.0 + TAU * i / (points * 2)
		pts.push_back(Vector2(cos(angle) * r, sin(angle) * r))
	return pts

static func _ccw(poly: PackedVector2Array) -> PackedVector2Array:
	var area: float = 0.0
	var count: int = poly.size()
	for i: int in count:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % count]
		area += a.x * b.y - b.x * a.y
	if area >= 0.0:
		return poly
	var out: PackedVector2Array = poly.duplicate()
	out.reverse()
	return out

## The normal at profile vertex `v` for edge `k`: vertical on the axis, averaged with the neighbor edge when
## the bend is gentler than the crease angle, else the edge's own.
static func _vertex_normal(edge_normals: Array[Vector2], edge_real: Array[bool], count: int, k: int, v: int, p: Vector2) -> Vector2:
	var own: Vector2 = edge_normals[k]
	if absf(p.x) < AXIS_EPS:
		return Vector2(0.0, 1.0 if own.y >= 0.0 else -1.0)
	# The other edge at vertex v: the previous one when v starts edge k, the next one when v ends it.
	var other_index: int = (v - 1 + count) % count if v == k else v
	if not edge_real[other_index]:
		return own
	var other: Vector2 = edge_normals[other_index]
	if own.angle_to(other) > CREASE_RAD or absf(own.angle_to(other)) > CREASE_RAD:
		return own
	return (own + other).normalized()

static func _ring(batch: MeshBatch, p: Vector2, n: Vector2, color: Color, segments: int) -> PackedInt32Array:
	var ring: PackedInt32Array = PackedInt32Array()
	for s: int in segments + 1:
		var theta: float = TAU * s / segments
		var c: float = cos(theta)
		var sn: float = sin(theta)
		ring.push_back(batch.add_vertex(Vector3(p.x * c, p.y, p.x * sn), Vector3(n.x * c, n.y, n.x * sn).normalized(), color))
	return ring

static func _hard_box(half: Vector3, color: Color) -> MeshBatch:
	var batch: MeshBatch = MeshBatch.new()
	var faces: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for n: Vector3 in faces:
		var u: Vector3 = Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
		var v: Vector3 = n.cross(u)
		var corners: PackedInt32Array = PackedInt32Array()
		for sv: int in [-1, 1]:
			for su: int in [-1, 1]:
				var d: Vector3 = n + u * su + v * sv
				corners.push_back(batch.add_vertex(Vector3(d.x * half.x, d.y * half.y, d.z * half.z), n, color))
		batch.add_quad(corners[0], corners[1], corners[3], corners[2])
	return batch

## A hemisphere closing one end of a torus arc, from the end ring `edge` out along the tangent.
static func _torus_cap(batch: MeshBatch, major: float, minor: float, phi: float, direction: float, color: Color, around: int, edge: PackedInt32Array) -> void:
	var u: Vector3 = Vector3(cos(phi), 0.0, sin(phi))
	var t: Vector3 = Vector3(-sin(phi), 0.0, cos(phi)) * direction
	var c: Vector3 = u * major
	var steps: int = maxi(around / 4, 2)
	var previous: PackedInt32Array = edge
	for k: int in range(1, steps + 1):
		var alpha: float = (PI / 2.0) * k / steps
		var ring: PackedInt32Array = PackedInt32Array()
		for j: int in around + 1:
			var psi: float = TAU * j / around
			var n: Vector3 = (u * cos(psi) + Vector3.UP * sin(psi)) * cos(alpha) + t * sin(alpha)
			ring.push_back(batch.add_vertex(c + n * minor, n, color))
		for j: int in around:
			if k == steps:
				batch.add_face(previous[j], previous[j + 1], ring[j])
			else:
				batch.add_quad(previous[j], previous[j + 1], ring[j + 1], ring[j])
		previous = ring

static func _snap_sign(x: float) -> float:
	if absf(x) < 0.00001:
		return 0.0
	return 1.0 if x > 0.0 else -1.0

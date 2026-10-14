extends RefCounted
class_name Sdf
## Exact signed distances for the primitive set (docs/geometry.md). Pure math: every function takes a point
## in the primitive's local space and returns meters, negative inside. [Mesher] builds the same shapes, so a
## recipe's mesh and its distance field agree. The field is what tap picking reads, and what an editor will.
##
## Conventions shared with the mesher: Y is up, a revolve turns around Y, an extrude runs along Z, a torus
## arc lies in the XZ plane centered on +X.

## Two profile points closer to the axis than this lie on it. A revolve's closing edge along the axis is not a
## surface, so [method revolve] leaves it out of the distance and keeps it only for the inside test.
const AXIS_EPS: float = 0.00001

static func sphere(p: Vector3, radius: float) -> float:
	return p.length() - radius

## A box of outer half extents `half`, every edge rounded by `round`. The rounding is carved inward, so the box
## never grows past `half`.
static func box(p: Vector3, half: Vector3, round: float) -> float:
	var r: float = clampf(round, 0.0, minf(half.x, minf(half.y, half.z)))
	var q: Vector3 = p.abs() - (half - Vector3(r, r, r))
	var outside: float = Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length()
	var inside: float = minf(maxf(q.x, maxf(q.y, q.z)), 0.0)
	return outside + inside - r

## A capsule along Y: a cylinder `half_height` long between two hemispheres of `radius`.
static func capsule(p: Vector3, radius: float, half_height: float) -> float:
	var q: Vector3 = Vector3(p.x, p.y - clampf(p.y, -half_height, half_height), p.z)
	return q.length() - radius

## An arc of a torus in the XZ plane: `major` from the axis to the tube center, `minor` the tube radius, the
## arc `arc` radians wide and centered on +X, both ends capped round. An arc of TAU or more is the whole ring.
static func torus_arc(p: Vector3, major: float, minor: float, arc: float) -> float:
	var flat: Vector2 = Vector2(p.x, p.z)
	var angle: float = 0.0
	if flat.length_squared() > 0.0:
		angle = atan2(p.z, p.x)
	if arc < TAU - AXIS_EPS:
		angle = clampf(angle, -arc / 2.0, arc / 2.0)
	var nearest: Vector3 = Vector3(cos(angle) * major, 0.0, sin(angle) * major)
	return (p - nearest).length() - minor

## Signed distance to a closed 2D polygon, negative inside. Either winding; a repeated point is skipped.
static func polygon(q: Vector2, poly: PackedVector2Array) -> float:
	return _polygon(q, poly, false)

## A surface of revolution around Y. `profile` is a closed polygon of (radius, height) points with radius 0 or
## more. It may touch the axis, as a cup's bottom does; the edges that run along the axis are not surfaces.
static func revolve(p: Vector3, profile: PackedVector2Array) -> float:
	var q: Vector2 = Vector2(Vector2(p.x, p.z).length(), p.y)
	return _polygon(q, profile, true)

## A closed polygon in XY, extruded `half_depth` each way along Z.
static func extrude(p: Vector3, poly: PackedVector2Array, half_depth: float) -> float:
	var d: float = _polygon(Vector2(p.x, p.y), poly, false)
	var w: Vector2 = Vector2(d, absf(p.z) - half_depth)
	return minf(maxf(w.x, w.y), 0.0) + Vector2(maxf(w.x, 0.0), maxf(w.y, 0.0)).length()

static func _polygon(q: Vector2, poly: PackedVector2Array, skip_axis_edges: bool) -> float:
	var n: int = poly.size()
	if n < 3:
		return INF
	var d: float = INF
	var sign_value: float = 1.0
	var j: int = n - 1
	for i: int in n:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		var e: Vector2 = b - a
		if e.length_squared() <= 0.0:
			j = i
			continue
		var w: Vector2 = q - a
		var on_axis: bool = skip_axis_edges and absf(a.x) < AXIS_EPS and absf(b.x) < AXIS_EPS
		if not on_axis:
			var c: Vector2 = w - e * clampf(w.dot(e) / e.dot(e), 0.0, 1.0)
			d = minf(d, c.length_squared())
		var c1: bool = q.y >= a.y
		var c2: bool = q.y < b.y
		var c3: bool = e.x * w.y > e.y * w.x
		if (c1 and c2 and c3) or (not c1 and not c2 and not c3):
			sign_value = -sign_value
		j = i
	if d == INF:
		return INF
	return sign_value * sqrt(d)

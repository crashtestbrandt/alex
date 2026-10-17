extends RefCounted
class_name Picker
## Tap picking against recipe distance fields (docs/geometry.md). A ray from the camera is sphere-traced
## through each target's field, parts where they are right now, and the nearest hit wins. Pure: the targets
## carry everything, so a unit suite can pick against a recipe with no scene.

const HIT_EPS: float = 0.004
const MIN_STEP: float = 0.003
const MAX_STEPS: int = 96

## What a pick runs against. `transform` takes object space to world; `parts` is each part's current
## transform in object space; `center` and `radius` bound the object in world space. `opening` is a
## pick-only rectangle in the object's x/y plane at z 0: the doorway a swung leaf leaves empty, so a tap
## through it still picks the door. Empty for none.
class Target:
	var recipe: Recipe = null
	var transform: Transform3D = Transform3D.IDENTITY
	var parts: Dictionary[String, Transform3D] = {}
	var center: Vector3 = Vector3.ZERO
	var radius: float = 1.0
	var opening: Rect2 = Rect2()

## The index of the nearest target the ray hits, or -1.
static func pick(origin: Vector3, direction: Vector3, targets: Array[Target]) -> int:
	var best: int = -1
	var best_t: float = INF
	for i: int in targets.size():
		var t: float = march(origin, direction, targets[i])
		if t < best_t:
			best_t = t
			best = i
	return best

## Distance along the ray to the target's surface or through its opening, or INF for a miss.
static func march(origin: Vector3, direction: Vector3, target: Target) -> float:
	var span: Vector2 = ray_sphere(origin, direction, target.center, target.radius)
	if span.x == INF:
		return INF
	var inverse: Transform3D = target.transform.affine_inverse()
	var through: float = through_opening(inverse * origin, inverse.basis * direction, target.opening)
	var t: float = maxf(span.x, 0.0)
	for _step: int in MAX_STEPS:
		if t > span.y:
			return through
		var p: Vector3 = inverse * (origin + direction * t)
		var d: float = target.recipe.distance(p, target.parts)
		if d < HIT_EPS:
			return minf(t, through)
		t += maxf(d, MIN_STEP)
	return through

## Distance along a ray, in object space, to where it crosses `opening` in the x/y plane at z 0, or INF
## when the opening is empty or the ray misses it.
static func through_opening(origin: Vector3, direction: Vector3, opening: Rect2) -> float:
	if not opening.has_area() or absf(direction.z) < 0.000001:
		return INF
	var t: float = -origin.z / direction.z
	if t < 0.0:
		return INF
	var p: Vector3 = origin + direction * t
	return t if opening.has_point(Vector2(p.x, p.y)) else INF

## Entry and exit distances of a ray through a sphere, or (INF, INF) when it misses.
static func ray_sphere(origin: Vector3, direction: Vector3, center: Vector3, radius: float) -> Vector2:
	var oc: Vector3 = origin - center
	var b: float = oc.dot(direction)
	var c: float = oc.dot(oc) - radius * radius
	var disc: float = b * b - c
	if disc < 0.0:
		return Vector2(INF, INF)
	var root: float = sqrt(disc)
	var t1: float = -b + root
	if t1 < 0.0:
		return Vector2(INF, INF)
	return Vector2(-b - root, t1)

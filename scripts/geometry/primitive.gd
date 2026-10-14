extends RefCounted
class_name Primitive
## One shape in a [Recipe]: a kind, its dimensions, a rigid transform into object space, a color and the part
## it belongs to. It answers two questions the same way: [method distance] through [Sdf] and [method batch]
## through [Mesher]. The transform is rotation and translation only; a scaled primitive would put the two
## answers out of step.

enum Kind {
	SPHERE = 0,
	BOX = 1,
	CAPSULE = 2,
	TORUS_ARC = 3,
	REVOLVE = 4,
	EXTRUDE = 5,
}

var kind: Kind = Kind.SPHERE
var transform: Transform3D = Transform3D.IDENTITY
var color: Color = Color.WHITE
## The part this primitive belongs to. The empty name is the body. A reaction moves a part by name.
var part: String = ""
var radius: float = 0.5
var half: Vector3 = Vector3(0.5, 0.5, 0.5)
var round: float = 0.0
var half_height: float = 0.5
var major: float = 0.5
var minor: float = 0.1
var arc: float = TAU
var profile: PackedVector2Array = PackedVector2Array()
var half_depth: float = 0.1

static func sphere(p_radius: float, at: Transform3D, p_color: Color) -> Primitive:
	var prim: Primitive = _make(Kind.SPHERE, at, p_color)
	prim.radius = p_radius
	return prim

## A box of full `size`, edges rounded by `p_round`.
static func box(size: Vector3, at: Transform3D, p_color: Color, p_round: float = 0.0) -> Primitive:
	var prim: Primitive = _make(Kind.BOX, at, p_color)
	prim.half = size / 2.0
	prim.round = p_round
	return prim

## A capsule along local Y whose straight section is `length` long.
static func capsule(p_radius: float, length: float, at: Transform3D, p_color: Color) -> Primitive:
	var prim: Primitive = _make(Kind.CAPSULE, at, p_color)
	prim.radius = p_radius
	prim.half_height = length / 2.0
	return prim

static func torus_arc(p_major: float, p_minor: float, p_arc: float, at: Transform3D, p_color: Color) -> Primitive:
	var prim: Primitive = _make(Kind.TORUS_ARC, at, p_color)
	prim.major = p_major
	prim.minor = p_minor
	prim.arc = p_arc
	return prim

static func revolve(p_profile: PackedVector2Array, at: Transform3D, p_color: Color) -> Primitive:
	var prim: Primitive = _make(Kind.REVOLVE, at, p_color)
	prim.profile = p_profile
	return prim

## A polygon in local XY extruded to a full `depth` along Z.
static func extrude(poly: PackedVector2Array, depth: float, at: Transform3D, p_color: Color) -> Primitive:
	var prim: Primitive = _make(Kind.EXTRUDE, at, p_color)
	prim.profile = poly
	prim.half_depth = depth / 2.0
	return prim

func in_part(name: String) -> Primitive:
	part = name
	return self

## Signed distance from `p`, a point in object space, in meters.
func distance(p: Vector3) -> float:
	var q: Vector3 = transform.affine_inverse() * p
	match kind:
		Kind.SPHERE:
			return Sdf.sphere(q, radius)
		Kind.BOX:
			return Sdf.box(q, half, round)
		Kind.CAPSULE:
			return Sdf.capsule(q, radius, half_height)
		Kind.TORUS_ARC:
			return Sdf.torus_arc(q, major, minor, arc)
		Kind.REVOLVE:
			return Sdf.revolve(q, profile)
		Kind.EXTRUDE:
			return Sdf.extrude(q, profile, half_depth)
	return INF

## The mesh in the primitive's own space. The caller applies [member transform].
func batch() -> MeshBatch:
	match kind:
		Kind.SPHERE:
			return Mesher.sphere(radius, color)
		Kind.BOX:
			return Mesher.box(half, round, color)
		Kind.CAPSULE:
			return Mesher.capsule(radius, half_height, color)
		Kind.TORUS_ARC:
			return Mesher.torus_arc(major, minor, arc, color)
		Kind.REVOLVE:
			return Mesher.revolve(profile, color)
		Kind.EXTRUDE:
			return Mesher.extrude(profile, half_depth, color)
	return MeshBatch.new()

static func _make(p_kind: Kind, at: Transform3D, p_color: Color) -> Primitive:
	var prim: Primitive = Primitive.new()
	prim.kind = p_kind
	prim.transform = at
	prim.color = p_color
	return prim

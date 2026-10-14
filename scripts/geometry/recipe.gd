extends RefCounted
class_name Recipe
## An object as a list of [Primitive]s grouped into named parts, each part with a pivot (docs/geometry.md).
## The body is the part with the empty name. [RecipeBuilder] turns a recipe into a node tree, one mesh per
## part placed at its pivot, so a reaction can swing a door leaf by rotating the `leaf` part. [method distance]
## evaluates the same recipe as a field, with the parts wherever they are right now, and that is what a tap
## hits against.
##
## Only union is shared by the mesh and the field, so a recipe is a union of primitives. Subtraction and
## smooth blends wait for a mesher that can bake them.

var name: String = ""
var primitives: Array[Primitive] = []
## Part name to pivot, in object space. A part without an entry pivots at the origin.
var pivots: Dictionary[String, Vector3] = {}
## Parts that show only while the spot is on: the water in a tub.
var shown_when_on: PackedStringArray = PackedStringArray()
## Parts that light up on a GLOW reaction.
var glow_parts: PackedStringArray = PackedStringArray()
## Height in meters, for placing captions above the object.
var height: float = 1.0

func add(prim: Primitive) -> Primitive:
	primitives.push_back(prim)
	return prim

func set_pivot(part: String, at: Vector3) -> void:
	pivots[part] = at

func pivot(part: String) -> Vector3:
	return pivots.get(part, Vector3.ZERO)

## The part names in first-seen order, the body first when it has primitives.
func parts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for prim: Primitive in primitives:
		if not out.has(prim.part):
			out.push_back(prim.part)
	return out

## The rest transform of a part: its pivot, unrotated.
func rest_transform(part: String) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pivot(part))

## Signed distance from `p` in object space, with each part at the transform `part_transforms` gives it
## (a part not listed rests at its pivot).
func distance(p: Vector3, part_transforms: Dictionary[String, Transform3D]) -> float:
	var best: float = INF
	for prim: Primitive in primitives:
		var q: Vector3 = p
		if part_transforms.has(prim.part):
			var xf: Transform3D = part_transforms[prim.part]
			q = xf.affine_inverse() * p + pivot(prim.part)
		best = minf(best, prim.distance(q))
	return best

## One merged batch per part, vertices relative to the part's pivot.
func batches() -> Dictionary[String, MeshBatch]:
	var out: Dictionary[String, MeshBatch] = {}
	for prim: Primitive in primitives:
		if not out.has(prim.part):
			out[prim.part] = MeshBatch.new()
		var batch: MeshBatch = out[prim.part]
		var local: Transform3D = Transform3D(Basis.IDENTITY, -pivot(prim.part)) * prim.transform
		batch.append(prim.batch(), local)
	return out

func triangle_count() -> int:
	var total: int = 0
	for batch: MeshBatch in batches().values():
		total += batch.triangle_count()
	return total

## The object-space bounds of every part at rest.
func aabb() -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for part: String in parts():
		var batch: MeshBatch = batches()[part]
		if batch.is_empty():
			continue
		var part_box: AABB = batch.aabb()
		part_box.position += pivot(part)
		box = part_box if first else box.merge(part_box)
		first = false
	return box

## A hash over every part's arrays, in part order.
func fingerprint() -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var all: Dictionary[String, MeshBatch] = batches()
	for part: String in parts():
		ctx.update(("part:" + part).to_utf8_buffer())
		ctx.update(all[part].fingerprint().to_utf8_buffer())
	return ctx.finish().hex_encode()

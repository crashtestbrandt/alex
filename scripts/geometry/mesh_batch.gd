extends RefCounted
class_name MeshBatch
## Triangle arrays under construction: positions, normals, vertex colors and indices. [Mesher] fills one per
## primitive, [RecipeBuilder] merges them per part and hands the arrays to an [ArrayMesh].
##
## Winding is handled once, here. [method add_face] takes three indices in any order plus nothing else: it
## reads the three vertex normals, and emits the triangle clockwise as seen from the side those normals face,
## which is the side Godot draws. No builder reasons about winding.

var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var indices: PackedInt32Array = PackedInt32Array()

func add_vertex(v: Vector3, n: Vector3, c: Color) -> int:
	vertices.push_back(v)
	normals.push_back(n)
	colors.push_back(c)
	return vertices.size() - 1

## One triangle whose front faces the way its vertex normals point.
func add_face(i0: int, i1: int, i2: int) -> void:
	var outward: Vector3 = normals[i0] + normals[i1] + normals[i2]
	var cross: Vector3 = (vertices[i1] - vertices[i0]).cross(vertices[i2] - vertices[i0])
	# Godot's front faces are clockwise from the front, so a front triangle's cross product points inward.
	if cross.dot(outward) > 0.0:
		indices.push_back(i0)
		indices.push_back(i2)
		indices.push_back(i1)
	else:
		indices.push_back(i0)
		indices.push_back(i1)
		indices.push_back(i2)

## Two triangles over four corners given around the quad.
func add_quad(i0: int, i1: int, i2: int, i3: int) -> void:
	add_face(i0, i1, i2)
	add_face(i0, i2, i3)

## Append `other` under `xform`, keeping its colors. Normals are rotated, never scaled.
func append(other: MeshBatch, xform: Transform3D) -> void:
	var base: int = vertices.size()
	var rotation: Basis = xform.basis.orthonormalized()
	for i: int in other.vertices.size():
		vertices.push_back(xform * other.vertices[i])
		normals.push_back((rotation * other.normals[i]).normalized())
		colors.push_back(other.colors[i])
	for index: int in other.indices:
		indices.push_back(base + index)

func set_all_colors(c: Color) -> void:
	for i: int in colors.size():
		colors[i] = c

func triangle_count() -> int:
	return indices.size() / 3

func is_empty() -> bool:
	return indices.is_empty()

func aabb() -> AABB:
	if vertices.is_empty():
		return AABB()
	var box: AABB = AABB(vertices[0], Vector3.ZERO)
	for v: Vector3 in vertices:
		box = box.expand(v)
	return box

## The arrays an [ArrayMesh] surface takes.
func to_arrays() -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

## A SHA-256 over every array, so two builds can be compared without comparing arrays.
func fingerprint() -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(vertices))
	ctx.update(var_to_bytes(normals))
	ctx.update(var_to_bytes(colors))
	ctx.update(var_to_bytes(indices))
	return ctx.finish().hex_encode()

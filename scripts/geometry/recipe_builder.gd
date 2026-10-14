extends RefCounted
class_name RecipeBuilder
## Turns a [Recipe] into a node tree: a Node3D root with one MeshInstance3D per part, named after the part
## (the body is `Body`), placed at the part's pivot. Every mesh carries vertex colors and takes the one shared
## material, so a room of objects is one material and no texture.

static func build(recipe: Recipe, material: Material) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = recipe.name if not recipe.name.is_empty() else "Object"
	var all: Dictionary[String, MeshBatch] = recipe.batches()
	for part: String in recipe.parts():
		var batch: MeshBatch = all[part]
		if batch.is_empty():
			continue
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, batch.to_arrays())
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = node_name(part)
		instance.mesh = mesh
		instance.material_override = material
		instance.transform = recipe.rest_transform(part)
		root.add_child(instance)
	return root

static func node_name(part: String) -> String:
	return "Body" if part.is_empty() else part

## The one material every recipe mesh shares: vertex colors as albedo, matte.
static func make_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	material.metallic = 0.0
	return material

extends Node3D
class_name SpotBody
## One [Spot] standing in the 3D room: the object its recipe builds, its on/off state, and its reaction.
## RoomView owns the input and calls [method react]; this node only moves. Every tween multiplies by
## `Style.motion_scale()`, and at zero the state still changes so the picture does, with no movement.

const OPEN_RAD: float = -1.75
const GLOW_ENERGY: float = 1.8
const GLOW_COLOR: Color = Color(1.0, 0.9, 0.7)

var spot: Spot = null
var recipe: Recipe = null
## The toggled state: door open, light on, tub full.
var is_on: bool = false
var size_m: float = 1.0

var _parts: Dictionary[String, MeshInstance3D] = {}
var _glow: Array[StandardMaterial3D] = []
var _bounds: AABB = AABB()
var _rest: Transform3D = Transform3D.IDENTITY
var _tween: Tween = null

func setup(s: Spot, r: Recipe, p_size_m: float, material: Material) -> void:
	spot = s
	recipe = r
	size_m = p_size_m
	name = s.id
	var built: Node3D = RecipeBuilder.build(r, material)
	built.name = "Object"
	add_child(built)
	for part: String in r.parts():
		var node: Node = built.get_node_or_null(RecipeBuilder.node_name(part))
		if node is MeshInstance3D:
			_parts[part] = node
	for part: String in r.glow_parts:
		if not _parts.has(part):
			continue
		var dup: Resource = material.duplicate()
		if dup is StandardMaterial3D:
			var glow: StandardMaterial3D = dup
			glow.emission_enabled = true
			glow.emission = GLOW_COLOR
			glow.emission_energy_multiplier = 0.0
			_parts[part].material_override = glow
			_glow.push_back(glow)
	_bounds = r.aabb()
	_apply_state()

## Where the body stands when nothing is moving it.
func set_rest(xf: Transform3D) -> void:
	_rest = xf
	transform = xf

## The point captions hang from, in world space.
func top_point() -> Vector3:
	return to_global(Vector3(0.0, recipe.height, 0.0))

func center_point() -> Vector3:
	return to_global(_bounds.get_center())

## The object's bounds at rest, in its own space.
func bounds() -> AABB:
	return _bounds

## What the picker runs against: the recipe, where the body stands, and where each part is right now.
func pick_target() -> Picker.Target:
	var t: Picker.Target = Picker.Target.new()
	t.recipe = recipe
	t.transform = global_transform
	for part: String in _parts.keys():
		t.parts[part] = _parts[part].transform
	t.center = center_point()
	t.radius = _bounds.size.length() / 2.0 * 1.3 + 0.1
	return t

## Toggle the state and play the reaction.
func react() -> void:
	is_on = not is_on
	_apply_state()
	var scale_factor: float = Style.motion_scale()
	if _tween != null:
		_tween.kill()
		_tween = null
	transform = _rest
	if scale_factor <= 0.0:
		_snap_state()
		return
	_tween = create_tween()
	match spot.reaction:
		Spot.Reaction.BOUNCE:
			_tween.tween_property(self, "position:y", _rest.origin.y + size_m * 0.35, 0.18 * scale_factor) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			_tween.tween_property(self, "position:y", _rest.origin.y, 0.32 * scale_factor) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		Spot.Reaction.OPEN:
			var leaf: MeshInstance3D = _moving_part()
			if leaf != null:
				_tween.tween_property(leaf, "rotation:y", OPEN_RAD if is_on else 0.0, 0.45 * scale_factor) \
					.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			else:
				_tween.tween_property(self, "scale:x", 0.4 if is_on else 1.0, 0.35 * scale_factor)
		Spot.Reaction.GLOW:
			for glow: StandardMaterial3D in _glow:
				_tween.parallel().tween_property(glow, "emission_energy_multiplier", GLOW_ENERGY if is_on else 0.0, 0.3 * scale_factor)
			_tween.parallel().tween_property(self, "scale", Vector3.ONE * 1.06, 0.12 * scale_factor)
			_tween.tween_property(self, "scale", Vector3.ONE, 0.25 * scale_factor)
		Spot.Reaction.SPIN:
			_tween.tween_property(self, "rotation:y", _rest.basis.get_euler().y + TAU, 0.7 * scale_factor) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			_tween.tween_callback(func() -> void: transform = _rest)
		Spot.Reaction.WOBBLE:
			for i: int in 3:
				var swing: float = 0.16 * (1.0 - i / 3.0)
				_tween.tween_property(self, "rotation:z", swing, 0.09 * scale_factor)
				_tween.tween_property(self, "rotation:z", -swing, 0.09 * scale_factor)
			_tween.tween_property(self, "rotation:z", 0.0, 0.08 * scale_factor)
		Spot.Reaction.GROW:
			_tween.tween_property(self, "scale", Vector3.ONE * 1.2, 0.2 * scale_factor) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "scale", Vector3.ONE, 0.3 * scale_factor)

## Parts that show only while on, and the glow, follow the state.
func _apply_state() -> void:
	for part: String in recipe.shown_when_on:
		if _parts.has(part):
			_parts[part].visible = is_on

## The end state of a reaction, with no movement.
func _snap_state() -> void:
	match spot.reaction:
		Spot.Reaction.OPEN:
			var leaf: MeshInstance3D = _moving_part()
			if leaf != null:
				leaf.rotation.y = OPEN_RAD if is_on else 0.0
		Spot.Reaction.GLOW:
			for glow: StandardMaterial3D in _glow:
				glow.emission_energy_multiplier = GLOW_ENERGY if is_on else 0.0

## The first named part: the leaf of a door.
func _moving_part() -> MeshInstance3D:
	for part: String in recipe.parts():
		if not part.is_empty() and _parts.has(part):
			return _parts[part]
	return null

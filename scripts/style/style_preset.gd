extends Resource
class_name StylePreset
## Everything about how the app looks and moves for one child, as a resource under res://styles/. A profile
## names one by id. The Style autoload turns it into a Theme at runtime, so a preset is data a non-developer
## can author in the editor (docs/profiles.md "Styles").

## How much the interface moves. A child who is overwhelmed by motion gets NONE; the chunk animation and
## every tween read [method Style.motion_scale] and shorten or skip accordingly.
enum Motion {
	FULL = 0,
	REDUCED = 1,
	NONE = 2,
}

const DIR: String = "res://styles"

@export var display_name: String = "Calm"
@export var background: Color = Color("f4f1ea")
@export var surface: Color = Color("ffffff")
@export var accent: Color = Color("2f6f8f")
@export var text: Color = Color("1e2a32")
## The materials a room's objects are built from (ObjectRecipes). Vertex colors, no texture.
@export_group("Room materials")
@export var wood: Color = Color(0.62, 0.45, 0.30)
@export var cloth: Color = Color(0.86, 0.80, 0.70)
@export var metal: Color = Color(0.70, 0.72, 0.75)
@export var glass: Color = Color(0.72, 0.85, 0.93)
@export var water: Color = Color(0.50, 0.76, 0.90)
@export var floor_color: Color = Color(0.80, 0.72, 0.60)
@export var wall_color: Color = Color(0.93, 0.91, 0.86)
@export_group("")
## Multiplies every font size. 1.0 is a 24 px tile label.
@export_range(0.5, 3.0, 0.05) var font_scale: float = 1.0
@export var motion: Motion = Motion.FULL
@export_range(0, 48, 1) var corner_radius: int = 18
## The smallest a tile can be, in pixels. A touch target for a child with motor delay is larger than a
## grown-up's, and 160 is a floor, never a ceiling.
@export_range(96, 400, 4) var tile_min_size: int = 160
## How much every shape stands off the screen: the lit rim and the shadow under a button or a panel. 0 is flat.
@export_range(0.0, 1.0, 0.05) var relief: float = 0.6

## The preset ids on disk, sorted.
static func list_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(DIR)
	if dir == null:
		return out
	for file: String in dir.get_files():
		var name: String = file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			out.push_back(name.trim_suffix(".tres"))
	out.sort()
	return out

## The preset with `preset_id`, or a default-constructed one when there is no such file.
static func load_by_id(preset_id: String) -> StylePreset:
	var path: String = "%s/%s.tres" % [DIR, preset_id]
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is StylePreset:
			return loaded as StylePreset
	return StylePreset.new()

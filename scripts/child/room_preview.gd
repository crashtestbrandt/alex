extends SdfButton
class_name RoomPreview
## A large chooser target showing the room's own procedural geometry. Its preview has no learner input.
const ROOM_SCENE: PackedScene = preload("res://scenes/child/room_view.tscn")
const INSET: float = 12.0
var room: Room = null
var profile: Profile = null
var current: bool = false
var _preview: RoomView = null

func _ready() -> void:
	super()
	_preview = ROOM_SCENE.instantiate() as RoomView
	_preview.preview = true
	_preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(_preview)
	_preview.show_room(profile, room)
	resized.connect(_fit_preview)
	_fit_preview()
	refresh()

func _fit_preview() -> void:
	_preview.position = Vector2.ONE * INSET
	_preview.size = (size - Vector2.ONE * INSET * 2.0).max(Vector2.ONE)

func refresh() -> void:
	super()
	if _shape != null and current:
		_shape.border_px = 4.0
		_shape.border_color = Style.current.accent

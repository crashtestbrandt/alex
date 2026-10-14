extends GlyphBar
class_name ViewWidget
## The learner's view buttons: Front, Top, and Tilt when the room allows it. Front is the default and the
## way back. A tap on the current view's pill resets that view, so the pill emits on every tap. The pressed
## pill is the current view, so the widget reads as a state, not a menu ([GlyphBar]).

signal view_chosen(view: CameraFraming.View)

const _FIGURES: Dictionary[int, SdfGlyph.Figure] = {
	CameraFraming.View.FRONT: SdfGlyph.Figure.FRONT,
	CameraFraming.View.TOP: SdfGlyph.Figure.TOP,
	CameraFraming.View.TILT: SdfGlyph.Figure.TILT,
}

var _buttons: Dictionary[int, GlyphBar.GlyphButton] = {}

func _ready() -> void:
	super()
	for v: int in CameraFraming.View.values():
		var view: CameraFraming.View = v as CameraFraming.View
		var view_name: String = CameraFraming.View.keys()[v]
		var button: GlyphBar.GlyphButton = add_glyph(_FIGURES[v], view_name.capitalize())
		button.pressed.connect(_on_pressed.bind(view))
		_buttons[v] = button

## Which buttons the room offers. FIXED hides the widget.
func set_mode(camera: Room.Camera) -> void:
	visible = camera != Room.Camera.FIXED
	_buttons[CameraFraming.View.TILT].visible = camera == Room.Camera.TILT

## Show `view` as the current one without emitting.
func show_view(view: CameraFraming.View) -> void:
	show_current(_buttons[view])

func _on_pressed(view: CameraFraming.View) -> void:
	view_chosen.emit(view)

extends PillBar
class_name ViewWidget
## The learner's view buttons: Front, Side, Top, and Turn when the room allows an orbit. Front is the default
## and the way back. The pressed pill is the current view, so the widget reads as a state, not a menu. Each
## button is a distance-field glyph in a distance-field pill, and honors the style's touch floor.

signal view_chosen(view: CameraFraming.View)

const _FIGURES: Dictionary[int, SdfGlyph.Figure] = {
	CameraFraming.View.FRONT: SdfGlyph.Figure.FRONT,
	CameraFraming.View.SIDE: SdfGlyph.Figure.SIDE,
	CameraFraming.View.TOP: SdfGlyph.Figure.TOP,
	CameraFraming.View.TURN: SdfGlyph.Figure.TURN,
}

var _buttons: Dictionary[int, ViewButton] = {}

func _ready() -> void:
	super()
	for v: int in CameraFraming.View.values():
		var view: CameraFraming.View = v as CameraFraming.View
		var button: ViewButton = ViewButton.new()
		button.figure = _FIGURES[v]
		button.pressed.connect(_on_pressed.bind(view))
		add_item(button)
		_buttons[v] = button
	_size_buttons()

## Which buttons the room offers. FIXED hides the widget.
func set_mode(camera: Room.Camera) -> void:
	visible = camera != Room.Camera.FIXED
	_buttons[CameraFraming.View.TURN].visible = camera == Room.Camera.ORBIT

## Show `view` as the current one without emitting.
func show_current(view: CameraFraming.View) -> void:
	_buttons[view].set_pressed_no_signal(true)
	for button: ViewButton in _buttons.values():
		button.refresh()
		button.update_glyph()

func _on_pressed(view: CameraFraming.View) -> void:
	view_chosen.emit(view)

func _size_buttons() -> void:
	var px: float = float(Style.current.tile_min_size)
	for button: ViewButton in _buttons.values():
		button.custom_minimum_size = Vector2(px, px)

func _on_style_changed(preset: StylePreset) -> void:
	super(preset)
	_size_buttons()

## A pill that shows one view's glyph, in the pressed font color while it is the current view.
class ViewButton extends SdfButton:
	var figure: SdfGlyph.Figure = SdfGlyph.Figure.FRONT
	var _glyph: SdfGlyph = null

	func _ready() -> void:
		super()
		_glyph = SdfGlyph.new()
		_glyph.name = "Glyph"
		_glyph.figure = figure
		_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_glyph)
		button_down.connect(update_glyph)
		button_up.connect(update_glyph)
		toggled.connect(func(_on: bool) -> void: update_glyph())
		update_glyph()

	func update_glyph() -> void:
		if _glyph == null:
			return
		_glyph.tint = Style.current.surface if is_active() else Style.current.text

	func _on_style_changed(preset: StylePreset) -> void:
		super(preset)
		update_glyph()

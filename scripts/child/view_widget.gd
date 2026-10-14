extends HBoxContainer
class_name ViewWidget
## The learner's view buttons: Front, Side, Top, and Turn when the room allows an orbit. Front is the default
## and the way back. The pressed button is the current view, so the widget reads as a state, not a menu.
## Glyphs are drawn, not loaded, and every button honors the style's touch floor.

signal view_chosen(view: CameraFraming.View)

var _buttons: Dictionary[int, ViewButton] = {}
var _group: ButtonGroup = ButtonGroup.new()

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_PASS
	for v: int in CameraFraming.View.values():
		var view: CameraFraming.View = v as CameraFraming.View
		var button: ViewButton = ViewButton.new()
		button.view = view
		button.toggle_mode = true
		button.button_group = _group
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_pressed.bind(view))
		add_child(button)
		_buttons[v] = button
	_size_buttons()
	Style.changed.connect(_on_style_changed)

## Which buttons the room offers. FIXED hides the widget.
func set_mode(camera: Room.Camera) -> void:
	visible = camera != Room.Camera.FIXED
	_buttons[CameraFraming.View.TURN].visible = camera == Room.Camera.ORBIT

## Show `view` as the current one without emitting.
func show_current(view: CameraFraming.View) -> void:
	_buttons[view].set_pressed_no_signal(true)

func _on_pressed(view: CameraFraming.View) -> void:
	view_chosen.emit(view)

func _size_buttons() -> void:
	var px: float = float(Style.current.tile_min_size)
	for button: ViewButton in _buttons.values():
		button.custom_minimum_size = Vector2(px, px)
		button.queue_redraw()

func _on_style_changed(_preset: StylePreset) -> void:
	_size_buttons()

## A button that draws its view's glyph.
class ViewButton extends Button:
	var view: CameraFraming.View = CameraFraming.View.FRONT

	func _draw() -> void:
		var color: Color = Style.current.surface if button_pressed else Style.current.text
		var c: Vector2 = size / 2.0
		var r: float = minf(size.x, size.y) * 0.24
		var w: float = 3.0
		match view:
			CameraFraming.View.FRONT:
				draw_rect(Rect2(c - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6)), color, false, w)
				draw_line(c + Vector2(-r, r * 0.8), c + Vector2(-r * 0.6, r * 0.3), color, w)
				draw_line(c + Vector2(r, r * 0.8), c + Vector2(r * 0.6, r * 0.3), color, w)
				draw_line(c + Vector2(-r * 0.6, r * 0.3), c + Vector2(r * 0.6, r * 0.3), color, w)
			CameraFraming.View.SIDE:
				var face: PackedVector2Array = PackedVector2Array([
					c + Vector2(-r * 0.2, -r * 0.8), c + Vector2(r, -r * 0.5), c + Vector2(r, r * 0.9), c + Vector2(-r * 0.2, r * 0.6), c + Vector2(-r * 0.2, -r * 0.8)])
				draw_polyline(face, color, w)
				draw_rect(Rect2(c + Vector2(-r, -r * 0.8), Vector2(r * 0.8, r * 1.4)), color, false, w)
			CameraFraming.View.TOP:
				draw_rect(Rect2(c - Vector2(r, r * 0.7), Vector2(r * 2.0, r * 1.4)), color, false, w)
				draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.3), Vector2(r * 0.5, r * 0.6)), color, false, w)
				draw_circle(c + Vector2(r * 0.5, r * 0.1), r * 0.18, color)
			CameraFraming.View.TURN:
				draw_arc(c, r, PI * 0.15, PI * 1.6, 32, color, w)
				var tip: Vector2 = c + Vector2(cos(PI * 0.15), sin(PI * 0.15)) * r
				draw_line(tip, tip + Vector2(-r * 0.45, -r * 0.1), color, w)
				draw_line(tip, tip + Vector2(0.05 * r, -r * 0.5), color, w)

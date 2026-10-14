extends Button
class_name SdfButton
## A Button whose shape is an [SdfShape] drawn behind its text (docs/ui.md). The theme's style boxes are
## replaced by empty ones, so the field is the only thing drawn. Hover adds a border, a press pulls the shape
## in, and a pressed or toggled-on button fills with the accent, which the theme's pressed font color is set
## against.
##
## `quiet` is for a pill inside a bar: no fill, no relief, until it is the active one.

enum Shape {
	ROUNDED = 0,
	PILL = 1,
	CIRCLE = 2,
}

const CONTENT_MARGIN_PX: float = 20.0
const HOVER_BORDER_PX: float = 3.0
const PRESS_SECONDS: float = 0.08

@export var shape: Shape = Shape.ROUNDED:
	set(value):
		shape = value
		refresh()
@export var quiet: bool = false:
	set(value):
		quiet = value
		refresh()
## Below zero, the style preset's corner radius. A bar or a panel sets a concentric one.
@export var radius_px: float = -1.0:
	set(value):
		radius_px = value
		refresh()

var _shape: SdfShape = null
var _hover: bool = false
var _down: bool = false
var _press_tween: Tween = null

func _init() -> void:
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.set_content_margin_all(CONTENT_MARGIN_PX)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)

func _ready() -> void:
	_shape = SdfShape.new()
	_shape.name = "Shape"
	_shape.show_behind_parent = true
	_shape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shape)
	move_child(_shape, 0)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	toggled.connect(_on_toggled)
	Style.changed.connect(_on_style_changed)
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		refresh()

## Whether the button shows as active: held down, or toggled on.
func is_active() -> bool:
	return _down or button_pressed

## Redraw the shape for the current state. Called on every signal that changes it, and by whoever sets the
## pressed state without a signal.
func refresh() -> void:
	if _shape == null:
		return
	var preset: StylePreset = Style.current
	var active: bool = is_active()
	var shape_radius: float = radius_px
	if shape_radius < 0.0:
		shape_radius = float(preset.corner_radius)
	match shape:
		Shape.PILL, Shape.CIRCLE:
			_shape.radius_px = UiGeometry.pill_radius(size)
		_:
			_shape.radius_px = UiGeometry.rounded_radius(size, shape_radius)
	if active:
		_shape.fill = preset.accent
	elif disabled:
		_shape.fill = preset.surface.lerp(preset.background, 0.5)
	elif quiet:
		_shape.fill = Color(preset.surface, 0.0)
	else:
		_shape.fill = preset.surface
	_shape.border_px = HOVER_BORDER_PX if _hover and not active and not disabled else 0.0
	_shape.border_color = preset.accent
	_shape.relief = 0.0 if quiet else -1.0

func _on_down() -> void:
	_down = true
	refresh()
	_animate_press(1.0)

func _on_up() -> void:
	_down = false
	refresh()
	_animate_press(0.0)

func _animate_press(target: float) -> void:
	var scale_factor: float = Style.motion_scale()
	if _press_tween != null:
		_press_tween.kill()
		_press_tween = null
	if scale_factor <= 0.0:
		_shape.press = target
		return
	_press_tween = create_tween()
	_press_tween.tween_property(_shape, "press", target, PRESS_SECONDS * scale_factor)

func _on_hover(inside: bool) -> void:
	_hover = inside
	refresh()

func _on_toggled(_on: bool) -> void:
	refresh()

func _on_style_changed(_preset: StylePreset) -> void:
	refresh()

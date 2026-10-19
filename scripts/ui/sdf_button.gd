extends Button
class_name SdfButton
## A Button whose shape is an [SdfShape] drawn behind its text (docs/ui.md). The theme's style boxes are
## replaced by empty ones, so the field is the only thing drawn. Hover adds a border, a press pulls the shape
## in, and a pressed or toggled-on button fills with the accent, which the theme's pressed font color is set
## against.
##
## `quiet` is for a pill inside a bar: no fill, no relief, until it is the active one. `primary` is the one
## button on a screen that does the thing: always the accent. `danger` marks destructive actions in red.

enum Shape {
	ROUNDED = 0,
	PILL = 1,
	CIRCLE = 2,
}

const CONTENT_MARGIN_PX: float = 20.0
const HOVER_BORDER_PX: float = 3.0
const PRESS_SECONDS: float = 0.08
const DANGER_FILL: Color = Color("b4232d")

@export var shape: Shape = Shape.ROUNDED:
	set(value):
		shape = value
		refresh()
@export var quiet: bool = false:
	set(value):
		quiet = value
		refresh()
@export var primary: bool = false:
	set(value):
		primary = value
		refresh()
@export var danger: bool = false:
	set(value):
		danger = value
		refresh()
## Below zero, the style preset's corner radius. A bar or a panel sets a concentric one.
@export var radius_px: float = -1.0:
	set(value):
		radius_px = value
		refresh()

var _declared_min_size: Vector2 = Vector2.ZERO
var _touch_min_size: Vector2 = -Vector2.ONE
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
	_declared_min_size = custom_minimum_size
	Style.fonts_changed.connect(_fit_touch_size)
	_fit_touch_size()
	# A swipe beginning on a button must reach its enclosing scroll container.
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			mouse_filter = Control.MOUSE_FILTER_PASS
			break
		ancestor = ancestor.get_parent()
	_shape = SdfShape.new()
	_shape.name = "Shape"
	_shape.show_behind_parent = true
	_shape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shape)
	move_child(_shape, 0)
	button_down.connect(_on_shape_down)
	button_up.connect(_on_shape_up)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	toggled.connect(_on_toggled)
	focus_entered.connect(refresh)
	focus_exited.connect(refresh)
	Style.changed.connect(_on_style_changed)
	refresh()

func _fit_touch_size() -> void:
	for axis: int in 2:
		if not is_equal_approx(custom_minimum_size[axis], _touch_min_size[axis]):
			_declared_min_size[axis] = custom_minimum_size[axis]
	_touch_min_size = _declared_min_size.max(Vector2.ONE * Style.units_per_point * 44.0)
	custom_minimum_size = _touch_min_size

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
	if disabled:
		_shape.fill = preset.surface.lerp(preset.background, 0.5)
	elif danger:
		_shape.fill = DANGER_FILL.darkened(0.15) if active else DANGER_FILL
	elif active or primary:
		_shape.fill = preset.accent
	elif quiet:
		_shape.fill = Color(preset.surface, 0.0)
	else:
		_shape.fill = preset.surface
	_shape.border_px = HOVER_BORDER_PX if (_hover or has_focus()) and not disabled else 0.0
	_shape.border_color = preset.surface if primary or active else preset.accent
	if danger:
		_shape.border_color = Color.WHITE
	_shape.relief = 0.0 if quiet else -1.0
	for color_name: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		if danger:
			add_theme_color_override(color_name, Color.WHITE)
		elif primary:
			add_theme_color_override(color_name, preset.surface)
		else:
			remove_theme_color_override(color_name)

# Named for the shape so a subclass with its own press handlers, HoldButton, never overrides these.
func _on_shape_down() -> void:
	_down = true
	refresh()
	_animate_press(1.0)

func _on_shape_up() -> void:
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

func _make_custom_tooltip(for_text: String) -> Object:
	var panel: SdfPanel = SdfPanel.new()
	var label: Label = Label.new()
	label.text = for_text
	panel.add_child(label)
	return panel

extends TextEdit
class_name SdfTextArea
## A TextEdit whose box is an [SdfShape] drawn behind its text (docs/ui.md), the multi-line partner of
## [SdfField]. The theme's style boxes are replaced by empty ones; focus adds the accent border. It wraps,
## grows with its text from a few lines, and never scrolls sideways.

const CONTENT_MARGIN_PX: float = 20.0
const FOCUS_BORDER_PX: float = 3.0
const MIN_HEIGHT_PX: float = 132.0

var _shape: SdfShape = null
var _pointer_down: bool = false
var _pointer_start: Vector2 = Vector2.ZERO
var _pointer_dragged: bool = false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	virtual_keyboard_show_on_focus = false
	virtual_keyboard_enabled = false
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.set_content_margin_all(CONTENT_MARGIN_PX)
	for state: String in ["normal", "focus", "read_only"]:
		add_theme_stylebox_override(state, empty)
	wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	scroll_fit_content_height = true
	custom_minimum_size = Vector2(0.0, MIN_HEIGHT_PX)

func _ready() -> void:
	_shape = SdfShape.new()
	_shape.name = "Shape"
	_shape.show_behind_parent = true
	_shape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shape)
	move_child(_shape, 0)
	focus_entered.connect(refresh)
	focus_exited.connect(refresh)
	focus_exited.connect(_end_text_entry)
	visibility_changed.connect(_on_visibility_changed)
	Style.changed.connect(_on_style_changed)
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		refresh()

func refresh() -> void:
	if _shape == null:
		return
	var preset: StylePreset = Style.current
	_shape.radius_px = UiGeometry.rounded_radius(size, float(preset.corner_radius))
	_shape.fill = preset.surface.lerp(preset.background, 0.35)
	_shape.border_px = FOCUS_BORDER_PX if has_focus() else 1.0
	_shape.border_color = preset.accent if has_focus() else preset.text.lerp(preset.surface, 0.82)
	_shape.relief = 0.0
	add_theme_color_override("font_color", preset.text)
	add_theme_color_override("font_placeholder_color", preset.text.lerp(preset.background, 0.3))
	add_theme_color_override("caret_color", preset.accent)

func _on_style_changed(_preset: StylePreset) -> void:
	refresh()

## Native TextEdit requests its keyboard on mouse release, even after a sheet drag released focus.
## Permit that request only for a press received by this field followed by a short, focused release.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_pointer_down = true
			_pointer_start = get_global_transform_with_canvas() * mouse.position
			_pointer_dragged = false
			virtual_keyboard_enabled = false

func _input(event: InputEvent) -> void:
	if not _pointer_down:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		var deadzone: int = ProjectSettings.get_setting("gui/common/default_scroll_deadzone", 24)
		_pointer_dragged = _pointer_dragged or motion.position.distance_to(_pointer_start) >= deadzone
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
			var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * mouse.position
			var deadzone: int = ProjectSettings.get_setting("gui/common/default_scroll_deadzone", 24)
			var tap: bool = not _pointer_dragged and mouse.position.distance_to(_pointer_start) < deadzone
			virtual_keyboard_enabled = tap and has_focus() and is_visible_in_tree() and Rect2(Vector2.ZERO, size).has_point(local)
			# Native GUI handling consumes this event before deferred calls run. Later releases cannot reopen it.
			set_deferred("virtual_keyboard_enabled", false)
			_pointer_down = false

func _end_text_entry() -> void:
	_pointer_down = false
	virtual_keyboard_enabled = false
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_end_text_entry()

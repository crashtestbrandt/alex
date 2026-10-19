extends SdfScroll
class_name SdfSheet
## A centered caregiver panel that fits its width and scrolls when its content is taller than the screen.

@export var panel_width: float = 760.0
var _content: Control = null
var _panel: Control = null
var _keyboard_overlap: float = 0.0
var _scroll_revision: int = 0

func _ready() -> void:
	super()
	scroll_started.connect(dismiss_text_entry)
	_panel = get_child(0) as Control
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_content)
	_panel.reparent(_content)
	_panel.custom_minimum_size.x = 0.0
	resized.connect(_schedule_layout)
	Style.fonts_changed.connect(_schedule_layout)
	visibility_changed.connect(_schedule_layout)
	_content.resized.connect(_schedule_layout)
	_panel.minimum_size_changed.connect(_schedule_layout)
	_schedule_layout()

func _schedule_layout() -> void:
	_layout_sheet.call_deferred()

func _layout_sheet() -> void:
	if not is_visible_in_tree():
		return
	var width: float = minf(maxf(panel_width, 520.0 * Style.units_per_point), maxf(_content.size.x - 48.0, 1.0))
	_panel.size.x = width
	_panel.size.y = _panel.get_combined_minimum_size().y
	_content.custom_minimum_size.y = _panel.size.y + 48.0
	_panel.position = Vector2((_content.size.x - width) / 2.0, maxf(24.0, (_content.size.y - _panel.size.y) / 2.0))

## A tap outside a text entry dismisses the keyboard without consuming the tapped action.
func _input(event: InputEvent) -> void:
	super(event)
	if not is_visible_in_tree():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if not (focus is LineEdit or focus is TextEdit) or not is_ancestor_of(focus):
		return
	var point: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		point = mouse.position
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if not touch.pressed:
			return
		point = touch.position
	else:
		return
	var local: Vector2 = focus.get_global_transform_with_canvas().affine_inverse() * point
	if not Rect2(Vector2.ZERO, focus.size).has_point(local):
		dismiss_text_entry()

func dismiss_text_entry() -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	if (focus is LineEdit or focus is TextEdit) and is_ancestor_of(focus):
		focus.release_focus()
	# Focus may already belong to Save, or have been cleared by hiding the field.
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

## iOS overlays its keyboard without resizing the window. Keep the sheet's scrolling area above it.
func _process(delta: float) -> void:
	super(delta)
	var keyboard: int = 0
	if is_visible_in_tree() and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		keyboard = DisplayServer.virtual_keyboard_get_height()
	_fit_keyboard(keyboard)

func _fit_keyboard(height_px: int) -> void:
	var overlap: float = 0.0
	if height_px > 0:
		var pixels: Transform2D = get_viewport().get_final_transform() * get_global_transform()
		var keyboard_top: float = (pixels.affine_inverse() * Vector2(0, get_window().size.y - height_px)).y
		overlap = clampf(size.y + _keyboard_overlap - keyboard_top, 0.0, maxf(size.y + _keyboard_overlap - 96.0, 0.0))
	if absf(overlap - _keyboard_overlap) > 0.5:
		_keyboard_overlap = overlap
		offset_bottom = -overlap
		_keep_entry_visible.call_deferred()

func _keep_entry_visible() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var focus: Control = get_viewport().gui_get_focus_owner()
	if (focus is LineEdit or focus is TextEdit) and is_ancestor_of(focus):
		ensure_control_visible(focus)

## Rebuilding a scene's controls must not jump to the top when their minimum sizes settle.
func restore_scroll_after_layout(position_y: int) -> void:
	_scroll_revision += 1
	var revision: int = _scroll_revision
	await get_tree().process_frame
	await get_tree().process_frame
	if revision == _scroll_revision and is_visible_in_tree():
		scroll_vertical = position_y

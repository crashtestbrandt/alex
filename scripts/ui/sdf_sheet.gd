extends SdfScroll
class_name SdfSheet
## A centered caregiver panel that fits its width and scrolls when its content is taller than the screen.

@export var panel_width: float = 760.0
var _content: Control = null
var _panel: Control = null

func _ready() -> void:
	super()
	_panel = get_child(0) as Control
	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_content)
	_panel.reparent(_content)
	_panel.custom_minimum_size.x = 0.0
	resized.connect(_schedule_layout)
	visibility_changed.connect(_schedule_layout)
	_content.resized.connect(_schedule_layout)
	_panel.minimum_size_changed.connect(_schedule_layout)
	_schedule_layout()

func _schedule_layout() -> void:
	_layout_sheet.call_deferred()

func _layout_sheet() -> void:
	if not is_visible_in_tree():
		return
	var width: float = minf(panel_width, maxf(_content.size.x - 48.0, 1.0))
	_panel.size.x = width
	_panel.size.y = _panel.get_combined_minimum_size().y
	_content.custom_minimum_size.y = _panel.size.y + 48.0
	_panel.position = Vector2((_content.size.x - width) / 2.0, maxf(24.0, (_content.size.y - _panel.size.y) / 2.0))

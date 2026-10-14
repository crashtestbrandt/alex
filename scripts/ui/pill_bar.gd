extends MarginContainer
class_name PillBar
## A floating pill that holds a row of quiet pill buttons, one of them active (docs/ui.md). The bar's corner is
## half its height and every button inside takes the concentric radius. The place strip and the view widget
## are both one of these.

const PAD_PX: float = 8.0
const GAP_PX: int = 6

var _shape: SdfShape = null
var _row: HFlowContainer = HFlowContainer.new()
var _group: ButtonGroup = ButtonGroup.new()

func _init() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		add_theme_constant_override(side, int(PAD_PX))
	mouse_filter = Control.MOUSE_FILTER_PASS
	_row.name = "Row"
	_row.add_theme_constant_override("h_separation", GAP_PX)
	_row.add_theme_constant_override("v_separation", GAP_PX)
	_row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_row)

func _ready() -> void:
	_shape = SdfShape.new()
	_shape.name = "Shape"
	_shape.show_behind_parent = true
	add_child(_shape)
	move_child(_shape, 0)
	# A container lays its children out inside its margins, the shape included. It is pinned back to the full
	# rect after every sort, so the drawn panel is the panel and not its content box.
	sort_children.connect(_place_shape)
	Style.changed.connect(_on_style_changed)
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh()

func _place_shape() -> void:
	_shape.position = Vector2.ZERO
	_shape.size = size

## Put a button in the bar as a quiet pill in the bar's toggle group.
func add_item(button: SdfButton) -> void:
	button.quiet = true
	button.shape = SdfButton.Shape.PILL
	button.toggle_mode = true
	button.button_group = _group
	button.focus_mode = Control.FOCUS_ALL
	_row.add_child(button)
	_refresh()

func fit_width(available: float) -> void:
	var natural: float = PAD_PX * 2.0
	var count: int = 0
	for button: SdfButton in items():
		if button.visible:
			natural += button.get_combined_minimum_size().x
			count += 1
	natural += maxf(count - 1, 0) * GAP_PX
	custom_minimum_size.x = minf(natural, available)

func items() -> Array[SdfButton]:
	var out: Array[SdfButton] = []
	for child: Node in _row.get_children():
		if child is SdfButton:
			out.push_back(child)
	return out

## The index of the pressed item, or -1.
func active_index() -> int:
	var all: Array[SdfButton] = items()
	for i: int in all.size():
		if all[i].button_pressed:
			return i
	return -1

## Press item `index` without a signal.
func set_active(index: int) -> void:
	var all: Array[SdfButton] = items()
	if index < 0 or index >= all.size():
		return
	for button: SdfButton in all:
		button.set_pressed_no_signal(button == all[index])
		button.refresh()

func clear() -> void:
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()

func _refresh() -> void:
	if _shape == null:
		return
	_shape.radius_px = UiGeometry.pill_radius(size)
	_shape.fill = Style.current.surface
	var inner: float = UiGeometry.concentric(_shape.radius_px, PAD_PX)
	for button: SdfButton in items():
		button.radius_px = inner

func _on_style_changed(_preset: StylePreset) -> void:
	_refresh()

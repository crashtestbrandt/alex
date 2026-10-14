extends PanelContainer
class_name SdfPanel
## A PanelContainer whose panel is an [SdfShape] drawn behind its content (docs/ui.md). Its radius is larger
## than a button's, and [method inner_radius] is what a control inside it takes to stay concentric.

const CONTENT_MARGIN_PX: float = 28.0
const RADIUS_SCALE: float = 1.6

var _shape: SdfShape = null

func _init() -> void:
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.set_content_margin_all(CONTENT_MARGIN_PX)
	add_theme_stylebox_override("panel", empty)

func _ready() -> void:
	_shape = SdfShape.new()
	_shape.name = "Shape"
	_shape.show_behind_parent = true
	add_child(_shape)
	move_child(_shape, 0)
	# A container lays its children out inside its margins, the shape included. It is pinned back to the full
	# rect after every sort, so the drawn panel is the panel and not its content box.
	sort_children.connect(_place_shape)
	visibility_changed.connect(_schedule_layout)
	minimum_size_changed.connect(_schedule_layout)
	resized.connect(_schedule_layout)
	Style.changed.connect(_on_style_changed)
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh()

func _place_shape() -> void:
	_shape.position = Vector2.ZERO
	_shape.size = size
	var inset: Vector2 = Vector2.ONE * CONTENT_MARGIN_PX
	for child: Node in get_children():
		if child is Control and child != _shape:
			fit_child_in_rect(child as Control, Rect2(inset, size - inset * 2.0))

func _schedule_layout() -> void:
	_place_shape.call_deferred()

func radius() -> float:
	return UiGeometry.rounded_radius(size, Style.current.corner_radius * RADIUS_SCALE)

## The radius a control sitting at the panel's content margin takes.
func inner_radius() -> float:
	return UiGeometry.concentric(radius(), CONTENT_MARGIN_PX)

func _refresh() -> void:
	if _shape == null:
		return
	_shape.radius_px = radius()
	_shape.fill = Style.current.surface
	for child: Node in get_children():
		if child is SdfButton:
			var button: SdfButton = child
			button.radius_px = inner_radius()

func _on_style_changed(_preset: StylePreset) -> void:
	_refresh()

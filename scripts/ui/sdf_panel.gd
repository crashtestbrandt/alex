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
	_shape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shape)
	move_child(_shape, 0)
	Style.changed.connect(_on_style_changed)
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh()

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

extends TextEdit
class_name SdfTextArea
## A TextEdit whose box is an [SdfShape] drawn behind its text (docs/ui.md), the multi-line partner of
## [SdfField]. The theme's style boxes are replaced by empty ones; focus adds the accent border. It wraps,
## grows with its text from a few lines, and never scrolls sideways.

const CONTENT_MARGIN_PX: float = 20.0
const FOCUS_BORDER_PX: float = 3.0
const MIN_HEIGHT_PX: float = 132.0

var _shape: SdfShape = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
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

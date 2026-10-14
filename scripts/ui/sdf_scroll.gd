extends ScrollContainer
class_name SdfScroll
## Native scrolling and keyboard navigation with a distance-field scrollbar.

var _thumb: SdfShape = null

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	var bar: VScrollBar = get_v_scroll_bar()
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.content_margin_left = 8.0
	empty.content_margin_right = 8.0
	for state: String in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, empty)
	_thumb = SdfShape.new()
	_thumb.relief = 0.0
	bar.add_child(_thumb)
	bar.changed.connect(_update_thumb)
	bar.value_changed.connect(func(_value: float) -> void: _update_thumb())
	bar.resized.connect(_update_thumb)
	Style.changed.connect(func(_preset: StylePreset) -> void: _update_thumb())
	_update_thumb()

func _update_thumb() -> void:
	var bar: VScrollBar = get_v_scroll_bar()
	var span: float = maxf(bar.max_value - bar.min_value, 1.0)
	var height: float = clampf(bar.size.y * bar.page / span, 24.0, maxf(bar.size.y, 24.0))
	var travel: float = maxf(bar.size.y - height, 0.0)
	_thumb.position = Vector2(4.0, travel * (bar.value - bar.min_value) / maxf(span - bar.page, 1.0))
	_thumb.size = Vector2(8.0, height)
	_thumb.radius_px = 4.0
	_thumb.fill = Style.current.text.lerp(Style.current.surface, 0.55)

extends ScrollContainer
class_name SdfScroll
## Native scrolling and keyboard navigation with a distance-field scrollbar, and a rubber band at both ends.
##
## A drag past an end moves the content less and less ([Overscroll]), and a release springs it back. A fling that
## hits an end carries a little past it and settles. Only content taller than the view bands. Every spring
## multiplies by `Style.motion_scale()`, and at motion NONE the content returns at once.
##
## The band starts past the scroll deadzone, so a tap or a hold on a button inside never moves the content.

## How long the content takes to return after a release, before the style's motion scale.
const RETURN_SECONDS: float = 0.4
## How long a fling takes to carry past an end, before it returns.
const FLING_OUT_SECONDS: float = 0.12
## Content moving slower than this when it reaches an end stops there, in pixels a second.
const FLING_MIN_SPEED: float = 600.0
## How long after a drag's release the native inertia may still carry the content into an end. A jump to the
## top when a screen opens is not a fling, and outside this window it does not bounce.
const FLING_WINDOW_SECONDS: float = 1.5

var _thumb: SdfShape = null
var _pull: float = 0.0
var _shown: float = 0.0
var _touching: bool = false
var _travel: float = 0.0
var _spring: Tween = null
var _last_scroll: int = 0
var _last_step: int = 0
var _since_drag: float = INF

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
	sort_children.connect(_offset_content)
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

## The distance the content shows past an end, down positive. Zero at rest.
func overscroll() -> float:
	return _shown

# Mouse events, like the native drag: with touch emulated from the mouse and the mouse from touch, a finger and
# a mouse both arrive as these, and accepting one keeps the native drag from also scrolling it.
func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_touching = true
			_travel = 0.0
			_stop_spring()
			_pull = Overscroll.unband(_shown, size.y)
		else:
			_touching = false
			# Only a release that ends a drag hands the content to the native inertia.
			if _travel >= _deadzone():
				_since_drag = 0.0
			_return()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null or not _touching or (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	_travel += absf(motion.relative.y)
	if _travel < _deadzone() or not _scrollable():
		return
	var next: float = Overscroll.drag(_pull, motion.relative.y, scroll_vertical <= 0, scroll_vertical >= _max_scroll())
	if _pull == 0.0 and next == 0.0:
		return
	# The band owns this step. The native drag never sees it, so the content does not scroll as well.
	_pull = next
	_show(Overscroll.band(_pull, size.y))
	accept_event()

## The travel before a press becomes a drag: the container's own deadzone, or the project's when it has none.
func _deadzone() -> float:
	var project: int = ProjectSettings.get_setting("gui/common/default_scroll_deadzone", 0)
	return float(maxi(scroll_deadzone, project))

func _process(delta: float) -> void:
	var scroll: int = scroll_vertical
	_since_drag += delta
	var coasting: bool = _since_drag < FLING_WINDOW_SECONDS
	var step: int = scroll - _last_scroll
	if coasting and not _touching and _spring == null and _shown == 0.0 and delta > 0.0 and _scrollable():
		var speed: float = float(-step) / delta
		var hit_top: bool = scroll <= 0 and _last_scroll > 0
		var hit_bottom: bool = scroll >= _max_scroll() and _last_scroll < _max_scroll()
		# Inertia moves the content toward the end over several frames. A jump moves it in one, from rest.
		var carried: bool = _last_step != 0 and signi(_last_step) == signi(step)
		if (hit_top or hit_bottom) and carried and absf(speed) >= FLING_MIN_SPEED:
			_fling(speed)
	_last_step = step
	_last_scroll = scroll

func _scrollable() -> bool:
	return _max_scroll() > 0

func _max_scroll() -> int:
	var bar: VScrollBar = get_v_scroll_bar()
	return maxi(int(bar.max_value - bar.page), 0)

func _show(shown: float) -> void:
	_shown = shown
	queue_sort()

## Runs after the container places its content, so the band moves the content from where scrolling put it.
func _offset_content() -> void:
	if _shown == 0.0:
		return
	for child: Node in get_children():
		var content: Control = child as Control
		if content != null and not (content is ScrollBar) and content.visible:
			content.position.y += _shown

func _return() -> void:
	_pull = 0.0
	if _shown == 0.0:
		return
	var seconds: float = RETURN_SECONDS * Style.motion_scale()
	if seconds <= 0.0:
		_show(0.0)
		return
	_stop_spring()
	_spring = create_tween()
	_spring.tween_method(_show, _shown, 0.0, seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_spring.finished.connect(_stop_spring)

func _fling(speed: float) -> void:
	var scale: float = Style.motion_scale()
	var carry: float = Overscroll.fling(speed, size.y)
	if scale <= 0.0 or carry == 0.0:
		return
	_stop_spring()
	_spring = create_tween()
	_spring.tween_method(_show, 0.0, carry, FLING_OUT_SECONDS * scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_spring.tween_method(_show, carry, 0.0, RETURN_SECONDS * scale).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_spring.finished.connect(_stop_spring)

func _stop_spring() -> void:
	if _spring != null:
		_spring.kill()
		_spring = null

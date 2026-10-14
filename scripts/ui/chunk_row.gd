extends HFlowContainer
class_name ChunkRow
## A gestalt's chunks as a wrapping row of pills (docs/ui.md "Chunk colors"). Each pill is an [SdfShape] filled
## with its chunk's color (ChunkColors) behind a label in the style's text color, so contrast holds in every
## preset. The tile on a board and the caption in the room are both one of these. A caption floats over the
## room with no card behind it, so its pills take the style's relief; a tile's pills sit flat on the tile.
##
## While the phrase plays, the chunk being spoken grows a little, by `SPOKEN_GROWTH` times
## [method Style.motion_scale]. At motion NONE it brightens instead, keeping its hue. The schedule follows the
## audio, so its intervals are not scaled; only the growth tween is.

const GAP_PX: int = 12
const PAD_X_PX: float = 14.0
const PAD_Y_PX: float = 6.0
const SPOKEN_GROWTH: float = 0.1
const SPOKEN_SECONDS: float = 0.12
## The shortest a phrase is paced over, so a fast one still shows each chunk.
const MIN_PHRASE_SECONDS: float = 0.6

## Whether the pills stand off what is behind them with the style's relief: the rim and the shadow.
var floating: bool = false:
	set(value):
		floating = value
		for pill: Pill in _pills:
			pill.set_floating(value)

var _pills: Array[Pill] = []
var _tween: Tween = null

func _init() -> void:
	alignment = FlowContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("h_separation", GAP_PX)
	add_theme_constant_override("v_separation", GAP_PX)

## Replace the pills with one per chunk, lettered at `font_base` scaled by the style.
func set_chunks(chunks: PackedStringArray, font_base: int) -> void:
	stop()
	for pill: Pill in _pills:
		remove_child(pill)
		pill.queue_free()
	_pills.clear()
	for chunk: String in chunks:
		var pill: Pill = Pill.new(chunk, Style.font_px(font_base))
		pill.set_floating(floating)
		add_child(pill)
		_pills.push_back(pill)

## Cap every pill at `width`. A chunk wider than that wraps inside its pill.
func fit_width(width: float) -> void:
	for pill: Pill in _pills:
		pill.fit_width(width)

## The width the pills take on one line, gaps included.
func natural_width() -> float:
	var total: float = 0.0
	for pill: Pill in _pills:
		total += pill.get_combined_minimum_size().x
	return total + maxf(_pills.size() - 1, 0) * GAP_PX

func pills() -> Array[Pill]:
	return _pills

## Mark each chunk as spoken in turn across `seconds`, then settle.
func play(seconds: float) -> void:
	stop()
	if _pills.is_empty():
		return
	var per_chunk: float = maxf(seconds, MIN_PHRASE_SECONDS) / _pills.size()
	_tween = create_tween()
	for pill: Pill in _pills:
		_tween.tween_callback(pill.set_spoken.bind(true))
		_tween.tween_interval(per_chunk)
		_tween.tween_callback(pill.set_spoken.bind(false))

## Mark one chunk as spoken for `seconds`, then settle. For a chunk that has just landed on a strip.
func play_one(index: int, seconds: float) -> void:
	stop()
	if index < 0 or index >= _pills.size():
		return
	var pill: Pill = _pills[index]
	_tween = create_tween()
	_tween.tween_callback(pill.set_spoken.bind(true))
	_tween.tween_interval(maxf(seconds, MIN_PHRASE_SECONDS))
	_tween.tween_callback(pill.set_spoken.bind(false))

## The index of the pill under `point`, in this row's coordinates, or -1 between pills.
func pill_at(point: Vector2) -> int:
	for i: int in _pills.size():
		if _pills[i].get_rect().has_point(point):
			return i
	return -1

## End a playback early and put every pill back at rest.
func stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	for pill: Pill in _pills:
		pill.set_spoken(false)

## One chunk's pill. The flow container lays out this wrapper; the body inside it is what grows. A container
## resets the scale of the children it sorts, so the scaled body sits one level down.
class Pill extends Control:
	var text: String = ""
	var _font_px: int = 24
	var _body: MarginContainer = MarginContainer.new()
	var _shape: SdfShape = SdfShape.new()
	var _label: Label = Label.new()
	var _spoken: bool = false
	var _grow: Tween = null

	func _init(chunk: String, font_px: int) -> void:
		text = chunk
		_font_px = font_px
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_theme_constant_override("margin_left", int(ChunkRow.PAD_X_PX))
		_body.add_theme_constant_override("margin_right", int(ChunkRow.PAD_X_PX))
		_body.add_theme_constant_override("margin_top", int(ChunkRow.PAD_Y_PX))
		_body.add_theme_constant_override("margin_bottom", int(ChunkRow.PAD_Y_PX))
		_shape.name = "Shape"
		_shape.relief = 0.0
		_label.text = chunk
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_font_size_override("font_size", font_px)
		_body.add_child(_shape)
		_body.add_child(_label)
		add_child(_body)
		# The container lays the shape out inside its margins too. Pin it back to the full body after every sort.
		_body.sort_children.connect(_place_shape)
		_body.minimum_size_changed.connect(update_minimum_size)
		resized.connect(_fit_body)
		fit_width(INF)

	func _ready() -> void:
		Style.changed.connect(_on_style_changed)
		refresh()

	func _get_minimum_size() -> Vector2:
		return _body.get_combined_minimum_size()

	## The identity color at rest.
	func color() -> Color:
		return ChunkColors.color_for(text, Style.current.chunk_palette)

	## What the pill draws right now: the identity color, brightened while spoken at motion NONE.
	func fill() -> Color:
		return _shape.fill

	func is_spoken() -> bool:
		return _spoken

	func body_scale() -> Vector2:
		return _body.scale

	## Below zero, the shape takes the style preset's relief.
	func set_floating(on: bool) -> void:
		_shape.relief = -1.0 if on else 0.0

	func relief() -> float:
		return _shape.relief

	func fit_width(width: float) -> void:
		var font: Font = _label.get_theme_font("font")
		var text_width: float = ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_px).x) + 2.0
		_label.custom_minimum_size.x = minf(text_width, maxf(width - ChunkRow.PAD_X_PX * 2.0, 1.0))

	func set_spoken(on: bool) -> void:
		if _grow != null:
			_grow.kill()
			_grow = null
		_spoken = on
		var motion: float = Style.motion_scale()
		if motion <= 0.0:
			_body.scale = Vector2.ONE
			refresh()
			return
		refresh()
		var target: Vector2 = Vector2.ONE * (1.0 + ChunkRow.SPOKEN_GROWTH * motion) if on else Vector2.ONE
		if not is_inside_tree() or _body.scale == target:
			_body.scale = target
			return
		_grow = create_tween()
		_grow.tween_property(_body, "scale", target, ChunkRow.SPOKEN_SECONDS * motion)

	func refresh() -> void:
		var rest: Color = color()
		var bright: bool = _spoken and Style.motion_scale() <= 0.0
		_shape.fill = ChunkColors.spoken(rest) if bright else rest
		_shape.radius_px = UiGeometry.pill_radius(_body.size)
		_label.add_theme_color_override("font_color", Style.current.text)

	func _place_shape() -> void:
		_shape.position = Vector2.ZERO
		_shape.size = _body.size
		_shape.radius_px = UiGeometry.pill_radius(_body.size)

	func _fit_body() -> void:
		_body.size = size
		_body.pivot_offset = size / 2.0

	func _on_style_changed(_preset: StylePreset) -> void:
		refresh()

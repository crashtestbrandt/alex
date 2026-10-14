extends HoldButton
class_name GestaltTile
## One tile on a board. Tapping it says the gestalt. While it plays, the chunks pull apart and light up one
## after another, so the child sees where the seams are (docs/design.md "Making chunks visible"). A gestalt
## with one chunk stays whole. Holding the tile fires `held` (from [HoldButton]) for the recording flow.

signal tapped(gestalt: Gestalt)

const _SPREAD_PX: float = 14.0
const _SPREAD_SECONDS: float = 0.25

var gestalt: Gestalt = null

@onready var _chunks: HFlowContainer = %Chunks

var _labels: Array[Label] = []
var _tween: Tween = null

func _ready() -> void:
	super()
	hold_seconds = 2.0
	pressed.connect(_on_pressed)
	button_down.connect(_on_text_down)
	button_up.connect(_refresh_text)
	resized.connect(_layout_chunks)
	_chunks.minimum_size_changed.connect(_layout_chunks)
	custom_minimum_size = Vector2(Style.current.tile_min_size, Style.current.tile_min_size)
	if gestalt != null:
		_build_labels()

func set_gestalt(g: Gestalt) -> void:
	gestalt = g
	if is_node_ready():
		_build_labels()

## Pull the chunks apart for the length of the utterance, then settle. Reads the style's motion scale and
## does nothing at zero.
func play_split(seconds: float) -> void:
	var scale: float = Style.motion_scale()
	if scale <= 0.0 or _labels.size() < 2:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_chunks.add_theme_constant_override("h_separation", 8)
	_tween.tween_property(_chunks, "theme_override_constants/h_separation", int(8 + _SPREAD_PX), _SPREAD_SECONDS * scale)
	var per_chunk: float = maxf(seconds, 0.4) / _labels.size()
	for i: int in _labels.size():
		var label: Label = _labels[i]
		_tween.tween_property(label, "theme_override_colors/font_color", Style.current.accent, 0.1 * scale).set_delay(per_chunk * i)
		_tween.tween_property(label, "theme_override_colors/font_color", Style.current.text, 0.2 * scale).set_delay(per_chunk * (i + 1))
	_tween.chain().tween_property(_chunks, "theme_override_constants/h_separation", 8, _SPREAD_SECONDS * scale)

func _build_labels() -> void:
	for label: Label in _labels:
		_chunks.remove_child(label)
		label.queue_free()
	_labels.clear()
	for chunk: String in gestalt.chunks:
		var label: Label = Label.new()
		label.text = chunk
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", Style.font_px(24))
		label.add_theme_color_override("font_color", Style.current.text)
		_chunks.add_child(label)
		_labels.push_back(label)
	_layout_chunks()

func _on_text_down() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_chunks.add_theme_constant_override("h_separation", 8)
	_refresh_text()

func _refresh_text() -> void:
	for label: Label in _labels:
		label.add_theme_color_override("font_color", Style.current.surface if is_active() else Style.current.text)

func _layout_chunks() -> void:
	var width: float = maxf(size.x - 40.0, 1.0)
	for label: Label in _labels:
		var font: Font = label.get_theme_font("font")
		var text_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.font_px(24)).x
		label.custom_minimum_size.x = minf(ceilf(text_width) + 2.0, width)
	_chunks.size.x = width
	var height: float = _chunks.get_combined_minimum_size().y
	custom_minimum_size.y = maxf(Style.current.tile_min_size, height + 40.0)
	_chunks.size.y = height
	_chunks.position = Vector2(20.0, maxf((size.y - height) / 2.0, 20.0))

func _on_pressed() -> void:
	if gestalt != null and not consumed_by_hold():
		tapped.emit(gestalt)

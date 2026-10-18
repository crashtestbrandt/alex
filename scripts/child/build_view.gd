extends VBoxContainer
class_name BuildView
## Build: the learner fills a strip with chunks from the bank (docs/ui.md "Words"). Beginnings stand in the
## left column and endings in the right, each a [ChunkButton] in its chunk's color (ChunkBank). A tap on a
## chunk lands it on the strip, a tap on the strip says the whole, and a tap on a chunk in the strip takes it
## off. The strip keeps what the learner built until they change it. The chunks the bank says next
## (ChunkBank.leads) carry a border; every other chunk stays as it is and stays tappable. Nothing is scored,
## nothing is timed, and there is no send button. The home owns the speaking. A hold on a chunk or on the
## strip reports itself for the caregiver's recording flow; a hold is never a tap.

signal chunk_added(chunk: String, index: int)
signal strip_tapped(chunks: PackedStringArray)
signal chunk_held(chunk: String)
signal strip_held(chunks: PackedStringArray)

const FONT_BASE: int = Typography.CAPTION
const MARGIN_PX: float = 20.0

@onready var _strip: HoldButton = %Strip
@onready var _row: ChunkRow = %StripChunks
@onready var _beginnings: VBoxContainer = %Beginnings
@onready var _endings: VBoxContainer = %Endings
@onready var _beginning_spacer: Control = %BeginningSpacer
@onready var _ending_spacer: Control = %EndingSpacer

var _chunks: PackedStringArray = PackedStringArray()
var _gestalts: Array[Gestalt] = []
var _press_point: Vector2 = Vector2.ZERO

func _ready() -> void:
	_strip.button_down.connect(_on_strip_down)
	_strip.pressed.connect(_on_strip_pressed)
	_strip.held.connect(_on_strip_held)
	_strip.resized.connect(_layout_strip)
	_row.minimum_size_changed.connect(_layout_strip)
	Style.changed.connect(_on_style_changed)
	_rebuild_strip()

## Offer `gestalts`' beginnings and endings. The strip keeps its chunks.
func set_bank(gestalts: Array[Gestalt]) -> void:
	_gestalts = gestalts
	_fill(_beginnings, ChunkBank.beginnings(gestalts), _beginning_spacer)
	_fill(_endings, ChunkBank.endings(gestalts), _ending_spacer)
	_rebuild_strip()

## What the strip says right now, in order.
func chunks() -> PackedStringArray:
	return _chunks.duplicate()

func add_chunk(chunk: String) -> void:
	_chunks.push_back(chunk)
	_rebuild_strip()
	chunk_added.emit(chunk, _chunks.size() - 1)

func remove_chunk(index: int) -> void:
	if index < 0 or index >= _chunks.size():
		return
	_chunks.remove_at(index)
	_rebuild_strip()

func clear() -> void:
	_chunks.clear()
	_rebuild_strip()

## Mark the strip's chunks in turn across `seconds`, the length of the utterance.
func play(seconds: float) -> void:
	_row.play(seconds)

## Mark one chunk of the strip for `seconds`, as it lands.
func play_chunk(index: int, seconds: float) -> void:
	_row.play_one(index, seconds)

func strip_row() -> ChunkRow:
	return _row

func beginning_buttons() -> Array[ChunkButton]:
	return _buttons_in(_beginnings)

func ending_buttons() -> Array[ChunkButton]:
	return _buttons_in(_endings)

## The chunks carrying the border, what the bank says next, beginnings first.
func lead_buttons() -> Array[ChunkButton]:
	var out: Array[ChunkButton] = []
	for button: ChunkButton in beginning_buttons() + ending_buttons():
		if button.lead:
			out.push_back(button)
	return out

## Leave `px` clear at the bottom of each column, for a control floating over it.
func set_bottom_clearance(px: float) -> void:
	_beginning_spacer.custom_minimum_size.y = maxf(px, 0.0)
	_ending_spacer.custom_minimum_size.y = maxf(px, 0.0)

func _fill(column: VBoxContainer, chunk_list: PackedStringArray, spacer: Control) -> void:
	for button: ChunkButton in _buttons_in(column):
		column.remove_child(button)
		button.queue_free()
	for chunk: String in chunk_list:
		var button: ChunkButton = ChunkButton.new()
		button.chunk = chunk
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_chunk_pressed.bind(button))
		button.held.connect(_on_chunk_held.bind(chunk))
		column.add_child(button)
	column.move_child(spacer, -1)

func _buttons_in(column: VBoxContainer) -> Array[ChunkButton]:
	var out: Array[ChunkButton] = []
	for child: Node in column.get_children():
		if child is ChunkButton:
			out.push_back(child)
	return out

func _rebuild_strip() -> void:
	if _row == null:
		return
	_row.set_chunks(_chunks, FONT_BASE)
	_layout_strip()
	_mark_leads()

## Border the chunks the bank says next after the strip, in both columns, and clear the rest.
func _mark_leads() -> void:
	var leads: Dictionary[String, bool] = {}
	for chunk: String in ChunkBank.leads(_gestalts, _chunks):
		leads[ChunkColors.key(chunk)] = true
	for button: ChunkButton in beginning_buttons() + ending_buttons():
		button.lead = leads.has(ChunkColors.key(button.chunk))

func _layout_strip() -> void:
	var width: float = maxf(_strip.size.x - MARGIN_PX * 2.0, 1.0)
	_row.fit_width(width)
	_row.size.x = width
	var height: float = _row.get_combined_minimum_size().y
	_strip.custom_minimum_size.y = maxf(Style.current.tile_min_size, height + MARGIN_PX * 2.0)
	_row.size.y = height
	_row.position = Vector2(MARGIN_PX, maxf((_strip.size.y - height) / 2.0, MARGIN_PX))

func _on_strip_down() -> void:
	_press_point = _row.get_local_mouse_position()

## A tap on a chunk lands it on the strip. A hold is not a tap.
func _on_chunk_pressed(button: ChunkButton) -> void:
	if not button.consumed_by_hold():
		add_chunk(button.chunk)

func _on_chunk_held(chunk: String) -> void:
	chunk_held.emit(chunk)

## A hold on a strip with something on it reports its chunks.
func _on_strip_held() -> void:
	if not _chunks.is_empty():
		strip_held.emit(chunks())

## A tap on a chunk takes it off the strip; a tap anywhere else on the strip says the whole. A hold is not
## a tap.
func _on_strip_pressed() -> void:
	if _strip.consumed_by_hold():
		return
	var index: int = _row.pill_at(_press_point)
	if index >= 0:
		remove_chunk(index)
		return
	if not _chunks.is_empty():
		strip_tapped.emit(chunks())

func _on_style_changed(_preset: StylePreset) -> void:
	_layout_strip()

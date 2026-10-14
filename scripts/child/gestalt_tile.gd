extends HoldButton
class_name GestaltTile
## One tile in Words. Tapping it says the gestalt. Its chunks sit on pills in their own colors ([ChunkRow]),
## and while it plays each chunk is marked in turn, so the child sees where the seams are (docs/design.md
## "Making chunks visible"). A gestalt with one chunk stays whole. Holding the tile fires `held` (from
## [HoldButton]) for the recording flow.

signal tapped(gestalt: Gestalt)

const _FONT_BASE: int = 24
const _MARGIN_PX: float = 20.0

var gestalt: Gestalt = null

@onready var _chunks: ChunkRow = %Chunks

func _ready() -> void:
	super()
	hold_seconds = 2.0
	pressed.connect(_on_pressed)
	button_down.connect(_chunks.stop)
	resized.connect(_layout_chunks)
	_chunks.minimum_size_changed.connect(_layout_chunks)
	custom_minimum_size = Vector2(Style.current.tile_min_size, Style.current.tile_min_size)
	if gestalt != null:
		_build_chunks()

func set_gestalt(g: Gestalt) -> void:
	gestalt = g
	if is_node_ready():
		_build_chunks()

## Mark each chunk in turn across `seconds`, the length of the utterance.
func play(seconds: float) -> void:
	_chunks.play(seconds)

func chunk_row() -> ChunkRow:
	return _chunks

func _build_chunks() -> void:
	_chunks.set_chunks(gestalt.chunks, _FONT_BASE)
	_layout_chunks()

func _layout_chunks() -> void:
	var width: float = maxf(size.x - _MARGIN_PX * 2.0, 1.0)
	_chunks.fit_width(width)
	_chunks.size.x = width
	var height: float = _chunks.get_combined_minimum_size().y
	custom_minimum_size.y = maxf(Style.current.tile_min_size, height + _MARGIN_PX * 2.0)
	_chunks.size.y = height
	_chunks.position = Vector2(_MARGIN_PX, maxf((size.y - height) / 2.0, _MARGIN_PX))

func _on_pressed() -> void:
	if gestalt != null and not consumed_by_hold():
		tapped.emit(gestalt)

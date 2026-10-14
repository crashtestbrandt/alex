extends Control
class_name ChildHome
## The learner's screen: one room or board at a time, a strip to move between them, and a held button back
## to the adults' picker. No scores, no timers, no wrong answers (docs/design.md).
##
## Holding a spot or a tile opens the caregiver's recording overlay for that gestalt.

signal profiles_requested

const _TILE_SCENE: PackedScene = preload("res://scenes/child/gestalt_tile.tscn")

@onready var _title: Label = %Title
@onready var _strip: PillBar = %PlaceStrip
@onready var _room_view: RoomView = %RoomView
@onready var _grid: GridContainer = %Board
@onready var _profiles_button: HoldButton = %ProfilesButton
@onready var _speaker: Speaker = %Speaker
@onready var _record_overlay: RecordOverlay = %RecordOverlay

var _profile: Profile = null
var _board: Board = null
var _room: Room = null
var _tiles: Dictionary[String, GestaltTile] = {}
var _places: Dictionary[String, SdfButton] = {}
var _speaking_spot: Spot = null

func _ready() -> void:
	_profiles_button.held.connect(_on_profiles_held)
	_speaker.started.connect(_on_speech_started)
	_room_view.spot_tapped.connect(_on_spot_tapped)
	_room_view.spot_held.connect(_on_spot_held)
	_record_overlay.kept.connect(_on_recording_kept)
	Style.changed.connect(_on_style_changed)

func show_profile(p: Profile) -> void:
	_profile = p
	_title.text = p.display_name
	_build_strip()
	if not p.rooms.is_empty():
		show_room(p.rooms[0])
	elif not p.boards.is_empty():
		show_board(p.boards[0])
	else:
		show_board(_all_gestalts_board(p))

func show_room(r: Room) -> void:
	_speaker.stop()
	_room = r
	_board = null
	_grid.visible = false
	_room_view.visible = true
	_room_view.show_room(_profile, r)
	_show_place("room:" + r.id)

func show_board(b: Board) -> void:
	_speaker.stop()
	_board = b
	_room = null
	_room_view.visible = false
	_grid.visible = true
	for child: Node in _grid.get_children():
		child.queue_free()
	_tiles.clear()
	for g: Gestalt in _profile.board_gestalts(b):
		var tile: GestaltTile = _TILE_SCENE.instantiate() as GestaltTile
		tile.set_gestalt(g)
		tile.tapped.connect(_on_tile_tapped)
		tile.held.connect(_on_tile_held.bind(tile))
		_grid.add_child(tile)
		_tiles[g.id] = tile
	_grid.columns = _columns_for(_tiles.size())
	_show_place("board:" + b.id)

func _build_strip() -> void:
	_strip.clear()
	_places.clear()
	_strip.visible = _profile.rooms.size() + _profile.boards.size() >= 2
	if not _strip.visible:
		return
	for r: Room in _profile.rooms:
		var button: SdfButton = SdfButton.new()
		button.text = r.title
		button.pressed.connect(show_room.bind(r))
		_strip.add_item(button)
		_places["room:" + r.id] = button
	for b: Board in _profile.boards:
		var button: SdfButton = SdfButton.new()
		button.text = b.title
		button.pressed.connect(show_board.bind(b))
		_strip.add_item(button)
		_places["board:" + b.id] = button

func _show_place(key: String) -> void:
	var button: SdfButton = _places.get(key, null)
	if button == null:
		return
	button.set_pressed_no_signal(true)
	for other: SdfButton in _places.values():
		other.refresh()

## A profile with nothing to show lists every gestalt it has.
static func _all_gestalts_board(p: Profile) -> Board:
	var ids: PackedStringArray = PackedStringArray()
	for g: Gestalt in p.gestalts:
		ids.push_back(g.id)
	return Board.make("all", "All", ids)

static func _columns_for(count: int) -> int:
	if count <= 1:
		return 1
	if count <= 4:
		return 2
	return 3

func _say(g: Gestalt) -> void:
	_speaker.say(g, ProfileStore.media_dir(_profile.id))

func _on_spot_tapped(s: Spot, g: Gestalt) -> void:
	_speaking_spot = s
	_say(g)

func _on_tile_tapped(g: Gestalt) -> void:
	_speaking_spot = null
	_say(g)

func _on_speech_started(g: Gestalt, seconds: float) -> void:
	if _speaking_spot != null and _room != null:
		_room_view.show_chunks(_speaking_spot, g, seconds)
		return
	var tile: GestaltTile = _tiles.get(g.id, null)
	if tile != null:
		tile.play_split(seconds)

func _on_spot_held(_s: Spot, g: Gestalt) -> void:
	_open_recorder(g)

func _on_tile_held(tile: GestaltTile) -> void:
	if tile.gestalt != null:
		_open_recorder(tile.gestalt)

func _open_recorder(g: Gestalt) -> void:
	_speaker.stop()
	_record_overlay.open(g, _profile)

func _on_recording_kept(g: Gestalt) -> void:
	# Play the new take back where it lives, so the caregiver hears it in place.
	_say(g)

func _on_profiles_held() -> void:
	_speaker.stop()
	profiles_requested.emit()

func _on_style_changed(_preset: StylePreset) -> void:
	if _profile == null:
		return
	if _room != null:
		show_room(_room)
	elif _board != null:
		show_board(_board)

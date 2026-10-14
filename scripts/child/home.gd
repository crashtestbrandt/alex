extends Control
class_name ChildHome
## The learner's screen: one room or board at a time, a strip to move between them, and a held button back
## to the adults' picker. No scores, no timers, no wrong answers (docs/design.md).
##
## Holding a spot or a tile opens the caregiver's recording overlay for that gestalt.

signal profiles_requested

const _TILE_SCENE: PackedScene = preload("res://scenes/child/gestalt_tile.tscn")

@onready var _title: HoldButton = %Title
@onready var _name_slot: Control = %NameSlot
@onready var _top_bar: HBoxContainer = %TopBar
@onready var _strip: PillBar = %PlaceStrip
@onready var _room_view: RoomView = %RoomView
@onready var _stage: ScrollContainer = %Stage
@onready var _column: VBoxContainer = %Column
@onready var _margin: MarginContainer = %Margin
@onready var _grid: HFlowContainer = %Board
@onready var _profiles_button: HoldButton = %ProfilesButton
@onready var _speaker: Speaker = %Speaker
@onready var _record_overlay: RecordOverlay = %RecordOverlay

var _safe_rect: Rect2 = Rect2()
var _profile: Profile = null
var _board: Board = null
var _room: Room = null
var _tiles: Dictionary[String, GestaltTile] = {}
var _places: Dictionary[String, SdfButton] = {}
var _speaking_spot: Spot = null

func _ready() -> void:
	var name_padding: StyleBoxEmpty = StyleBoxEmpty.new()
	name_padding.set_content_margin_all(4.0)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		_title.add_theme_stylebox_override(state, name_padding)
	_name_slot.resized.connect(_layout_name)
	_title.theme_changed.connect(_layout_name.call_deferred)
	_profiles_button.held.connect(_on_profiles_held)
	_title.pressed.connect(_on_name_tapped)
	_title.held.connect(_on_name_held)
	_speaker.started.connect(_on_speech_started)
	_room_view.spot_tapped.connect(_on_spot_tapped)
	_room_view.spot_held.connect(_on_spot_held)
	_record_overlay.kept.connect(_on_recording_kept)
	_top_bar.item_rect_changed.connect(_sync_room_inset)
	Style.changed.connect(_on_style_changed)
	resized.connect(_layout_home)
	_stage.resized.connect(_layout_board)
	_strip.item_rect_changed.connect(_sync_room_inset)
	_layout_home()

func show_profile(p: Profile) -> void:
	_profile = p
	_title.text = p.display_name
	_title.disabled = p.display_name.is_empty()
	_build_strip()
	if not p.rooms.is_empty():
		show_room(p.rooms[0])
	elif not p.boards.is_empty():
		show_board(p.boards[0])
	else:
		show_board(_all_gestalts_board(p))

func set_safe_area(rect: Rect2) -> void:
	_safe_rect = rect
	SafeArea.fit_control(_margin, rect)
	_room_view.set_safe_area(rect)
	_record_overlay.set_safe_area(rect)
	_layout_home.call_deferred()

func show_room(r: Room) -> void:
	_speaker.stop()
	_room = r
	_board = null
	_grid.visible = false
	_stage.visible = false
	_room_view.visible = true
	_room_view.show_room(_profile, r)
	_show_place("room:" + r.id)
	_layout_home()

func show_board(b: Board) -> void:
	_speaker.stop()
	_board = b
	_room = null
	_room_view.visible = false
	_grid.visible = true
	_stage.visible = true
	_stage.scroll_vertical = 0
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_tiles.clear()
	for g: Gestalt in _profile.board_gestalts(b):
		var tile: GestaltTile = _TILE_SCENE.instantiate() as GestaltTile
		tile.set_gestalt(g)
		tile.tapped.connect(_on_tile_tapped)
		tile.held.connect(_on_tile_held.bind(tile))
		_grid.add_child(tile)
		_tiles[g.id] = tile
	_layout_board()
	_show_place("board:" + b.id)
	_layout_home()

func _build_strip() -> void:
	_strip.clear()
	_places.clear()
	_strip.visible = _profile.rooms.size() + _profile.boards.size() >= 2
	if not _strip.visible:
		return
	for r: Room in _profile.rooms:
		var button: SdfButton = SdfButton.new()
		button.text = r.title
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.x = 160.0
		button.pressed.connect(show_room.bind(r))
		_strip.add_item(button)
		_places["room:" + r.id] = button
	for b: Board in _profile.boards:
		var button: SdfButton = SdfButton.new()
		button.text = b.title
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.x = 160.0
		button.pressed.connect(show_board.bind(b))
		_strip.add_item(button)
		_places["board:" + b.id] = button

func _show_place(key: String) -> void:
	var button: SdfButton = _places.get(key, null)
	if button == null:
		return
	for other: SdfButton in _places.values():
		other.set_pressed_no_signal(other == button)
		other.refresh()

## The room renders edge to edge behind the top bar; it frames itself into the band below the bar.
func _sync_room_inset() -> void:
	var bar_bottom: float = _top_bar.global_position.y + _top_bar.size.y - _room_view.global_position.y
	if _strip.visible:
		bar_bottom = maxf(bar_bottom, _strip.global_position.y + _strip.size.y - _room_view.global_position.y)
	_room_view.safe_top_px = maxf(bar_bottom + 16.0, 0.0)

func _layout_home() -> void:
	var available: Vector2 = _safe_rect.size if _safe_rect.has_area() else size
	var compact: bool = available.x < 740.0 or (available.x < 900.0 and available.y > available.x * 1.2)
	var parent: Node = _column if compact else _top_bar
	if _strip.get_parent() != parent:
		_strip.reparent(parent)
		parent.move_child(_strip, 1)
	_strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if compact else Control.SIZE_FILL
	_strip.fit_width(available.x - 48.0 if compact else available.x * 0.55)
	_layout_name.call_deferred()
	_layout_board()
	_sync_room_inset.call_deferred()

## Only the displayed name receives taps; unused header space passes through to the room.
func _layout_name() -> void:
	var minimum: Vector2 = _title.get_combined_minimum_size()
	_name_slot.custom_minimum_size.y = minimum.y
	var font: Font = _title.get_theme_font("font")
	var font_size: int = _title.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var padding: Vector2 = _title.get_theme_stylebox("normal").get_minimum_size()
	_title.visible = not _title.text.is_empty() and _name_slot.size.x >= minimum.x
	_title.size = Vector2(minf(ceilf(text_width) + padding.x, _name_slot.size.x), minimum.y)
	_title.position = Vector2(0.0, maxf(0.0, (_name_slot.size.y - _title.size.y) / 2.0))

func _layout_board() -> void:
	var width: float = clampf(_stage.size.x - 16.0, Style.current.tile_min_size, 320.0)
	for tile: GestaltTile in _tiles.values():
		tile.custom_minimum_size.x = width

## A profile with nothing to show lists every gestalt it has.
static func _all_gestalts_board(p: Profile) -> Board:
	var ids: PackedStringArray = PackedStringArray()
	for g: Gestalt in p.gestalts:
		ids.push_back(g.id)
	return Board.make("all", "All", ids)

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
	# The name utterance is separate even if a bank entry also has the id "name".
	if _profile.gestalt(g.id) != g:
		return
	var tile: GestaltTile = _tiles.get(g.id, null)
	if tile != null:
		tile.play_split(seconds)

func _on_spot_held(s: Spot, g: Gestalt) -> void:
	_speaking_spot = s
	_open_recorder(g)

func _on_tile_held(tile: GestaltTile) -> void:
	_speaking_spot = null
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

func _on_name_tapped() -> void:
	if _profile == null or _title.consumed_by_hold():
		return
	_speaking_spot = null
	_say(_profile.name_gestalt())

func _on_name_held() -> void:
	if _profile == null:
		return
	_speaking_spot = null
	_speaker.stop()
	_record_overlay.open(_profile.name_gestalt(), _profile, true)

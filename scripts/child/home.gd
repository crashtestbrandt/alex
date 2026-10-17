extends Control
class_name ChildHome
## The learner's screen: the room or the tiles, a strip of two modes to move between them, and a held button
## back to the adults' picker. No scores, no timers, no wrong answers (docs/design.md).
##
## The strip reads Explore and Words, never a room's or a board's title. Explore is the entry scene's room
## (`Profile.explore_room`); room choice inside it waits. Words is the whole bank
## (`Profile.words_gestalts`) in two modes on a floating widget: Palette, a column of tiles, and Build, a
## strip the learner fills from the bank's chunks ([BuildView]). Holding a spot or a tile opens the
## caregiver's recording overlay for that gestalt.

signal profiles_requested

## The learner's two modes, in strip order.
enum Mode {
	EXPLORE = 0,
	WORDS = 1,
}

const _TILE_SCENE: PackedScene = preload("res://scenes/child/gestalt_tile.tscn")
const _MODE_LABELS: Dictionary[int, String] = {Mode.EXPLORE: "Explore", Mode.WORDS: "Words"}
const WIDGET_MARGIN: float = 10.0

@onready var _title: HoldButton = %Title
@onready var _name_slot: Control = %NameSlot
@onready var _top_bar: HBoxContainer = %TopBar
@onready var _strip: PillBar = %ModeStrip
@onready var _room_view: RoomView = %RoomView
@onready var _stage: ScrollContainer = %Stage
@onready var _column: VBoxContainer = %Column
@onready var _margin: MarginContainer = %Margin
@onready var _grid: HFlowContainer = %Board
@onready var _board_spacer: Control = %BoardSpacer
@onready var _build: BuildView = %Build
@onready var _words_widget: WordsWidget = %WordsWidget
@onready var _profiles_button: HoldButton = %ProfilesButton
@onready var _speaker: Speaker = %Speaker
@onready var _record_overlay: RecordOverlay = %RecordOverlay

var _safe_rect: Rect2 = Rect2()
var _profile: Profile = null
var _mode: Mode = Mode.EXPLORE
var _words_mode: WordsWidget.Mode = WordsWidget.Mode.PALETTE
var _room: Room = null
var _tiles: Dictionary[String, GestaltTile] = {}
var _modes: Dictionary[int, SdfButton] = {}
var _speaking_spot: Spot = null
## Whether Build asked for the current utterance, and which strip chunk it was, or -1 for the whole strip.
var _speaking_build: bool = false
var _build_index: int = -1

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
	_words_widget.mode_chosen.connect(_on_words_mode_chosen)
	_words_widget.resized.connect(_layout_home)
	_build.chunk_added.connect(_on_chunk_added)
	_build.strip_tapped.connect(_on_strip_tapped)
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
		show_explore()
	else:
		show_words()

func set_safe_area(rect: Rect2) -> void:
	_safe_rect = rect
	SafeArea.fit_control(_margin, rect)
	_room_view.set_safe_area(rect)
	_record_overlay.set_safe_area(rect)
	_layout_home.call_deferred()

## Explore: the entry scene's room (`Profile.explore_room`).
func show_explore() -> void:
	var r: Room = _profile.explore_room()
	if r != null:
		show_room(r)

func show_room(r: Room) -> void:
	_speaker.stop()
	_mode = Mode.EXPLORE
	_room = r
	_grid.visible = false
	_stage.visible = false
	_build.visible = false
	_words_widget.visible = false
	_room_view.visible = true
	_room_view.show_room(_profile, r)
	_show_mode(Mode.EXPLORE)
	_layout_home()

## Words, in whichever of its modes the learner last used.
func show_words() -> void:
	if _words_mode == WordsWidget.Mode.BUILD:
		show_build()
	else:
		show_palette()

## Palette: every gestalt in the bank as a tile (`Profile.words_gestalts`).
func show_palette() -> void:
	_enter_words(WordsWidget.Mode.PALETTE)
	_build.visible = false
	_grid.visible = true
	_stage.visible = true
	_stage.scroll_vertical = 0
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_tiles.clear()
	for g: Gestalt in _profile.words_gestalts():
		var tile: GestaltTile = _TILE_SCENE.instantiate() as GestaltTile
		tile.set_gestalt(g)
		tile.tapped.connect(_on_tile_tapped)
		tile.held.connect(_on_tile_held.bind(tile))
		_grid.add_child(tile)
		_tiles[g.id] = tile
	_layout_board()
	_layout_home()

## Build: the bank's beginnings and endings, and the strip the learner fills from them ([BuildView]).
func show_build() -> void:
	_enter_words(WordsWidget.Mode.BUILD)
	_grid.visible = false
	_stage.visible = false
	_build.visible = true
	_build.set_bank(_profile.gestalts)
	_layout_home()

func build_view() -> BuildView:
	return _build

func words_mode() -> WordsWidget.Mode:
	return _words_mode

func _enter_words(words: WordsWidget.Mode) -> void:
	_speaker.stop()
	_mode = Mode.WORDS
	_words_mode = words
	_room = null
	_speaking_build = false
	_room_view.visible = false
	_words_widget.visible = true
	_words_widget.show_mode(words)
	_show_mode(Mode.WORDS)

func _on_words_mode_chosen(words: WordsWidget.Mode) -> void:
	if words == WordsWidget.Mode.BUILD:
		show_build()
	else:
		show_palette()

## The pill a mode shows on the strip, or null when the profile has nothing for that mode.
func mode_button(m: Mode) -> SdfButton:
	return _modes.get(m, null)

## A mode gets a pill only when it has something to show. The strip shows only when both do.
func _build_strip() -> void:
	_strip.clear()
	_modes.clear()
	if not _profile.rooms.is_empty():
		_add_mode(Mode.EXPLORE, show_explore)
	if not _profile.words_gestalts().is_empty():
		_add_mode(Mode.WORDS, show_words)
	_strip.visible = _modes.size() >= 2

func _add_mode(m: Mode, show: Callable) -> void:
	var button: SdfButton = SdfButton.new()
	button.text = _MODE_LABELS[m]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.x = 160.0
	button.pressed.connect(show)
	_strip.add_item(button)
	_modes[m] = button

func _show_mode(m: Mode) -> void:
	for key: int in _modes.keys():
		var button: SdfButton = _modes[key]
		button.set_pressed_no_signal(key == m)
		button.refresh()

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
	_layout_words_widget()
	_sync_room_inset.call_deferred()

## The Words widget floats over the bottom right corner, like the room's view widget, and the columns under
## it leave it clear so their last row can scroll above it.
func _layout_words_widget() -> void:
	var safe: Rect2 = _safe_rect if _safe_rect.has_area() else Rect2(Vector2.ZERO, size)
	_words_widget.fit_width(maxf(safe.size.x - WIDGET_MARGIN * 2.0, 1.0))
	_words_widget.reset_size()
	_words_widget.position = safe.end - _words_widget.size - Vector2.ONE * WIDGET_MARGIN
	var clearance: float = _words_widget.size.y + WIDGET_MARGIN * 2.0
	_board_spacer.custom_minimum_size.y = clearance
	_build.set_bottom_clearance(clearance)

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

func _say(g: Gestalt) -> void:
	_speaker.say(g, ProfileStore.media_dir(_profile.id))

func _on_spot_tapped(s: Spot, g: Gestalt) -> void:
	_speaking_spot = s
	_speaking_build = false
	_say(g)

func _on_tile_tapped(g: Gestalt) -> void:
	_speaking_spot = null
	_speaking_build = false
	_say(g)

## A chunk that landed on the strip is said on its own. Until per-chunk takes exist, that is the OS voice.
func _on_chunk_added(chunk: String, index: int) -> void:
	_speaking_spot = null
	_speaking_build = true
	_build_index = index
	_say(ChunkBank.phrase(PackedStringArray([chunk])))

## The strip is said whole: in the caregiver's voice when the bank holds that phrase, as itself otherwise.
func _on_strip_tapped(chunks: PackedStringArray) -> void:
	_speaking_spot = null
	_speaking_build = true
	_build_index = -1
	_say(ChunkBank.voice(_profile.gestalts, chunks))

func _on_speech_started(g: Gestalt, seconds: float) -> void:
	if _speaking_spot != null and _room != null:
		_room_view.show_chunks(_speaking_spot, g, seconds)
		return
	if _speaking_build and _mode == Mode.WORDS and _words_mode == WordsWidget.Mode.BUILD:
		if _build_index >= 0:
			_build.play_chunk(_build_index, seconds)
		else:
			_build.play(seconds)
		return
	# The name utterance is separate even if a bank entry also has the id "name".
	if _profile.gestalt(g.id) != g:
		return
	var tile: GestaltTile = _tiles.get(g.id, null)
	if tile != null:
		tile.play(seconds)

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
	if _mode == Mode.EXPLORE and _room != null:
		show_room(_room)
	else:
		show_words()

func _on_name_tapped() -> void:
	if _profile == null or _title.consumed_by_hold():
		return
	_speaking_spot = null
	_speaking_build = false
	_say(_profile.name_gestalt())

func _on_name_held() -> void:
	if _profile == null:
		return
	_speaking_spot = null
	_speaker.stop()
	_record_overlay.open(_profile.name_gestalt(), _profile, true)

extends SdfPanel
class_name RoomChooser
## A full-screen visual choice of the profile's rooms, in saved order. Previews exist only while open.
signal room_chosen(room: Room)
signal closed
const GAP: float = 20.0
const EDGE: int = 24
var _padding: MarginContainer = null
var _scroll: SdfScroll = null
var _grid: HFlowContainer = null
var _back: GlyphBar.GlyphButton = null
var _safe: Rect2 = Rect2()
var _cards: Array[RoomPreview] = []

func _init() -> void:
	content_margin = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	super()
	_padding = MarginContainer.new()
	add_child(_padding)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_padding.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	column.add_child(header)
	_back = GlyphBar.GlyphButton.new()
	_back.figure = SdfGlyph.Figure.BACK
	_back.tooltip_text = "Back to room"
	_back.accessibility_name = "Back to room"
	_back.shape = SdfButton.Shape.PILL
	_back.pressed.connect(func() -> void: closed.emit())
	header.add_child(_back)
	var title: Label = Label.new()
	title.text = "Rooms"
	title.theme_type_variation = &"TitleLabel"
	header.add_child(title)
	_scroll = SdfScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_scroll.add_child(_grid)
	_scroll.resized.connect(_layout_cards)
	resized.connect(_layout_cards)
	_layout_cards()

func open(profile: Profile, current: Room) -> void:
	clear()
	show()
	for room: Room in profile.rooms:
		var card: RoomPreview = RoomPreview.new()
		card.room = room
		card.profile = profile
		card.current = current != null and room.id == current.id
		card.accessibility_name = room.title
		card.pressed.connect(func() -> void: room_chosen.emit(room))
		_cards.push_back(card)
		_grid.add_child(card)
	_scroll.scroll_vertical = 0
	_layout_cards()
	_back.grab_focus()

func clear() -> void:
	for card: RoomPreview in _cards:
		_grid.remove_child(card)
		card.queue_free()
	_cards.clear()

func cards() -> Array[RoomPreview]:
	return _cards

func set_safe_area(rect: Rect2) -> void:
	_safe = rect
	_layout_cards()

func _layout_cards() -> void:
	if _padding == null:
		return
	var safe: Rect2 = _safe if _safe.has_area() else Rect2(Vector2.ZERO, size)
	_padding.add_theme_constant_override("margin_left", EDGE + ceili(safe.position.x))
	_padding.add_theme_constant_override("margin_right", EDGE + ceili(size.x - safe.end.x))
	_padding.add_theme_constant_override("margin_top", EDGE + ceili(safe.position.y))
	_padding.add_theme_constant_override("margin_bottom", EDGE + ceili(size.y - safe.end.y))
	var target: float = maxf(Style.current.tile_min_size, 260.0)
	var width: float = maxf(_scroll.size.x - 16.0, target)
	var columns: int = clampi(floori((width + GAP) / (target + GAP)), 1, 3)
	var card_width: float = floorf((width - GAP * (columns - 1)) / columns)
	for card: RoomPreview in _cards:
		card.custom_minimum_size = Vector2(card_width, maxf(Style.current.tile_min_size, card_width * 0.75))
	var back_px: float = maxf(Style.current.tile_min_size * GlyphBar.BUTTON_SCALE, GlyphBar.MIN_PX)
	_back.custom_minimum_size = Vector2.ONE * back_px

func _refresh() -> void:
	super()
	if _shape != null:
		_shape.radius_px = 0.0
		_shape.fill = Style.current.background
		_shape.relief = 0.0

func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()

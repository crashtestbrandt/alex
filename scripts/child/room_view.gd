extends Control
class_name RoomView
## One [Room] on screen: a floor line and its spots, laid out from their fractional positions so the same
## room fits a phone and a tablet. Chunks float above a spot while its gestalt plays, then fade.

signal spot_tapped(spot: Spot, gestalt: Gestalt)
signal spot_held(spot: Spot, gestalt: Gestalt)

## The smallest a spot may be, in pixels. A touch target, floored whatever the room says.
const MIN_SPOT_PX: float = 120.0

var _profile: Profile = null
var _room: Room = null
var _views: Dictionary[String, SpotView] = {}

@onready var _captions: Control = %Captions

func _ready() -> void:
	resized.connect(_layout)
	Style.changed.connect(_on_style_changed)

func show_room(p: Profile, r: Room) -> void:
	_profile = p
	_room = r
	for view: SpotView in _views.values():
		view.queue_free()
	_views.clear()
	for s: Spot in r.spots:
		if p.gestalt(s.gestalt_id) == null:
			continue
		var view: SpotView = SpotView.new()
		view.setup(s)
		view.tapped.connect(_on_spot_tapped)
		view.held.connect(_on_spot_held)
		add_child(view)
		_views[s.id] = view
	_captions.move_to_front()
	_layout()
	queue_redraw()

## The gestalt a spot says right now: its alternate when toggled on and one exists.
func gestalt_for(s: Spot) -> Gestalt:
	var view: SpotView = _views.get(s.id, null)
	if view != null and view.is_on and not s.alt_gestalt_id.is_empty():
		var alt: Gestalt = _profile.gestalt(s.alt_gestalt_id)
		if alt != null:
			return alt
	return _profile.gestalt(s.gestalt_id)

## Float `g`'s chunks above spot `s` for about `seconds`, one chunk lighting after another.
func show_chunks(s: Spot, g: Gestalt, seconds: float) -> void:
	var view: SpotView = _views.get(s.id, null)
	if view == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var labels: Array[Label] = []
	for chunk: String in g.chunks:
		var label: Label = Label.new()
		label.text = chunk
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", Style.font_px(28))
		label.add_theme_color_override("font_color", Style.current.text)
		row.add_child(label)
		labels.push_back(label)
	_captions.add_child(row)
	row.reset_size()
	var above: Vector2 = view.position + Vector2(view.size.x / 2.0 - row.size.x / 2.0, -row.size.y - 10.0)
	above.x = clampf(above.x, 8.0, maxf(8.0, size.x - row.size.x - 8.0))
	if above.y < 8.0:
		above.y = view.position.y + view.size.y + 10.0
	row.position = above
	var scale_factor: float = Style.motion_scale()
	var hold: float = maxf(seconds, 0.6)
	if scale_factor <= 0.0 or labels.size() < 2:
		get_tree().create_timer(hold + 0.6).timeout.connect(row.queue_free)
		return
	for label: Label in labels:
		label.modulate = Color(1, 1, 1, 0.25)
	var tween: Tween = create_tween()
	var per_chunk: float = hold / labels.size()
	for i: int in labels.size():
		tween.tween_property(labels[i], "modulate", Color.WHITE, 0.12 * scale_factor).set_delay(per_chunk * i if i == 0 else per_chunk - 0.12 * scale_factor)
	tween.tween_interval(0.5)
	tween.tween_property(row, "modulate", Color(1, 1, 1, 0), 0.4 * scale_factor)
	tween.tween_callback(row.queue_free)

func _layout() -> void:
	if _room == null:
		return
	var shorter: float = minf(size.x, size.y)
	for s: Spot in _room.spots:
		var view: SpotView = _views.get(s.id, null)
		if view == null:
			continue
		var px: float = maxf(s.size * shorter, MIN_SPOT_PX)
		view.size = Vector2(px, px)
		var center: Vector2 = Vector2(s.x * size.x, s.y * size.y)
		var top_left: Vector2 = center - view.size / 2.0
		top_left.x = clampf(top_left.x, 0.0, maxf(0.0, size.x - px))
		top_left.y = clampf(top_left.y, 0.0, maxf(0.0, size.y - px))
		view.set_rest_position(top_left)
	queue_redraw()

func _draw() -> void:
	if _room == null:
		return
	var floor_top: float = size.y * 0.72
	draw_rect(Rect2(0.0, floor_top, size.x, size.y - floor_top), Style.current.accent.lerp(Style.current.background, 0.82))
	draw_line(Vector2(0.0, floor_top), Vector2(size.x, floor_top), Style.current.text.lerp(Style.current.background, 0.6), 2.0)

func _on_spot_tapped(s: Spot) -> void:
	var g: Gestalt = gestalt_for(s)
	var view: SpotView = _views.get(s.id, null)
	if view != null:
		view.react()
	if g != null:
		spot_tapped.emit(s, g)

func _on_spot_held(s: Spot) -> void:
	var g: Gestalt = gestalt_for(s)
	if g != null:
		spot_held.emit(s, g)

func _on_style_changed(_preset: StylePreset) -> void:
	for view: SpotView in _views.values():
		view.queue_redraw()
	queue_redraw()

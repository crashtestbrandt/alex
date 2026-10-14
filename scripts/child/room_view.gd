extends Control
class_name RoomView
## One [Room] in 3D: a three-walled box, its spots built from recipes, a camera the learner can move between
## a few views, and captions that float over a spot while its gestalt plays (docs/geometry.md).
##
## Input rules, in the learner's favor: a tap on an object reacts and speaks; a two-second hold on an object
## opens the caregiver's recorder; a drag that started on an object cancels and does nothing; a drag on
## empty room orbits only when the room allows it; and any view returns to the front after the same idle
## period the recording overlay uses.

signal spot_tapped(spot: Spot, gestalt: Gestalt)
signal spot_held(spot: Spot, gestalt: Gestalt)

const HOLD_SECONDS: float = 2.0
const DRAG_PX: float = 24.0
const ORBIT_DEG_PER_PX: float = 0.35
const VIEW_TWEEN_SECONDS: float = 0.7
const WIDGET_MARGIN: float = 10.0

## How long a moved view stays before it returns to the front. A probe shortens it.
var idle_seconds: float = RecordOverlay.IDLE_SECONDS
## How much of the top of the view floating controls cover. The home sets it from its top bar; the camera
## frames the room into the band below it and above the view widget.
var safe_top_px: float = 0.0:
	set(value):
		safe_top_px = value
		if is_node_ready():
			_layout()

var _profile: Profile = null
var _room: Room = null
var _bodies: Dictionary[String, SpotBody] = {}
var _walls: Dictionary[int, MeshInstance3D] = {}
var _floor: MeshInstance3D = null
var _material: StandardMaterial3D = RecipeBuilder.make_material()

var _view: CameraFraming.View = CameraFraming.View.FRONT
var _azimuth: float = 0.0
var _elevation: float = CameraFraming.FRONT_ELEVATION_DEG
var _extent: float = 3.0
var _view_tween: Tween = null
var _blend_from: Vector3 = Vector3.ZERO
var _blend_to: Vector3 = Vector3.ZERO

var _press_pos: Vector2 = Vector2.ZERO
var _press_body: SpotBody = null
var _down_for: float = -1.0
var _dragging: bool = false
var _orbit_drag: bool = false
var _idle: float = 0.0

@onready var _container: SubViewportContainer = %ViewportContainer
@onready var _viewport: SubViewport = %Viewport
@onready var _world: Node3D = %World
@onready var _camera: Camera3D = %Camera
@onready var _sun: DirectionalLight3D = %Sun
@onready var _env: WorldEnvironment = %Env
@onready var _captions: Control = %Captions
@onready var _widget: ViewWidget = %ViewWidget

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_build_shell()
	# From the front and high, so the raised side walls throw their shadow onto the apron, not the back wall.
	_sun.look_at_from_position(Vector3(0.8, 6.0, 5.0), Vector3.ZERO, Vector3.UP)
	_sun.shadow_enabled = true
	_sun.light_energy = 0.75
	_env.environment = _make_environment(Style.current)
	_widget.view_chosen.connect(_on_view_chosen)
	resized.connect(_on_resized)
	Style.changed.connect(_on_style_changed)
	_apply_camera()

func show_room(p: Profile, r: Room) -> void:
	_profile = p
	_room = r
	for body: SpotBody in _bodies.values():
		body.queue_free()
	_bodies.clear()
	for s: Spot in r.spots:
		if p.gestalt(s.gestalt_id) == null:
			continue
		var size_m: float = RoomSpace.spot_size_m(s)
		var recipe: Recipe = ObjectRecipes.make(s.kind, size_m, Style.current)
		var body: SpotBody = SpotBody.new()
		body.setup(s, recipe, size_m, _material)
		body.set_rest(RoomSpace.place(s))
		_world.add_child(body)
		_bodies[s.id] = body
	_widget.set_mode(r.camera)
	_layout()
	_cancel_press()
	set_view(CameraFraming.View.FRONT, false)

## The gestalt a spot says right now: its alternate when toggled on and one exists.
func gestalt_for(s: Spot) -> Gestalt:
	var body: SpotBody = _bodies.get(s.id, null)
	if body != null and body.is_on and not s.alt_gestalt_id.is_empty():
		var alt: Gestalt = _profile.gestalt(s.alt_gestalt_id)
		if alt != null:
			return alt
	return _profile.gestalt(s.gestalt_id)

func bodies() -> Array[SpotBody]:
	var out: Array[SpotBody] = []
	for body: SpotBody in _bodies.values():
		out.push_back(body)
	return out

func body(spot_id: String) -> SpotBody:
	return _bodies.get(spot_id, null)

func view() -> CameraFraming.View:
	return _view

func camera_position() -> Vector3:
	return _camera.global_position

func wall_visible(w: Spot.Wall) -> bool:
	var wall: MeshInstance3D = _walls.get(w, null)
	return wall != null and wall.visible

## The band the room is framed into: this control minus the floating controls above and below.
func safe_rect() -> Rect2:
	var bottom: float = 0.0
	if _widget.visible:
		bottom = _widget.size.y + 2.0 * WIDGET_MARGIN
	return Rect2(0.0, safe_top_px, size.x, maxf(size.y - safe_top_px - bottom, 1.0))

## Where a body's center falls on this control.
func screen_point(b: SpotBody) -> Vector2:
	return _camera.unproject_position(b.center_point())

## How many pixels a body's bounds cover on this control, width and height.
func screen_size(b: SpotBody) -> Vector2:
	var box: AABB = b.bounds()
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	for i: int in 8:
		var corner: Vector2 = _camera.unproject_position(b.to_global(box.get_endpoint(i)))
		low = Vector2(minf(low.x, corner.x), minf(low.y, corner.y))
		high = Vector2(maxf(high.x, corner.x), maxf(high.y, corner.y))
	return high - low

## The body under a point on this control, or null. The ray is traced through every body's distance field;
## when it hits nothing, the nearest body whose center is within half the touch floor is taken instead.
func pick_at(point: Vector2) -> SpotBody:
	var all: Array[SpotBody] = bodies()
	if all.is_empty():
		return null
	var targets: Array[Picker.Target] = []
	for b: SpotBody in all:
		targets.push_back(b.pick_target())
	var hit: int = Picker.pick(_camera.project_ray_origin(point), _camera.project_ray_normal(point), targets)
	if hit >= 0:
		return all[hit]
	var reach: float = Style.current.tile_min_size / 2.0
	var best: SpotBody = null
	var best_d: float = INF
	for b: SpotBody in all:
		if _camera.is_position_behind(b.center_point()):
			continue
		var d: float = screen_point(b).distance_to(point)
		if d <= reach and d < best_d:
			best_d = d
			best = b
	return best

## Play a body's reaction and say its gestalt, as a tap does.
func tap(b: SpotBody) -> void:
	var g: Gestalt = gestalt_for(b.spot)
	b.react()
	if g != null:
		spot_tapped.emit(b.spot, g)

## Move the camera to a view, animated unless `animate` is false or the style's motion is none.
func set_view(target: CameraFraming.View, animate: bool = true) -> void:
	_view = target
	_widget.show_current(target)
	var angles: Vector2 = CameraFraming.view_angles(target)
	_move_camera(angles.x, angles.y, animate)

## Turn the camera by a drag of `delta` pixels, within the orbit's limits. Only a room with `camera: orbit`
## reaches this from input.
func orbit_by(delta: Vector2) -> void:
	var clamped: Vector2 = CameraFraming.clamp_orbit(_azimuth - delta.x * ORBIT_DEG_PER_PX, _elevation + delta.y * ORBIT_DEG_PER_PX)
	_view = CameraFraming.View.TURN
	_widget.show_current(_view)
	_azimuth = clamped.x
	_elevation = clamped.y
	_extent = _extent_for(_azimuth, _elevation)
	_apply_camera()

## Float `g`'s chunks above spot `s` for about `seconds`, one chunk lighting after another.
func show_chunks(s: Spot, g: Gestalt, seconds: float) -> void:
	var b: SpotBody = _bodies.get(s.id, null)
	if b == null:
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
	var anchor: Vector2 = _camera.unproject_position(b.top_point())
	var safe: Rect2 = safe_rect()
	var above: Vector2 = anchor + Vector2(-row.size.x / 2.0, -row.size.y - 12.0)
	above.x = clampf(above.x, 8.0, maxf(8.0, safe.end.x - row.size.x - 8.0))
	above.y = clampf(above.y, safe.position.y + 8.0, maxf(safe.position.y + 8.0, safe.end.y - row.size.y - 8.0))
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

# --- input ------------------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	_idle = 0.0
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_press_pos = button.position
			_press_body = pick_at(button.position)
			_down_for = 0.0
			_dragging = false
			_orbit_drag = false
			set_process(true)
		elif _down_for >= 0.0:
			var was_tap: bool = not _dragging and _press_body != null
			var tapped: SpotBody = _press_body
			_cancel_press()
			if was_tap:
				tap(tapped)
		accept_event()
	elif event is InputEventMouseMotion and _down_for >= 0.0:
		var motion: InputEventMouseMotion = event
		if not _dragging and motion.position.distance_to(_press_pos) > DRAG_PX:
			_dragging = true
			# A drag that started on an object cancels it; a drag on empty room turns the view if allowed.
			_orbit_drag = _press_body == null and _room != null and _room.camera == Room.Camera.ORBIT
			_press_body = null
		if _orbit_drag:
			orbit_by(motion.relative)
		accept_event()

func _process(delta: float) -> void:
	if _down_for >= 0.0:
		if _press_body != null and not _dragging:
			_down_for += delta
			if _down_for >= HOLD_SECONDS:
				var held: SpotBody = _press_body
				_cancel_press()
				var g: Gestalt = gestalt_for(held.spot)
				if g != null:
					spot_held.emit(held.spot, g)
		return
	if _view == CameraFraming.View.FRONT:
		return
	_idle += delta
	if _idle >= idle_seconds:
		_idle = 0.0
		set_view(CameraFraming.View.FRONT)

func _cancel_press() -> void:
	_down_for = -1.0
	_press_body = null
	_dragging = false
	_orbit_drag = false
	_idle = 0.0
	set_process(_room != null)

func _on_view_chosen(target: CameraFraming.View) -> void:
	_idle = 0.0
	set_view(target)

# --- camera -----------------------------------------------------------------------------------------------

## The full viewport's extent: the room is framed into the safe band, and the band's extent is scaled up to the
## whole viewport, which the floating controls then cover at the top and bottom.
func _extent_for(azimuth: float, elevation: float) -> float:
	var smallest: float = RoomSpace.smallest_spot_m(_room) if _room != null else 0.0
	var safe: Rect2 = safe_rect()
	var aspect: float = safe.size.x / maxf(safe.size.y, 1.0)
	var band: float = CameraFraming.frame_extent(azimuth, elevation, RoomSpace.content_dims(_room), aspect, smallest, safe.size.y, float(Style.current.tile_min_size))
	return CameraFraming.full_extent(band, safe.size.y, size.y)

func _move_camera(azimuth: float, elevation: float, animate: bool) -> void:
	if _view_tween != null:
		_view_tween.kill()
		_view_tween = null
	var extent: float = _extent_for(azimuth, elevation)
	var scale_factor: float = Style.motion_scale()
	if not animate or scale_factor <= 0.0 or not is_inside_tree():
		_azimuth = azimuth
		_elevation = elevation
		_extent = extent
		_apply_camera()
		return
	_blend_from = Vector3(_azimuth, _elevation, _extent)
	_blend_to = Vector3(azimuth, elevation, extent)
	_view_tween = create_tween()
	_view_tween.tween_method(_blend, 0.0, 1.0, VIEW_TWEEN_SECONDS * scale_factor) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _blend(t: float) -> void:
	var now: Vector3 = _blend_from.lerp(_blend_to, t)
	_azimuth = now.x
	_elevation = now.y
	_extent = now.z
	_apply_camera()

func _apply_camera() -> void:
	var distance: float = CameraFraming.perspective_distance(_extent, CameraFraming.FOV_DEG)
	_camera.fov = CameraFraming.FOV_DEG
	_camera.transform = CameraFraming.camera_transform(_target(), _azimuth, _elevation, distance)
	var safe: Rect2 = safe_rect()
	_camera.v_offset = CameraFraming.center_offset(safe.get_center().y - size.y / 2.0, size.y, _extent)
	for w: int in _walls.keys():
		var wall: Spot.Wall = w as Spot.Wall
		_walls[w].visible = not RoomSpace.wall_hidden(wall, _camera.global_position)

func _on_resized() -> void:
	_layout()

## What the camera looks at: a little under the center of the framed box, since a raised camera sees more
## floor than ceiling and the near floor edge projects larger.
func _target() -> Vector3:
	return Vector3(0.0, RoomSpace.content_dims(_room).y * 0.42, 0.0)

## The viewport fills the control edge to edge; the widget floats over its bottom right corner, and the camera
## frames the room into the band the floating controls leave.
func _layout() -> void:
	_widget.reset_size()
	_container.position = Vector2.ZERO
	_container.size = size
	_widget.position = Vector2(size.x - _widget.size.x - WIDGET_MARGIN, size.y - _widget.size.y - WIDGET_MARGIN)
	_extent = _extent_for(_azimuth, _elevation)
	_apply_camera()

# --- the room box -----------------------------------------------------------------------------------------

## The floor and the side walls run an apron past the open front, and every wall rises past the room's height,
## so the world fills the screen from the camera's side of the room (docs/geometry.md "The room").
func _build_shell() -> void:
	var w: float = RoomSpace.WIDTH
	var h: float = RoomSpace.HEIGHT + RoomSpace.WALL_RISE
	var d: float = RoomSpace.DEPTH + RoomSpace.APRON
	var t: float = RoomSpace.WALL
	var mid_z: float = RoomSpace.APRON / 2.0
	_floor = _slab(Vector3(w + 2.0 * t, t, d + t), Vector3(0.0, -t / 2.0, mid_z - t / 2.0), Style.current.floor_color)
	_walls[Spot.Wall.BACK] = _slab(Vector3(w + 2.0 * t, h, t), Vector3(0.0, h / 2.0, -RoomSpace.DEPTH / 2.0 - t / 2.0), Style.current.wall_color)
	_walls[Spot.Wall.LEFT] = _slab(Vector3(t, h, d), Vector3(-w / 2.0 - t / 2.0, h / 2.0, mid_z), Style.current.wall_color.darkened(0.06))
	_walls[Spot.Wall.RIGHT] = _slab(Vector3(t, h, d), Vector3(w / 2.0 + t / 2.0, h / 2.0, mid_z), Style.current.wall_color.darkened(0.06))

func _slab(size_m: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var batch: MeshBatch = Mesher.box(size_m / 2.0, 0.0, color)
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, batch.to_arrays())
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material
	instance.position = at
	_world.add_child(instance)
	return instance

func _make_environment(preset: StylePreset) -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = preset.background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = preset.wall_color.lerp(Color.WHITE, 0.4)
	env.ambient_light_energy = 0.55
	return env

func _on_style_changed(preset: StylePreset) -> void:
	_env.environment = _make_environment(preset)
	for wall: MeshInstance3D in _walls.values():
		wall.queue_free()
	_walls.clear()
	if _floor != null:
		_floor.queue_free()
	_build_shell()
	_apply_camera()

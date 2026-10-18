extends Control
class_name RoomView
## One [Room] in 3D: an enclosed room, its spots built from recipes, a camera the learner can move between
## a few views, and captions that float over a spot while its gestalt plays (docs/geometry.md).
##
## Input rules, in the learner's favor: a tap on an object reacts and speaks; a two-second hold on an object
## opens the caregiver's recorder; movement past `DRAG_PX` cancels the hold and moves the view from wherever
## the press began, when the room allows a moved view; two fingers pinch to zoom; a tap on a view pill resets
## that view; and a moved view returns to the front after `IDLE_RESET_SECONDS` with nothing touched.
##
## Front and Top pan and zoom on the orbit. Tilt stands at the room's center and a drag turns it, its zoom a
## field-of-view change. Every wall stays in place in Tilt, since the camera is inside the box.

signal spot_tapped(spot: Spot, gestalt: Gestalt)
signal spot_held(spot: Spot, gestalt: Gestalt)

const HOLD_SECONDS: float = 2.0
const DRAG_PX: float = 24.0
const LOOK_DEG_PER_PX: float = 0.25
## One notch of a scroll wheel zooms by this factor.
const WHEEL_ZOOM_STEP: float = 1.15
const VIEW_TWEEN_SECONDS: float = 0.7
const WIDGET_MARGIN: float = 10.0
## How long a moved view stays, with nothing touched, before it returns to the front.
const IDLE_RESET_SECONDS: float = 120.0
const CAPTION_FONT_BASE: int = 28
const CAPTION_MAX_PX: float = 504.0

## The idle period in use. A probe shortens it.
var idle_seconds: float = IDLE_RESET_SECONDS
## A chooser preview renders once, with no input, controls, speech or idle motion.
var preview: bool = false
var navigation_size: Vector2 = Vector2.ZERO:
	set(value):
		if navigation_size == value:
			return
		navigation_size = value
		if is_node_ready():
			_layout()

## Session-only state. No recordings, transient gestures or scene nodes are retained.
class State extends RefCounted:
	var on: Dictionary[String, bool] = {}
	var spoken: Dictionary[String, Gestalt] = {}
	var view: CameraFraming.View = CameraFraming.View.FRONT
	var azimuth: float = 0.0
	var elevation: float = CameraFraming.FRONT_ELEVATION_DEG
	var zoom: float = 1.0
	var pan: Vector2 = Vector2.ZERO
	var yaw: float = 0.0
	var pitch: float = 0.0
	var tilt_zoom: float = 1.0
## How much of the top of the view floating controls cover. The home sets it from its top bar; the camera
## frames the room into the band below it and above the view widget.
var safe_top_px: float = 0.0:
	set(value):
		safe_top_px = value
		if is_node_ready():
			_layout()

var _device_safe: Rect2 = Rect2()
var _profile: Profile = null
var _room: Room = null
var _bodies: Dictionary[String, SpotBody] = {}
var _spoken_gestalts: Dictionary[String, Gestalt] = {}
var _walls: Dictionary[int, Node3D] = {}
## The front wall and ceiling stay beyond the camera in orbit views.
var _enclosure: Node3D = null
var _shell: Node3D = null
var _floor: MeshInstance3D = null
var _front: MeshInstance3D = null
var _ceiling: MeshInstance3D = null
var _front_trim: MeshInstance3D = null
var _upper_walls: Dictionary[int, MeshInstance3D] = {}
var _wall_extensions: Dictionary[int, MeshInstance3D] = {}
var _trim_extensions: Dictionary[int, MeshInstance3D] = {}
var _material: StandardMaterial3D = RecipeBuilder.make_material()

var _view: CameraFraming.View = CameraFraming.View.FRONT
var _azimuth: float = 0.0
var _elevation: float = CameraFraming.FRONT_ELEVATION_DEG
var _extent: float = 3.0
## Front and Top: how far in from the fit, and where the frame has moved, in meters on the target plane.
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
## Tilt: where the camera stands, found once per room, where it looks, and how narrow its view is.
var _tilt_origin: Vector3 = Vector3(0.0, RoomSpace.TILT_EYE_HEIGHT, 0.0)
var _yaw: float = 0.0
var _pitch: float = 0.0
var _tilt_zoom: float = 1.0
var _fov: float = CameraFraming.FOV_DEG
var _view_tween: Tween = null
var _blend_from: Vector3 = Vector3.ZERO
var _blend_to: Vector3 = Vector3.ZERO
var _blend_pan_from: Vector2 = Vector2.ZERO
var _blend_zoom_from: float = 1.0
var _blend_xf_from: Transform3D = Transform3D.IDENTITY
var _blend_xf_to: Transform3D = Transform3D.IDENTITY
var _blend_fov_from: float = CameraFraming.FOV_DEG
var _blend_fov_to: float = CameraFraming.FOV_DEG
var _blend_offset_from: Vector2 = Vector2.ZERO
var _blend_offset_to: Vector2 = Vector2.ZERO

var _press_pos: Vector2 = Vector2.ZERO
var _press_body: SpotBody = null
var _down_for: float = -1.0
var _dragging: bool = false
## Every finger on the screen, by its index.
var _touches: Dictionary[int, Vector2] = {}
var _pinching: bool = false
var _pinch_distance: float = 0.0
var _pinch_center: Vector2 = Vector2.ZERO
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
	mouse_filter = Control.MOUSE_FILTER_IGNORE if preview else Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	if not preview:
		add_to_group(CaregiverGate.HOLD_GROUP)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if preview else SubViewport.UPDATE_WHEN_VISIBLE
	_viewport.gui_disable_input = true
	_build_shell()
	# Furniture casts shadows; the enclosing shell receives light without cutaway-wall shadows.
	_sun.look_at_from_position(Vector3(0.8, 6.0, 5.0), Vector3.ZERO, Vector3.UP)
	_sun.shadow_enabled = true
	_sun.light_energy = 0.75
	_env.environment = _make_environment(Style.current)
	_widget.view_chosen.connect(_on_view_chosen)
	resized.connect(_on_resized)
	_widget.resized.connect(_on_resized)
	get_window().focus_exited.connect(_cancel_gestures)
	visibility_changed.connect(_cancel_gestures)
	Style.changed.connect(_on_style_changed)
	_apply_camera()

func show_room(p: Profile, r: Room) -> void:
	_profile = p
	_room = r
	for body: SpotBody in _bodies.values():
		body.queue_free()
	_bodies.clear()
	_spoken_gestalts.clear()
	for s: Spot in r.spots:
		if p.gestalt(s.gestalt_id) == null:
			continue
		var size_m: float = RoomSpace.spot_size_m(s, r)
		var recipe: Recipe = ObjectRecipes.make(s.kind, size_m, Style.current)
		var body: SpotBody = SpotBody.new()
		body.setup(s, recipe, size_m, _material)
		body.set_rest(RoomSpace.place(s, r))
		_world.add_child(body)
		_bodies[s.id] = body
	_tilt_origin = RoomSpace.tilt_origin(r)
	_build_shell()
	_clear_captions()
	_widget.set_mode(r.camera)
	if preview:
		_widget.hide()
	_layout()
	_cancel_press()
	set_view(CameraFraming.View.FRONT, false)
	if preview:
		_elevation = 35.0
		_layout()

## Capture logical toggles and the current camera, without keeping extra live room renderers.
func capture_state() -> State:
	var state: State = State.new()
	for id: String in _bodies:
		state.on[id] = _bodies[id].is_on
	state.spoken = _spoken_gestalts.duplicate()
	state.view = _view
	state.azimuth = _azimuth
	state.elevation = _elevation
	state.zoom = _zoom
	state.pan = _pan
	state.yaw = _yaw
	state.pitch = _pitch
	state.tilt_zoom = _tilt_zoom
	return state

func restore_state(state: State) -> void:
	_stop_view_tween()
	for id: String in state.on:
		if _bodies.has(id):
			_bodies[id].restore_state(state.on[id])
	_spoken_gestalts = state.spoken.duplicate()
	_view = state.view
	_azimuth = state.azimuth
	_elevation = state.elevation
	_zoom = state.zoom
	_pan = state.pan
	_yaw = state.yaw
	_pitch = state.pitch
	_tilt_zoom = state.tilt_zoom
	_widget.show_view(_view)
	_idle = 0.0
	_layout()

## The gestalt a spot says right now, at the scene's stage (`Profile.says`): its alternate when toggled on
## and one exists.
func gestalt_for(s: Spot) -> Gestalt:
	var body: SpotBody = _bodies.get(s.id, null)
	return _profile.says(_room, s, body != null and body.is_on)

func bodies() -> Array[SpotBody]:
	var out: Array[SpotBody] = []
	for body: SpotBody in _bodies.values():
		out.push_back(body)
	return out

## Record the phrase last heard at this spot, before its reaction changed the next tap's phrase.
func recording_gestalt_for(s: Spot) -> Gestalt:
	return _spoken_gestalts.get(s.id, gestalt_for(s))

func body(spot_id: String) -> SpotBody:
	return _bodies.get(spot_id, null)

func view() -> CameraFraming.View:
	return _view

func camera_position() -> Vector3:
	return _camera.global_position

func wall_visible(w: Spot.Wall) -> bool:
	var wall: Node3D = _walls.get(w, null)
	return wall != null and wall.visible

func set_safe_area(rect: Rect2) -> void:
	_device_safe = rect
	_clear_captions()
	_cancel_press()
	_layout()

func device_safe_rect() -> Rect2:
	var full: Rect2 = Rect2(Vector2.ZERO, size)
	var clipped: Rect2 = _device_safe.intersection(full)
	return clipped if clipped.has_area() else full

## The device-safe rectangle minus the floating controls above and below.
func safe_rect() -> Rect2:
	var safe: Rect2 = device_safe_rect()
	var top: float = maxf(safe.position.y, safe_top_px)
	var bottom: float = safe.end.y
	var controls_height: float = maxf(_widget.size.y if _widget.visible else 0.0, navigation_size.y)
	if controls_height > 0.0:
		bottom -= controls_height + 2.0 * WIDGET_MARGIN
	return Rect2(safe.position.x, top, safe.size.x, maxf(bottom - top, 1.0))

## Where a body's center falls on this control.
func screen_point(b: SpotBody) -> Vector2:
	return _camera.unproject_position(b.center_point())

## How many pixels a body's bounds cover on this control, width and height.
func screen_size(b: SpotBody) -> Vector2:
	return screen_bounds(b).size

func screen_bounds(b: SpotBody) -> Rect2:
	var box: AABB = b.bounds()
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	for i: int in 8:
		var corner: Vector2 = _camera.unproject_position(b.to_global(box.get_endpoint(i)))
		low = Vector2(minf(low.x, corner.x), minf(low.y, corner.y))
		high = Vector2(maxf(high.x, corner.x), maxf(high.y, corner.y))
	return Rect2(low, high - low)

## The body under a point on this control, or null. The ray is traced through every body's distance field;
## when it hits nothing, the nearest body whose center is within half the touch floor is taken instead.
func pick_at(point: Vector2) -> SpotBody:
	if not device_safe_rect().has_point(point):
		return null
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
		_spoken_gestalts[b.spot.id] = g
		spot_tapped.emit(b.spot, g)

## Move the camera to a view at rest, animated unless `animate` is false or the style's motion is none. The
## same view as the current one resets its pan, zoom or turn.
func set_view(target: CameraFraming.View, animate: bool = true) -> void:
	_clear_captions()
	var crosses_tilt: bool = _view == CameraFraming.View.TILT or target == CameraFraming.View.TILT
	_view = target
	_widget.show_view(target)
	var angles: Vector2 = CameraFraming.view_angles(target)
	_move_camera(angles.x, angles.y, animate, crosses_tilt)

func zoom() -> float:
	return _zoom

## The fitted vertical extent of the current orbit view, in meters, which the zoom divides.
func frame_extent() -> float:
	return _extent

func pan() -> Vector2:
	return _pan

## Tilt's yaw and pitch, in degrees.
func tilt_angles() -> Vector2:
	return Vector2(_yaw, _pitch)

func tilt_zoom() -> float:
	return _tilt_zoom

## Whether the view has left its rest: another view than Front, or Front panned or zoomed.
func is_moved() -> bool:
	return _view != CameraFraming.View.FRONT or _zoom != 1.0 or _pan != Vector2.ZERO

## Whether the room lets the learner move the view at all.
func can_move_view() -> bool:
	return _room != null and _room.camera != Room.Camera.FIXED

## Move the view by a drag of `delta_px`: Front and Top pan within the fitted frame, Tilt turns within its
## pitch limits. The world follows the finger.
func pan_by(delta_px: Vector2) -> void:
	if not can_move_view():
		return
	_stop_view_tween()
	_clear_captions()
	if _view == CameraFraming.View.TILT:
		var turned: Vector2 = CameraFraming.clamp_tilt(_yaw - delta_px.x * LOOK_DEG_PER_PX, _pitch + delta_px.y * LOOK_DEG_PER_PX)
		_yaw = turned.x
		_pitch = turned.y
	else:
		var per_px: float = CameraFraming.meters_per_px(_extent, size.y, _zoom)
		_pan = _clamp_pan(_pan - Vector2(delta_px.x, -delta_px.y) * per_px)
	_apply_camera()

## Zoom by `factor` about the point `at_px` on this control: Front and Top close in on the fit and keep the
## point under the fingers fixed, Tilt narrows its view.
func zoom_by(factor: float, at_px: Vector2) -> void:
	if not can_move_view() or factor <= 0.0:
		return
	_stop_view_tween()
	_clear_captions()
	if _view == CameraFraming.View.TILT:
		_tilt_zoom = CameraFraming.clamp_tilt_zoom(_tilt_zoom * factor)
	else:
		var next: float = CameraFraming.clamp_zoom(_zoom * factor)
		_pan = CameraFraming.zoom_about(_pan, _extent, size.y, at_px - size / 2.0, _zoom, next)
		_zoom = next
		_pan = _clamp_pan(_pan)
	_apply_camera()

## The pan that keeps the frame inside the room's silhouette at the current zoom.
func _clamp_pan(pan_m: Vector2) -> Vector2:
	var visible: Vector2 = Vector2(size.x / maxf(size.y, 1.0), 1.0) * _extent / _zoom
	return CameraFraming.clamp_pan(pan_m, visible, room_silhouette())

## The room box on the view plane of the current orbit view, in meters right and up from the target.
func room_silhouette() -> Rect2:
	return CameraFraming.room_silhouette(RoomSpace.dims(_room), _target(), _azimuth, _elevation)

## Float `g`'s chunks above spot `s` for about `seconds`, each chunk marked in turn ([ChunkRow]). The pills
## float on their own, with the style's relief and no card behind them.
func show_chunks(s: Spot, g: Gestalt, seconds: float) -> void:
	var b: SpotBody = _bodies.get(s.id, null)
	if b == null:
		return
	_clear_captions()
	var row: ChunkRow = ChunkRow.new()
	row.name = "Caption"
	row.floating = true
	row.set_chunks(g.chunks, CAPTION_FONT_BASE)
	_captions.add_child(row)
	var width: float = minf(CAPTION_MAX_PX, safe_rect().size.x - 48.0)
	row.fit_width(width)
	row.custom_minimum_size.x = minf(width, row.natural_width())
	row.size.x = row.custom_minimum_size.x
	# Wrapped pills settle their height a frame after the first sort; the caption is placed again when they do.
	row.minimum_size_changed.connect(_place_caption.bind(row, b.top_point()), CONNECT_DEFERRED)
	_place_caption.call_deferred(row, b.top_point())
	row.play(seconds)
	var scale_factor: float = Style.motion_scale()
	var hold: float = maxf(seconds, ChunkRow.MIN_PHRASE_SECONDS)
	if scale_factor <= 0.0:
		get_tree().create_timer(hold + 0.5).timeout.connect(row.queue_free)
		return
	var tween: Tween = row.create_tween()
	tween.tween_interval(hold + 0.5)
	tween.tween_property(row, "modulate:a", 0.0, 0.4 * scale_factor)
	tween.tween_callback(row.queue_free)

## The caption on screen now, or null.
func caption_row() -> ChunkRow:
	for caption: Node in _captions.get_children():
		if not caption.is_queued_for_deletion():
			return caption as ChunkRow
	return null

func _place_caption(caption: Control, at: Vector3) -> void:
	if not is_instance_valid(caption) or caption.is_queued_for_deletion():
		return
	caption.reset_size()
	var anchor: Vector2 = _camera.unproject_position(at)
	var safe: Rect2 = safe_rect().grow(-16.0)
	caption.position = Vector2(
		clampf(anchor.x - caption.size.x / 2.0, safe.position.x, maxf(safe.position.x, safe.end.x - caption.size.x)),
		clampf(anchor.y - caption.size.y - 12.0, safe.position.y, maxf(safe.position.y, safe.end.y - caption.size.y)))

func _clear_captions() -> void:
	for caption: Node in _captions.get_children():
		_captions.remove_child(caption)
		caption.queue_free()

# --- input ------------------------------------------------------------------------------------------------

## One finger arrives as emulated mouse events and drives the tap, the hold and the drag. Raw touch events
## are tracked beside them only to see a second finger, which turns the gesture into a pinch. A trackpad's
## magnify and pan gestures and a scroll wheel do the same on a desktop.
func _gui_input(event: InputEvent) -> void:
	if preview:
		return
	_idle = 0.0
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		_on_touch(touch)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_on_touch_drag(drag)
	elif event is InputEventMagnifyGesture:
		var magnify: InputEventMagnifyGesture = event
		zoom_by(magnify.factor, magnify.position)
		accept_event()
	elif event is InputEventPanGesture:
		var pan_gesture: InputEventPanGesture = event
		pan_by(-pan_gesture.delta)
		accept_event()
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		_on_mouse_button(button)
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		_on_mouse_motion(motion)

func _on_mouse_button(button: InputEventMouseButton) -> void:
	if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if button.pressed and device_safe_rect().has_point(button.position):
			var step: float = WHEEL_ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL_ZOOM_STEP
			zoom_by(step, button.position)
		accept_event()
		return
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	if not device_safe_rect().has_point(button.position):
		_cancel_press()
		return
	if button.pressed:
		if _pinching:
			return
		_press_pos = button.position
		_press_body = pick_at(button.position)
		_down_for = 0.0
		_dragging = false
		set_process(true)
	elif _down_for >= 0.0:
		var was_tap: bool = not _dragging and _press_body != null
		var tapped: SpotBody = _press_body
		_cancel_press()
		if was_tap:
			tap(tapped)
	accept_event()

func _on_mouse_motion(motion: InputEventMouseMotion) -> void:
	if _down_for < 0.0 or _pinching:
		return
	if not device_safe_rect().has_point(motion.position):
		_cancel_press()
		return
	if not _dragging and motion.position.distance_to(_press_pos) > DRAG_PX:
		# Past the threshold the press is a drag: the hold is off, and the view moves wherever the press began.
		_dragging = true
		_press_body = null
	if _dragging:
		pan_by(motion.relative)
	accept_event()

func _on_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		_touches[touch.index] = touch.position
	else:
		_touches.erase(touch.index)
	if _touches.size() >= 2:
		if not _pinching:
			_begin_pinch()
	elif _pinching:
		# The pinch ends with the second finger. The press it cancelled stays cancelled, so the first finger's
		# release is not a tap.
		_pinching = false

func _on_touch_drag(drag: InputEventScreenDrag) -> void:
	if not _touches.has(drag.index):
		return
	_touches[drag.index] = drag.position
	if not _pinching or _touches.size() < 2:
		return
	var fingers: Array[Vector2] = _fingers()
	var distance: float = fingers[0].distance_to(fingers[1])
	var center: Vector2 = (fingers[0] + fingers[1]) / 2.0
	if _pinch_distance > 1.0:
		zoom_by(distance / _pinch_distance, center)
	pan_by(center - _pinch_center)
	_pinch_distance = distance
	_pinch_center = center

func _begin_pinch() -> void:
	_cancel_press()
	_pinching = true
	var fingers: Array[Vector2] = _fingers()
	_pinch_distance = fingers[0].distance_to(fingers[1])
	_pinch_center = (fingers[0] + fingers[1]) / 2.0

func _fingers() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for at: Vector2 in _touches.values():
		out.push_back(at)
	return out

func _process(delta: float) -> void:
	if _down_for >= 0.0:
		if _press_body != null and not _dragging:
			_down_for += delta
			if _down_for >= HOLD_SECONDS:
				var held: SpotBody = _press_body
				_cancel_press()
				var g: Gestalt = recording_gestalt_for(held.spot)
				if g != null:
					spot_held.emit(held.spot, g)
		return
	if _pinching or not _touches.is_empty() or not is_moved():
		return
	_idle += delta
	if _idle >= idle_seconds:
		_idle = 0.0
		set_view(CameraFraming.View.FRONT)

func _cancel_press() -> void:
	_down_for = -1.0
	_press_body = null
	_dragging = false
	_idle = 0.0
	set_process(not preview and _room != null and is_visible_in_tree())

## End a press without a tap or a hold, for the caregiver chord ([CaregiverGate]).
func cancel_hold() -> void:
	_cancel_press()

## Forget every finger too, for a window that lost focus or a view that was hidden mid-gesture.
func _cancel_gestures() -> void:
	_touches.clear()
	_pinching = false
	_cancel_press()

func _on_view_chosen(target: CameraFraming.View) -> void:
	_idle = 0.0
	set_view(target)

# --- camera -----------------------------------------------------------------------------------------------

## Fit object bounds and the floor in perspective inside the band left by the floating controls.
func _extent_for(azimuth: float, elevation: float) -> float:
	var points: Array[Vector3] = []
	for body: SpotBody in _bodies.values():
		var box: AABB = body.bounds()
		for corner: int in 8:
			points.push_back(RoomSpace.place(body.spot, _room) * box.get_endpoint(corner))
	for x: float in [-RoomSpace.dims(_room).x / 2.0, RoomSpace.dims(_room).x / 2.0]:
		for z: float in [-RoomSpace.dims(_room).z / 2.0, RoomSpace.dims(_room).z / 2.0]:
			points.push_back(Vector3(x, 0.0, z))
	return CameraFraming.points_extent(points, _target(), azimuth, elevation, size, safe_rect().grow(-16.0))

## Take the camera to a view at rest. Between Front and Top the camera slides along the orbit while the pan and
## zoom ease out. Into or out of Tilt it blends its transform, field of view and band offsets straight across.
func _move_camera(azimuth: float, elevation: float, animate: bool, crosses_tilt: bool) -> void:
	_stop_view_tween()
	var from_xf: Transform3D = _camera.transform
	var from_fov: float = _fov
	var from_offset: Vector2 = Vector2(_camera.h_offset, _camera.v_offset)
	var from_pan: Vector2 = _pan
	var from_zoom: float = _zoom
	var extent: float = _extent_for(azimuth, elevation)
	_yaw = 0.0
	_pitch = 0.0
	_tilt_zoom = 1.0
	var scale_factor: float = Style.motion_scale()
	if not animate or scale_factor <= 0.0 or not is_inside_tree():
		_azimuth = azimuth
		_elevation = elevation
		_extent = extent
		_pan = Vector2.ZERO
		_zoom = 1.0
		_apply_camera()
		return
	_view_tween = create_tween()
	if crosses_tilt:
		_azimuth = azimuth
		_elevation = elevation
		_extent = extent
		_pan = Vector2.ZERO
		_zoom = 1.0
		_apply_camera()
		_blend_xf_from = from_xf
		_blend_xf_to = _camera.transform
		_blend_fov_from = from_fov
		_blend_fov_to = _fov
		_blend_offset_from = from_offset
		_blend_offset_to = Vector2(_camera.h_offset, _camera.v_offset)
		_view_tween.tween_method(_blend_transform, 0.0, 1.0, VIEW_TWEEN_SECONDS * scale_factor) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_view_tween.tween_callback(_apply_camera)
		return
	_blend_from = Vector3(_azimuth, _elevation, _extent)
	_blend_to = Vector3(azimuth, elevation, extent)
	_blend_pan_from = from_pan
	_blend_zoom_from = from_zoom
	_view_tween.tween_method(_blend, 0.0, 1.0, VIEW_TWEEN_SECONDS * scale_factor) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _stop_view_tween() -> void:
	if _view_tween != null:
		_view_tween.kill()
		_view_tween = null

func _blend(t: float) -> void:
	var now: Vector3 = _blend_from.lerp(_blend_to, t)
	_azimuth = now.x
	_elevation = now.y
	_extent = _extent_for(_azimuth, _elevation)
	_pan = _blend_pan_from.lerp(Vector2.ZERO, t)
	_zoom = lerpf(_blend_zoom_from, 1.0, t)
	_apply_camera()

func _blend_transform(t: float) -> void:
	_fov = lerpf(_blend_fov_from, _blend_fov_to, t)
	_camera.fov = _fov
	_camera.transform = _blend_xf_from.interpolate_with(_blend_xf_to, t)
	var offset: Vector2 = _blend_offset_from.lerp(_blend_offset_to, t)
	_camera.h_offset = offset.x
	_camera.v_offset = offset.y
	_update_walls()

func _apply_camera() -> void:
	if _view == CameraFraming.View.TILT:
		_apply_tilt_camera()
	else:
		_apply_orbit_camera()
	_update_walls()

## An orbit view: the camera stands off the target at the distance that frames `_extent` over `_zoom`, trucked
## by `_pan` and by the band the floating controls leave.
func _apply_orbit_camera() -> void:
	_pan = _clamp_pan(_pan)
	var visible_extent: float = _extent / _zoom
	var distance: float = CameraFraming.perspective_distance(visible_extent, CameraFraming.FOV_DEG)
	_fov = CameraFraming.FOV_DEG
	_camera.fov = _fov
	var direction: Vector3 = CameraFraming.orbit_direction(_azimuth, _elevation)
	var up: Vector3 = CameraFraming.orbit_up(_azimuth, _elevation)
	var right: Vector3 = up.cross(direction)
	var target: Vector3 = _target() + right * _pan.x + up * _pan.y
	_camera.transform = CameraFraming.camera_transform(target, _azimuth, _elevation, distance)
	var safe: Rect2 = safe_rect()
	_camera.h_offset = -CameraFraming.center_offset(safe.get_center().x - size.x / 2.0, size.y, visible_extent)
	_camera.v_offset = CameraFraming.center_offset(safe.get_center().y - size.y / 2.0, size.y, visible_extent)

## Tilt: the camera stands at the room's center and turns in place. It looks through the whole viewport, since
## the learner can turn to anything the floating controls cover.
func _apply_tilt_camera() -> void:
	_fov = CameraFraming.tilt_fov(_tilt_zoom, size.x / maxf(size.y, 1.0))
	_camera.fov = _fov
	_camera.transform = CameraFraming.tilt_transform(_tilt_origin, _yaw, _pitch)
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0

## Keep a closed backdrop around the effective camera, including its framing offsets and animated path.
func _update_walls() -> void:
	if _floor == null:
		return
	var box: Vector3 = RoomSpace.dims(_room)
	var eye: Vector3 = _camera.get_camera_transform().origin
	var end: Vector3 = RoomSpace.shell_end(eye, _room)
	var t: float = RoomSpace.WALL
	var depth: float = end.z + box.z / 2.0
	var center_z: float = (end.z - box.z / 2.0) / 2.0
	_fit_slab(_floor, Vector3(box.x + 2.0 * t, t, depth + 2.0 * t), Vector3(0, -t / 2.0, center_z))
	_fit_slab(_front, Vector3(box.x + 2.0 * t, end.y, t), Vector3(0, end.y / 2.0, end.z + t / 2.0))
	_fit_slab(_ceiling, Vector3(box.x + 2.0 * t, t, depth + 2.0 * t), Vector3(0, end.y + t / 2.0, center_z))
	_fit_slab(_front_trim, Vector3(box.x, 0.09, 0.025), Vector3(0, 0.045, end.z - 0.0125))
	var rise: float = end.y - box.y
	var extension: float = end.z - box.z / 2.0
	for wall: int in _walls:
		var upper: MeshInstance3D = _upper_walls[wall]
		upper.visible = rise > 0.0
		if wall == Spot.Wall.BACK:
			_fit_slab(upper, Vector3(box.x, maxf(rise, 0.001), t), Vector3(0, box.y + rise / 2.0, -(box.z + t) / 2.0))
		else:
			var side: float = -1.0 if wall == Spot.Wall.LEFT else 1.0
			_fit_slab(upper, Vector3(t, maxf(rise, 0.001), depth), Vector3(side * (box.x + t) / 2.0, box.y + rise / 2.0, center_z))
			_wall_extensions[wall].visible = extension > 0.0
			_trim_extensions[wall].visible = extension > 0.0
			var extension_z: float = (end.z + box.z / 2.0) / 2.0
			_fit_slab(_wall_extensions[wall], Vector3(t, box.y, maxf(extension, 0.001)), Vector3(side * (box.x + t) / 2.0, box.y / 2.0, extension_z))
			_fit_slab(_trim_extensions[wall], Vector3(0.025, 0.09, maxf(extension, 0.001)), Vector3(side * (box.x / 2.0 - 0.0125), 0.045, extension_z))

func _fit_slab(slab: MeshInstance3D, dimensions: Vector3, at: Vector3) -> void:
	slab.scale = dimensions
	slab.position = at

## The front wall and ceiling remain present in every view.
func enclosure_visible() -> bool:
	return _enclosure != null and _enclosure.visible

func _on_resized() -> void:
	_clear_captions()
	_layout()

## What the camera looks at: a little under the center of the framed box, since a raised camera sees more
## floor than ceiling and the near floor edge projects larger.
func _target() -> Vector3:
	return Vector3(0.0, RoomSpace.content_dims(_room).y * 0.42, 0.0)

## The viewport fills the control edge to edge; the widget floats over its bottom right corner, and the camera
## frames the room into the band the floating controls leave.
func _layout() -> void:
	var safe: Rect2 = device_safe_rect()
	_widget.fit_width(maxf(safe.size.x - WIDGET_MARGIN * 2.0 - navigation_size.x - (WIDGET_MARGIN if navigation_size.x > 0.0 else 0.0), 1.0))
	_widget.reset_size()
	_container.position = Vector2.ZERO
	_container.size = size
	_widget.position = safe.end - _widget.size - Vector2.ONE * WIDGET_MARGIN
	_extent = _extent_for(_azimuth, _elevation)
	_apply_camera()
	if preview:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

# --- the room box -----------------------------------------------------------------------------------------

## Build the authored walls once, with adjustable extensions that enclose every camera view.
func _build_shell() -> void:
	if _shell != null:
		_world.remove_child(_shell)
		_shell.queue_free()
	_walls.clear()
	_upper_walls.clear()
	_wall_extensions.clear()
	_trim_extensions.clear()
	_shell = Node3D.new()
	_shell.name = "Shell"
	_world.add_child(_shell)
	var shell_room: Room = Room.new()
	shell_room.width = RoomSpace.dims(_room).x
	shell_room.height = RoomSpace.dims(_room).y
	shell_room.depth = RoomSpace.dims(_room).z
	for body: SpotBody in _bodies.values():
		shell_room.spots.push_back(body.spot)
	var w: float = RoomSpace.dims(_room).x
	var t: float = RoomSpace.WALL
	_floor = _slab(Vector3.ONE, Vector3.ZERO, Style.current.floor_color, _shell)
	_floor.name = "Floor"
	for wall: Spot.Wall in [Spot.Wall.BACK, Spot.Wall.LEFT, Spot.Wall.RIGHT]:
		var group: Node3D = Node3D.new()
		_shell.add_child(group)
		_walls[wall] = group
		var color: Color = Style.current.wall_color if wall == Spot.Wall.BACK else Style.current.wall_color.darkened(0.06)
		for section: Rect2 in RoomSpace.wall_sections(wall, shell_room):
			var mid: Vector2 = section.get_center()
			if wall == Spot.Wall.BACK:
				_slab(Vector3(section.size.x, section.size.y, t), Vector3(mid.x - w / 2.0, mid.y, -RoomSpace.dims(_room).z / 2.0 - t / 2.0), color, group)
			else:
				var x: float = (w + t) / 2.0 * (-1.0 if wall == Spot.Wall.LEFT else 1.0)
				_slab(Vector3(t, section.size.y, section.size.x), Vector3(x, mid.y, mid.x - RoomSpace.dims(_room).z / 2.0), color, group)
			if section.position.y <= 0.001:
				var trim: Color = Style.current.wood.lightened(0.30)
				if wall == Spot.Wall.BACK:
					_slab(Vector3(section.size.x, 0.09, 0.025), Vector3(mid.x - w / 2.0, 0.045, -RoomSpace.dims(_room).z / 2.0 + 0.0125), trim, group)
				else:
					var side_x: float = (w / 2.0 - 0.0125) * (-1.0 if wall == Spot.Wall.LEFT else 1.0)
					_slab(Vector3(0.025, 0.09, section.size.x), Vector3(side_x, 0.045, mid.x - RoomSpace.dims(_room).z / 2.0), trim, group)
		_upper_walls[wall] = _slab(Vector3.ONE, Vector3.ZERO, color, group)
		if wall != Spot.Wall.BACK:
			_wall_extensions[wall] = _slab(Vector3.ONE, Vector3.ZERO, color, group)
			_trim_extensions[wall] = _slab(Vector3.ONE, Vector3.ZERO, Style.current.wood.lightened(0.30), group)
	_build_enclosure()
	_build_exterior()
	_update_walls()

func _build_enclosure() -> void:
	_enclosure = Node3D.new()
	_enclosure.name = "Enclosure"
	_shell.add_child(_enclosure)
	_front = _slab(Vector3.ONE, Vector3.ZERO, Style.current.wall_color, _enclosure)
	_front.name = "Front"
	_ceiling = _slab(Vector3.ONE, Vector3.ZERO, Style.current.wall_color.lightened(0.12), _enclosure)
	_ceiling.name = "Ceiling"
	_front_trim = _slab(Vector3.ONE, Vector3.ZERO, Style.current.wood.lightened(0.30), _enclosure)
	_front_trim.name = "Baseboard"

## A quiet, deterministic garden gives every aperture real depth from every camera angle.
func _build_exterior() -> void:
	var preset: StylePreset = Style.current
	var grass: Color = preset.cloth.lerp(Color(0.28, 0.42, 0.24), 0.6)
	_slab(Vector3(80.0, 0.08, 80.0), Vector3(0.0, -0.10, 0.0), grass, _shell)
	_slab(Vector3(3.0, 0.02, 1.1), Vector3(-3.5, -0.045, -0.75), preset.floor_color, _shell)
	var trees: Array[Vector3] = [Vector3(-5.5, 0, -3.5), Vector3(-6, 0, 2), Vector3(0, 0, -6), Vector3(3.2, 0, -5), Vector3(6, 0, -2)]
	for at: Vector3 in trees:
		var recipe: Recipe = Recipe.new()
		recipe.add(Primitive.capsule(0.12, 1.7, Transform3D(Basis.IDENTITY, at + Vector3(0, 0.85, 0)), preset.wood))
		recipe.add(Primitive.sphere(1.1, Transform3D(Basis.IDENTITY, at + Vector3(0, 2.2, 0)), grass.darkened(0.16)))
		recipe.add(Primitive.sphere(0.8, Transform3D(Basis.IDENTITY, at + Vector3(0.7, 1.9, 0.15)), grass))
		_shell.add_child(RecipeBuilder.build(recipe, _material))

func _slab(size_m: Vector3, at: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var batch: MeshBatch = Mesher.box(size_m / 2.0, 0.0, color)
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, batch.to_arrays())
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = at
	parent.add_child(instance)
	return instance

func _make_environment(preset: StylePreset) -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = preset.glass.lerp(Color.WHITE, 0.32)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = preset.wall_color.lerp(Color.WHITE, 0.4)
	env.ambient_light_energy = 0.55
	return env

func _on_style_changed(preset: StylePreset) -> void:
	# The chooser can remove previews during this same style signal, before their queued deletion.
	if not is_inside_tree():
		return
	_env.environment = _make_environment(preset)
	_build_shell()
	_apply_camera()

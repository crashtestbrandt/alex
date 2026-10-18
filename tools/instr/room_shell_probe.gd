extends Control
## Enclosure coverage, baseboards and shadows across phone views, pans and transitions.
## Optional --capture=<directory> writes rendered iPhone 17 Pro Max views.
const MAIN: PackedScene = preload("res://scenes/main.tscn")
var _failures: int = 0
var _out: String = ""

func _ready() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL " + label)

func _settle() -> void:
	for frame: int in 8:
		await get_tree().process_frame

func _tap(control: Control) -> void:
	for down: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)

func _bounds(node: Node3D, result: Array[AABB]) -> void:
	if not node.visible:
		return
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node as MeshInstance3D
		result.push_back(mesh.global_transform * mesh.get_aabb())
		_check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "shell does not cast cutaway shadows")
	for child: Node in node.get_children():
		if child is Node3D:
			_bounds(child as Node3D, result)

func _coverage(room: RoomView, source: Room, label: String) -> void:
	var camera: Camera3D = room.get_node("%Camera") as Camera3D
	var bounds: Array[AABB] = []
	_bounds(room._floor, bounds)
	_bounds(room._enclosure, bounds)
	for wall: Node3D in room._walls.values():
		_check(wall.visible, label + " authored walls stay visible")
		_bounds(wall, bounds)
	# Exterior rays are allowed only through an authored door or window aperture.
	for spot: Spot in source.spots:
		if spot.wall == Spot.Wall.NONE:
			continue
		var hole: Rect2 = ObjectRecipes.opening(spot.kind, RoomSpace.spot_size_m(spot, source))
		if hole.has_area():
			bounds.push_back(RoomSpace.place(spot, source) * AABB(Vector3(hole.position.x, hole.position.y, -0.1), Vector3(hole.size.x, hole.size.y, 0.2)))
	var missed: int = 0
	for x: int in 21:
		for y: int in 21:
			var pixel: Vector2 = room.size * Vector2((x + 0.01) / 20.02, (y + 0.01) / 20.02)
			var origin: Vector3 = camera.project_ray_origin(pixel)
			var direction: Vector3 = camera.project_ray_normal(pixel)
			var hit: bool = false
			for box: AABB in bounds:
				if box.intersects_ray(origin, direction) is Vector3:
					hit = true
					break
			if not hit:
				missed += 1
	_check(missed == 0, "%s: %d rays escape the room outside an aperture" % [label, missed])
	var trim: AABB = room._front_trim.global_transform * room._front_trim.get_aabb()
	var front: AABB = room._front.global_transform * room._front.get_aabb()
	_check(is_equal_approx(trim.position.y, 0.0) and is_equal_approx(trim.end.z, front.position.z), label + " front baseboard meets the wall and floor")
	_check(is_equal_approx(trim.size.x, source.width), label + " front baseboard spans both corners")

func _capture(room: RoomView, label: String) -> void:
	if _out.is_empty():
		return
	await _settle()
	RenderingServer.force_draw()
	var viewport: SubViewport = room.get_node("%Viewport") as SubViewport
	_check(viewport.get_texture().get_image().save_png(_out.path_join(label + ".png")) == OK, "capture " + label)

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_out = arg.trim_prefix("--capture=")
			DirAccess.make_dir_recursive_absolute(_out)
	var repo: ProfileRepo = ProfileRepo.new("user://room_shell_%s" % OS.get_process_id())
	ProfileStore.repo = repo
	var profile: Profile = repo.create_profile("Sam", Starter.find("home_routines"), "calm")
	for pack: Starter in Starter.list_all():
		if pack.is_scene() and not profile.has_scene(pack.id):
			pack.add_to(profile)
	# Simulate a saved profile whose geometry is current but camera defaults predate Tilt.
	for old_room: Room in profile.rooms:
		old_room.camera = Room.Camera.VIEWS
	var main: Main = MAIN.instantiate() as Main
	add_child(main)
	for style_id: String in ["calm", "bold", "quiet"]:
		profile.style_id = style_id
		repo.save_profile(profile)
		main.open_profile(profile.id)
		for window_size: Vector2i in [Vector2i(440, 956), Vector2i(956, 440)]:
			get_window().size = window_size
			main.set_safe_area_override(Rect2(0, 62, 440, 860) if window_size.x == 440 else Rect2(62, 0, 832, 419))
			await _settle()
			var home: ChildHome = main.get_node("%ChildHome") as ChildHome
			var room: RoomView = home.get_node("%RoomView") as RoomView
			for source: Room in home._profile.rooms:
				home.show_room(source)
				await _settle()
				var widget: ViewWidget = room.get_node("%ViewWidget") as ViewWidget
				var tilt: SdfButton = widget.items()[CameraFraming.View.TILT]
				_check(tilt.is_visible_in_tree(), source.id + " saved and added rooms expose Tilt")
				_check(main.safe_area_rect().encloses(tilt.get_global_rect()), source.id + " Tilt stays inside the phone safe area")
				_tap(tilt)
				_check(room.view() == CameraFraming.View.TILT, source.id + " Tilt responds to a native pointer tap")
				var label: String = "%s-%s-%dx%d" % [source.id, style_id, window_size.x, window_size.y]
				for view: CameraFraming.View in [CameraFraming.View.FRONT, CameraFraming.View.TOP, CameraFraming.View.TILT]:
					room.set_view(view, false)
					_coverage(room, source, label + " view %d" % view)
					if style_id == "calm":
						await _capture(room, label + "-view%d" % view)
					if view == CameraFraming.View.TILT:
						for yaw: float in [-180.0, -90.0, 0.0, 90.0]:
							for pitch: float in [-40.0, 30.0]:
								var state: RoomView.State = room.capture_state()
								state.yaw = yaw
								state.pitch = pitch
								room.restore_state(state)
								_coverage(room, source, label + " tilt %s/%s" % [yaw, pitch])
								if style_id == "calm" and yaw == -180.0 and pitch == -40.0:
									await _capture(room, label + "-front-trim")
					else:
						room.zoom_by(3.0, room.safe_rect().get_center())
						for pan: Vector2 in [Vector2(-10000, -10000), Vector2(10000, 10000), Vector2(-10000, 10000), Vector2(10000, -10000)]:
							room.pan_by(pan)
							_coverage(room, source, label + " zoomed pan " + str(pan))
				# Sample the actual interpolated camera path without relying on wall-clock timing.
				room.set_view(CameraFraming.View.FRONT, false)
				room.set_view(CameraFraming.View.TILT, true)
				if Style.motion_scale() > 0.0:
					room._stop_view_tween()
					for step: int in 11:
						room._blend_transform(step / 10.0)
						_coverage(room, source, label + " transition %d" % step)
				print("SHELL checked " + label)
	repo.delete_profile(profile.id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(repo.root))
	print("ROOM-SHELL-PROBE %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

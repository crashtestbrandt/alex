extends Control
## Learner navigation, session state and safe-area layout with the real room chooser.
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
	for frame: int in 12:
		await get_tree().process_frame

func _mouse(at: Vector2, down: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	get_viewport().push_input(event, true)

func _tap(control: Control) -> void:
	_mouse(control.get_global_rect().get_center(), true)
	_mouse(control.get_global_rect().get_center(), false)

func _drag(at: Vector2) -> void:
	_mouse(at, true)
	for step: int in 8:
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = at + Vector2(0, -20 * (step + 1))
		motion.global_position = motion.position
		motion.relative = Vector2(0, -20)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
		await get_tree().process_frame
	_mouse(at + Vector2(0, -160), false)
	await _settle()

func _capture(name: String) -> void:
	if _out.is_empty():
		return
	RenderingServer.force_draw()
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png")) == OK, "capture " + name)

func _same_state(room: RoomView, expected: RoomView.State, label: String) -> void:
	var actual: RoomView.State = room.capture_state()
	_check(actual.on == expected.on, label + " toggles")
	_check(actual.spoken == expected.spoken, label + " last-spoken phrases")
	_check(actual.view == expected.view and is_equal_approx(actual.zoom, expected.zoom) and actual.pan.is_equal_approx(expected.pan), label + " orbit camera")
	_check(is_equal_approx(actual.yaw, expected.yaw) and is_equal_approx(actual.pitch, expected.pitch) and is_equal_approx(actual.tilt_zoom, expected.tilt_zoom), label + " tilt camera")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_out = arg.trim_prefix("--capture=")
			DirAccess.make_dir_recursive_absolute(_out)
	var repo: ProfileRepo = ProfileRepo.new("user://room_switch_%s" % OS.get_process_id())
	ProfileStore.repo = repo
	var p: Profile = repo.create_profile("Sam", Starter.find("home_routines"), "calm")
	for pack: Starter in Starter.list_all():
		if pack.is_scene() and not p.has_scene(pack.id):
			pack.add_to(p)
	p.set_scene_stage("bath_time", NlaStage.Stage.SINGLE_WORDS)
	repo.save_profile(p)
	var main: Main = MAIN.instantiate() as Main
	add_child(main)
	await _settle()
	var home: ChildHome = main.get_node("%ChildHome") as ChildHome
	var room: RoomView = home.get_node("%RoomView") as RoomView
	var chooser: RoomChooser = home.room_chooser()
	for style_id: String in ["calm", "bold", "quiet"]:
		p.style_id = style_id
		repo.save_profile(p)
		for window_size: Vector2i in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024)]:
			get_window().size = window_size
			main.open_profile(p.id)
			main.set_safe_area_override(Rect2(0, 24, window_size.x, window_size.y - 42))
			await _settle()
			var label: String = "%s-%dx%d" % [style_id, window_size.x, window_size.y]
			var nav: GlyphBar = home.room_navigation()
			var views: ViewWidget = room.get_node("%ViewWidget") as ViewWidget
			_check(nav.visible, label + " rooms control is visible")
			_check(main.safe_area_rect().encloses(nav.get_rect()), label + " rooms control respects safe area")
			_check(not nav.get_global_rect().intersects(views.get_global_rect()), label + " room and camera controls do not overlap")
			room.tap(room.body("door"))
			room.tap(room.body("light"))
			room.set_view(CameraFraming.View.TOP, false)
			room.zoom_by(1.7, room.safe_rect().get_center())
			room.pan_by(Vector2(20, 10))
			var bedroom: RoomView.State = room.capture_state()
			_tap(nav.items()[0])
			await _settle()
			_check(chooser.visible and not room.visible, label + " chooser replaces the live room")
			_check(chooser.cards().size() == p.rooms.size(), label + " one preview per room")
			for i: int in p.rooms.size():
				var card: RoomPreview = chooser.cards()[i]
				_check(card.room.id == p.rooms[i].id, label + " stable saved order")
				_check(card.size.x >= Style.current.tile_min_size and card.size.y >= Style.current.tile_min_size, label + " large preview targets")
				_check(card.current == (i == 0), label + " current room marker")
				_check(not card._preview.is_processing() and card._preview.mouse_filter == Control.MOUSE_FILTER_IGNORE, label + " previews are passive")
				var viewport: SubViewport = card._preview.get_node("%Viewport") as SubViewport
				_check(viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS and viewport.render_target_update_mode != SubViewport.UPDATE_WHEN_VISIBLE, label + " previews do not render continuously")
			_capture(label + "-chooser")
			if chooser._scroll.get_v_scroll_bar().max_value > chooser._scroll.size.y:
				var before: int = chooser._scroll.scroll_vertical
				await _drag(chooser.cards()[0].get_global_rect().get_center())
				_check(chooser.visible and chooser._scroll.scroll_vertical > before + 24, label + " dragging a preview scrolls without choosing")
			_tap(chooser._back)
			await _settle()
			_same_state(room, bedroom, label + " cancel")
			home.show_room_chooser()
			await _settle()
			chooser._scroll.ensure_control_visible(chooser.cards()[1])
			await _settle()
			_tap(chooser.cards()[1])
			await _settle()
			_check(home._room.id == p.rooms[1].id and not chooser.visible, label + " chosen room opens")
			_check(chooser.cards().is_empty(), label + " preview renderers are released")
			_check(not room.body("door").is_on, label + " rooms do not share object state")
			room.tap(room.body("tub"))
			room.set_view(CameraFraming.View.TOP, false)
			var bathroom: RoomView.State = room.capture_state()
			_check(room.gestalt_for(room.body("tub").spot).stage == NlaStage.Stage.SINGLE_WORDS, label + " chosen scene retains its stage")
			home.show_words()
			await _settle()
			_check(not nav.visible, label + " room control stays in Explore")
			home.show_explore()
			await _settle()
			_check(home._room.id == p.rooms[1].id, label + " Words returns to selected room")
			_same_state(room, bathroom, label + " Words return")
			_check((room.body("tub").get_node("Object/water") as MeshInstance3D).visible, label + " tub remains visibly filled")
			home.show_room_chooser()
			await _settle()
			_tap(chooser.cards()[0])
			await _settle()
			_same_state(room, bedroom, label + " bedroom return")
			_check(is_equal_approx((room.body("door").get_node("Object/leaf") as MeshInstance3D).rotation.y, SpotBody.OPEN_RAD), label + " door restored open without replay")
			var bulb: MeshInstance3D = room.body("light").get_node("Object/bulb") as MeshInstance3D
			var light_material: StandardMaterial3D = bulb.material_override as StandardMaterial3D
			_check(is_equal_approx(light_material.emission_energy_multiplier, SpotBody.GLOW_ENERGY), label + " light remains visibly on")
			room.set_view(CameraFraming.View.TILT, false)
			room.pan_by(Vector2(40, -20))
			room.zoom_by(1.3, room.safe_rect().get_center())
			var tilted: RoomView.State = room.capture_state()
			home.show_words()
			home.show_explore()
			await _settle()
			_same_state(room, tilted, label + " tilt round trip")
			room.set_view(CameraFraming.View.FRONT, false)
			_capture(label + "-room")
			for offered: Room in home._profile.rooms:
				home.show_room(offered)
				await _settle()
				for view: CameraFraming.View in [CameraFraming.View.FRONT, CameraFraming.View.TOP]:
					room.set_view(view, false)
					for body: SpotBody in room.bodies():
						var reachable: bool = room.pick_at(room.screen_point(body)) == body
						var rect: Rect2 = room.screen_bounds(body)
						for x: int in range(1, 5):
							for y: int in range(1, 5):
								reachable = reachable or room.pick_at(rect.position + rect.size * Vector2(x / 5.0, y / 5.0)) == body
						_check(reachable, label + " " + offered.id + "/" + body.spot.id + " remains tappable with room navigation")
			print("ROOM-SWITCH checked " + label)
	# Reopening a profile starts a fresh session at the caregiver's entry room.
	main.open_profile(p.id)
	await _settle()
	_check(home._room.id == p.explore_room().id and not room.body("door").is_on, "profile selection resets to its entry and clears room state")
	# A one-room profile needs no chooser; another profile must not inherit the previous session.
	var single: Profile = repo.create_profile("One room", Starter.find("home_routines"), "calm")
	home.show_room_chooser()
	Style.apply(StylePreset.load_by_id("bold"))
	await _settle()
	_check(chooser.visible and chooser.cards().size() == p.rooms.size(), "style change rebuilds an open chooser")
	main.open_profile(single.id)
	await _settle()
	_check(not home.room_navigation().visible, "single-room profile has no rooms button")
	home.show_room_chooser()
	_check(not chooser.visible, "single-room profile cannot open an empty choice")
	repo.delete_profile(single.id)
	repo.delete_profile(p.id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(repo.root))
	print("ROOM-SWITCH-PROBE %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

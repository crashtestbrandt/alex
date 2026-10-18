extends Control
## Room probe: seed a profile from the home starter, open it in the real main scene, pick every spot through
## its own screen point, tap it twice, move the camera through every view, turn it past its limits, let it
## idle back to the front, and switch to Words and back on the strip. Runs headless (`just room-probe`); it
## needs the live scene tree, which is why it is a probe and not a unit suite (docs/gates.md). Prints
## ROOM-PROBE PASS or FAIL and exits with the matching code. The profile it makes is deleted on the way out.
##
## The root is a Control so the window's theme reaches the home screen.

const _MAIN: PackedScene = preload("res://scenes/main.tscn")
const _ROOM_TITLE: String = "Bedroom"
const _BOARD_TITLE: String = "Favorites"

var _failures: PackedStringArray = PackedStringArray()

func _ready() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures.push_back(label)
		print("  FAIL %s" % label)

func _run() -> void:
	get_window().size = Vector2i(1280, 800)
	var repo: ProfileRepo = ProfileRepo.new("user://room_probe_%s" % OS.get_process_id())
	ProfileStore.repo = repo
	var starter: Starter = Starter.find("home_routines")
	var p: Profile = repo.create_profile("Probe", starter, "bold")
	_check(p != null, "profile created")
	if p == null:
		_finish(repo, "")
		return
	# Titles the strip must never show.
	p.rooms[0].title = _ROOM_TITLE
	p.boards[0].title = _BOARD_TITLE
	repo.save_profile(p)
	var main: Main = _MAIN.instantiate() as Main
	add_child(main)
	await get_tree().process_frame
	main.open_profile(p.id)
	await get_tree().process_frame
	await get_tree().process_frame

	var home: ChildHome = main.get_node("%ChildHome") as ChildHome
	var room_view: RoomView = home.get_node("%RoomView") as RoomView
	var captions: Control = room_view.get_node("%Captions") as Control
	var widget: ViewWidget = room_view.get_node("%ViewWidget") as ViewWidget
	_check(home.visible, "home is shown after open_profile")
	_check(room_view.visible, "the room is the first screen")
	_check(room_view.size.x > 100.0 and room_view.size.y > 100.0, "the room view has a size (%s)" % room_view.size)
	_check_strip(home, p)

	var safe: Rect2 = room_view.safe_rect()
	_check(safe.position.y > 40.0 and safe.end.y < room_view.size.y - 40.0, "floating controls leave a band (%s of %s)" % [safe, room_view.size])
	var camera: Camera3D = room_view.get_node("%Camera") as Camera3D
	var mid: Vector2 = camera.unproject_position(Vector3(0.0, RoomSpace.content_dims(p.rooms[0]).y * 0.42, 0.0))
	_check(absf(mid.y - safe.get_center().y) < 2.0 and absf(mid.x - safe.get_center().x) < 2.0,
		"the room's center sits at the band's center (%s vs %s)" % [mid, safe.get_center()])
	var bodies: Array[SpotBody] = room_view.bodies()
	var initial_door: SpotBody = room_view.body("door")
	_check(room_view.recording_gestalt_for(initial_door.spot).id == "lets_go_outside", "untapped door records its first phrase")
	_check(bodies.size() == p.rooms[0].spots.size(), "one body per spot (%d of %d)" % [bodies.size(), p.rooms[0].spots.size()])
	for b: SpotBody in bodies:
		var point: Vector2 = room_view.screen_point(b)
		_check(safe.has_point(point), "%s is inside the band (%s in %s)" % [b.spot.id, point, safe])
		var picked: SpotBody = room_view.pick_at(point)
		_check(picked == b, "%s is picked at its own center (got %s)" % [b.spot.id, picked.spot.id if picked != null else "nothing"])
		_check(safe.encloses(room_view.screen_bounds(b)), "%s bounds fit inside the safe band" % b.spot.id)
	_check(room_view.pick_at(Vector2(2.0, 2.0)) == null, "the top corner picks nothing")

	# First tap: every spot toggles on; the caption follows the latest spoken phrase.
	for b: SpotBody in bodies:
		room_view.tap(b)
	await get_tree().process_frame
	for b: SpotBody in bodies:
		_check(b.is_on, "%s toggled on" % b.spot.id)
	_check(captions.get_child_count() == 1, "only the current phrase has a caption (%d)" % captions.get_child_count())
	var door: SpotBody = room_view.body("door")
	_check(door != null, "the home room has a door")
	if door != null:
		_check(room_view.gestalt_for(door.spot).id == "lets_go_inside", "an open door says the alternate gestalt")
		_check(room_view.recording_gestalt_for(door.spot).id == "lets_go_outside", "hold records the phrase heard before the door opened")
		home._on_spot_held(door.spot, room_view.recording_gestalt_for(door.spot))
		var overlay: RecordOverlay = home.get_node("%RecordOverlay") as RecordOverlay
		var pills: Array[TakePill] = overlay.pills()
		_check(pills.size() == 3 and pills[0].text == "Let's go outside", "the whole pill reads the spoken caption (%d pills)" % pills.size())
		_check(pills[1].text == "Let's go" and pills[2].text == "outside", "one pill per chunk after the whole")
		_check(overlay.selected_pill() == pills[0] and pills[0].whole, "the whole is picked on open")
		_check(overlay.gestalt().id == "lets_go_outside", "Keep targets the displayed phrase")
		overlay.close()
		# The scene's stage picks the pair the open door says, and the bank stays whole.
		var live: Profile = home._profile
		var scene_id: String = live.scene_of(live.rooms[0].id)
		_check(live.set_scene_stage(scene_id, NlaStage.Stage.SINGLE_WORDS), "the scene is staged 3")
		_check(room_view.gestalt_for(door.spot).text == "Come in", "at stage 3 the open door says its stage 3 alternate")
		_check(live.words_gestalts().size() == live.gestalts.size(), "Words still offers the whole bank")
		_check(live.set_scene_stage(scene_id, NlaStage.Stage.EARLY_GRAMMAR), "the scene is staged 4")
		_check(room_view.gestalt_for(door.spot).text == "Shut the door", "at stage 4 the open door says its stage 4 alternate")
		live.set_scene_stage(scene_id, NlaStage.Stage.ECHOLALIA)
		_check(room_view.gestalt_for(door.spot).id == "lets_go_inside", "stage 1 says the first pair again")
	var tub: SpotBody = room_view.body("tub")
	if tub != null:
		var water: Node = tub.get_node_or_null("Object/water")
		_check(water is MeshInstance3D and (water as MeshInstance3D).visible, "a tapped tub shows its water")

	# Tweens run on wall time, and headless frames run fast, so wait by the clock.
	await get_tree().create_timer(3.5).timeout
	await get_tree().process_frame
	_check(captions.get_child_count() == 0, "captions fade out (%d left)" % captions.get_child_count())
	if door != null:
		var leaf: Node = door.get_node_or_null("Object/leaf")
		_check(leaf is MeshInstance3D and absf((leaf as MeshInstance3D).rotation.y - SpotBody.OPEN_RAD) < 0.01, "the door leaf swung open")
		_check(room_view.pick_at(room_view.screen_point(door)) == door, "an open door is still picked")
		var doorway: Vector2 = camera.unproject_position(door.to_global(Vector3(0.0, door.size_m * 0.5, 0.0)))
		_check(room_view.pick_at(doorway) == door, "the empty doorway picks the open door")

	# Second tap toggles back.
	for b: SpotBody in bodies:
		room_view.tap(b)
	await get_tree().process_frame
	for b: SpotBody in bodies:
		_check(not b.is_on, "%s toggled off" % b.spot.id)
	_check(room_view.recording_gestalt_for(door.spot).id == "lets_go_inside", "second tap and hold record the alternate")
	await get_tree().create_timer(1.0).timeout

	# Views: the widget offers Front and Top for `camera: views`, and the camera moves to each.
	p.rooms[0].camera = Room.Camera.VIEWS
	home.show_room(p.rooms[0])
	await get_tree().process_frame
	bodies = room_view.bodies()
	door = room_view.body("door")
	_check(widget.visible, "the view widget shows for a views room")
	var tilt_button: SdfButton = widget.items()[CameraFraming.View.TILT]
	_check(not tilt_button.visible, "tilt is hidden until the room allows it")
	var front_pos: Vector3 = room_view.camera_position()
	room_view.set_view(CameraFraming.View.TOP, false)
	_check(room_view.camera_position().y > front_pos.y + 1.0, "the top view stands above")
	_check(room_view.wall_visible(Spot.Wall.RIGHT) and room_view.wall_visible(Spot.Wall.LEFT), "the side walls show from above")
	for b: SpotBody in bodies:
		# The cup covers the table's center from above. Pick any visible part of each object.
		var bounds: Rect2 = room_view.screen_bounds(b)
		var reachable: bool = false
		for x: int in range(1, 10):
			for y: int in range(1, 10):
				var point: Vector2 = bounds.position + bounds.size * Vector2(x / 10.0, y / 10.0)
				reachable = reachable or room_view.pick_at(point) == b
		_check(reachable, "%s has a reachable surface from above" % b.spot.id)

	# Pan and zoom: nothing moves at the fit, a pinch closes in to its limit, and a drag then stays inside it.
	room_view.set_view(CameraFraming.View.FRONT, false)
	var mid_px: Vector2 = safe.get_center()
	room_view.pan_by(Vector2(500.0, 300.0))
	_check(room_view.pan() == Vector2.ZERO and not room_view.is_moved(), "no pan at the fit")
	room_view.zoom_by(100.0, mid_px)
	_check(absf(room_view.zoom() - CameraFraming.ZOOM_MAX) < 0.0001, "zoom stops at its limit")
	_check(room_view.is_moved(), "a zoomed front is a moved view")
	room_view.pan_by(Vector2(-100000.0, 100000.0))
	var visible: Vector2 = Vector2(room_view.size.x / room_view.size.y, 1.0) * room_view.frame_extent() / room_view.zoom()
	var silhouette: Rect2 = room_view.room_silhouette()
	var clamped: Vector2 = CameraFraming.clamp_pan(room_view.pan(), visible, silhouette)
	_check(room_view.pan().is_equal_approx(clamped) and room_view.pan() != Vector2.ZERO, "a pan stops inside the room (%s)" % room_view.pan())
	_check(room_view.pan().x + visible.x / 2.0 <= silhouette.end.x + 0.0001, "the frame's edge stops at the wall")
	_check(not room_view.enclosure_visible(), "the front wall and ceiling are out of the way from the front")
	for b: SpotBody in bodies:
		_check(room_view.pick_at(room_view.screen_point(b)) == b or room_view.camera_position().distance_to(b.center_point()) > 0.0, "%s is still picked where it shows" % b.spot.id)

	# The press rule: movement past the threshold cancels the hold and moves the view from wherever it began,
	# an object included, and the release is not a tap.
	var holds: Array[Spot] = []
	room_view.spot_held.connect(func(s: Spot, _g: Gestalt) -> void: holds.push_back(s))
	room_view.set_view(CameraFraming.View.FRONT, false)
	room_view.zoom_by(CameraFraming.ZOOM_MAX, mid_px)
	var pan_before: Vector2 = room_view.pan()
	var door_px: Vector2 = room_view.screen_point(door)
	var was_on: bool = door.is_on
	room_view._gui_input(_mouse(door_px, true))
	room_view._gui_input(_motion(door_px + Vector2(60.0, 40.0), Vector2(60.0, 40.0)))
	room_view._process(RoomView.HOLD_SECONDS + 0.1)
	room_view._gui_input(_mouse(door_px + Vector2(60.0, 40.0), false))
	_check(room_view.pan() != pan_before, "a drag that began on an object moves the view")
	_check(door.is_on == was_on, "a drag is not a tap")
	_check(holds.is_empty(), "a drag is not a hold")
	room_view._gui_input(_mouse(door_px, true))
	room_view._process(RoomView.HOLD_SECONDS + 0.1)
	_check(holds.size() == 1 and holds[0] == door.spot, "a still press is a hold")
	(home.get_node("%RecordOverlay") as RecordOverlay).close()

	# A tap on the current view's pill resets it.
	var front_button: SdfButton = widget.items()[CameraFraming.View.FRONT]
	_check(front_button.button_pressed, "front is the pressed pill")
	var pill_px: Vector2 = front_button.get_global_rect().get_center()
	get_viewport().push_input(_mouse(pill_px, true))
	get_viewport().push_input(_mouse(pill_px, false))
	# The reset is a tween on wall time.
	await get_tree().create_timer(1.0).timeout
	await get_tree().process_frame
	_check(not room_view.is_moved(), "a tap on the current pill resets the view (zoom %s, pan %s)" % [room_view.zoom(), room_view.pan()])

	# Tilt: the camera stands at the room's center, every wall stays, a drag turns within the pitch limits,
	# a pinch narrows the view, and the view idles back to the front.
	p.rooms[0].camera = Room.Camera.TILT
	home.show_room(p.rooms[0])
	await get_tree().process_frame
	_check(tilt_button.visible, "tilt shows for a tilt room")
	room_view.set_view(CameraFraming.View.TILT, false)
	var origin: Vector3 = RoomSpace.tilt_origin(p.rooms[0])
	_check(room_view.camera_position().is_equal_approx(origin), "tilt stands at the room's center (%s)" % room_view.camera_position())
	_check(origin.y > 0.5 and origin.y < RoomSpace.HEIGHT, "tilt stands at eye height")
	room_view.pan_by(Vector2(0.0, -100000.0))
	_check(absf(room_view.tilt_angles().y - CameraFraming.TILT_PITCH_MIN_DEG) < 0.001, "tilt stops looking down at its limit")
	room_view.pan_by(Vector2(100000.0, 100000.0))
	_check(absf(room_view.tilt_angles().y - CameraFraming.TILT_PITCH_MAX_DEG) < 0.001, "tilt stops looking up at its limit")
	_check(absf(room_view.tilt_angles().x) <= 180.0, "yaw wraps")
	room_view.zoom_by(100.0, mid_px)
	_check(absf(room_view.tilt_zoom() - CameraFraming.TILT_ZOOM_MAX) < 0.001, "tilt zoom stops at its limit")
	for wall: Spot.Wall in [Spot.Wall.BACK, Spot.Wall.LEFT, Spot.Wall.RIGHT]:
		_check(room_view.wall_visible(wall), "wall %d stays in tilt" % wall)
	_check(room_view.enclosure_visible(), "the front wall and ceiling close the box in tilt")
	room_view.idle_seconds = 0.3
	await get_tree().create_timer(1.0).timeout
	await get_tree().process_frame
	_check(room_view.view() == CameraFraming.View.FRONT, "an idle view returns to the front")

	home.mode_button(ChildHome.Mode.WORDS).pressed.emit()
	await get_tree().process_frame
	var grid: HFlowContainer = home.get_node("%Board") as HFlowContainer
	_check(grid.visible and not room_view.visible, "Words replaces the room")
	_check(grid.get_child_count() == p.words_gestalts().size(), "one tile per Words gestalt (%d)" % grid.get_child_count())
	_check(home.mode_button(ChildHome.Mode.WORDS).button_pressed and not home.mode_button(ChildHome.Mode.EXPLORE).button_pressed, "Words is the pressed pill")
	home.mode_button(ChildHome.Mode.EXPLORE).pressed.emit()
	await get_tree().process_frame
	_check(room_view.visible and not grid.visible, "Explore brings the room back")
	_check(home.mode_button(ChildHome.Mode.EXPLORE).button_pressed, "Explore is the pressed pill again")
	await _check_chunks(home, room_view)
	await _check_build(home, p)
	await _check_takes(home)
	home.show_words()
	await get_tree().process_frame

	await _check_name(home, p)
	await _check_cleanup(home, p)
	await _check_caregiver_chord(main, p)
	_finish(repo, p.id)

func _mouse(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	return event

func _motion(at: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event

## Each caregiver chord opens the picker after its hold, and cancels a record hold under the pointer. Two
## fingers do nothing. The bar shows after a moment and clears the fingers. A hand that moves hides it and
## starts the count again. Opening a profile remembers it for the next launch.
func _check_caregiver_chord(main: Main, p: Profile) -> void:
	var picker: ProfilePicker = main.get_node("%ProfilePicker") as ProfilePicker
	var wait: float = CaregiverChord.HOLD_SECONDS + 0.4
	main.open_profile(p.id)
	await get_tree().process_frame
	_check(ProfileStore.last_id() == p.id, "opening a profile remembers it")
	var home: ChildHome = main.get_node("%ChildHome") as ChildHome
	var room_view: RoomView = home.get_node("%RoomView") as RoomView
	home.show_room(p.rooms[0])
	await get_tree().process_frame
	var overlay: RecordOverlay = home.get_node("%RecordOverlay") as RecordOverlay
	var door: Vector2 = room_view.get_global_transform_with_canvas() * room_view.screen_point(room_view.body("door"))

	get_viewport().push_input(_mouse(door, true))
	var right: InputEventMouseButton = _mouse(door, true)
	right.button_index = MOUSE_BUTTON_RIGHT
	get_viewport().push_input(right)
	# Past the record hold, short of the chord.
	await get_tree().create_timer(RoomView.HOLD_SECONDS + 0.4).timeout
	_check(home.visible and not overlay.visible, "the chord cancels the record hold under the left button")
	await get_tree().create_timer(wait - RoomView.HOLD_SECONDS - 0.4).timeout
	await get_tree().process_frame
	_check(picker.visible and not home.visible, "left and right held together open the picker")
	get_viewport().push_input(_mouse(door, false))
	right.pressed = false
	get_viewport().push_input(right)

	for fingers: int in [2, 3]:
		main.open_profile(p.id)
		await get_tree().process_frame
		for i: int in fingers:
			get_viewport().push_input(_touch(i, door + Vector2(60.0 * i, 0.0), true))
		await get_tree().create_timer(wait).timeout
		await get_tree().process_frame
		if fingers == 2:
			_check(home.visible, "two fingers held stay on the learner's screen")
		else:
			_check(picker.visible and not home.visible, "three fingers held open the picker")
		for i: int in fingers:
			get_viewport().push_input(_touch(i, door + Vector2(60.0 * i, 0.0), false))

	main.open_profile(p.id)
	await get_tree().process_frame
	var bar: ChordProgress = (main.get_node("CaregiverGate") as CaregiverGate).bar()
	var fingers_at: Array[Vector2] = []
	for i: int in 3:
		fingers_at.push_back(door + Vector2(60.0 * i, 0.0))
		get_viewport().push_input(_touch(i, fingers_at[i], true))
	await get_tree().process_frame
	_check(not bar.visible, "a brief three-finger touch shows no bar")
	await get_tree().create_timer(CaregiverChord.SHOW_AFTER + 0.3).timeout
	var hand: Rect2 = Rect2(door, Vector2(120.0, 0.0)).grow(40.0)
	_check(bar.visible and bar.fraction() > 0.0, "a held chord shows its bar filling (%.2f)" % bar.fraction())
	_check(not Rect2(bar.global_position, ChordProgress.BAR_SIZE).intersects(hand), "the bar clears the fingers")
	var shift: Vector2 = Vector2(0.0, CaregiverChord.STILL_PX * 1.5)
	for i: int in 3:
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.index = i
		drag.position = fingers_at[i] + shift
		get_viewport().push_input(drag)
	# process_frame fires before the gate's _process, so the second one follows a pass that read the drag.
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not bar.visible, "a hand that moves hides the bar")
	await get_tree().create_timer(CaregiverChord.HOLD_SECONDS - 0.4).timeout
	_check(home.visible, "a hand that moves starts the count again")
	await get_tree().create_timer(0.8).timeout
	await get_tree().process_frame
	_check(picker.visible and not home.visible and not bar.visible, "and opens the picker once still for the hold")
	for i: int in 3:
		get_viewport().push_input(_touch(i, fingers_at[i] + shift, false))
	main.open_profile(p.id)
	await get_tree().process_frame

	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape)
	await get_tree().create_timer(wait).timeout
	await get_tree().process_frame
	_check(picker.visible and not home.visible, "Escape held opens the picker")
	escape.pressed = false
	get_viewport().push_input(escape)
	_check(ProfileStore.last_id() == p.id, "the picker keeps the profile remembered")

func _touch(index: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	return event

## A chunk is the same color in the caption and on a tile. The spoken chunk grows at full motion and
## brightens, at its own size, at motion NONE.
func _check_chunks(home: ChildHome, room_view: RoomView) -> void:
	var door: SpotBody = room_view.body("door")
	room_view.tap(door)
	await get_tree().create_timer(0.2).timeout
	var caption: ChunkRow = room_view.caption_row()
	_check(caption != null, "the door's caption is a chunk row")
	if caption == null:
		return
	var caption_pills: Array[ChunkRow.Pill] = caption.pills()
	_check(caption_pills.size() == 2 and caption_pills[0].text == "Let's go", "the caption holds the door's chunks")
	_check(caption.get_parent().get_child_count() == 1 and caption_pills[0].relief() < 0.0, "the caption is bare pills with the style's relief")
	for pill: ChunkRow.Pill in caption_pills:
		_check(pill.color() == ChunkColors.color_for(pill.text, Style.current.chunk_palette), "caption '%s' takes its text's color" % pill.text)
		_check(pill.fill() == pill.color(), "caption '%s' keeps its color at full motion" % pill.text)
	_check(caption_pills[0].is_spoken() and caption_pills[0].body_scale().x > 1.01, "the spoken chunk grows (%s)" % caption_pills[0].body_scale())
	_check(not caption_pills[1].is_spoken() and caption_pills[1].body_scale().is_equal_approx(Vector2.ONE), "the next chunk waits at rest")

	home.show_words()
	await get_tree().process_frame
	var tile: GestaltTile = home._tiles.get("lets_go_in_the_car", null)
	_check(tile != null, "the car tile is in Words")
	if tile == null:
		return
	var tile_pill: ChunkRow.Pill = tile.chunk_row().pills()[0]
	_check(tile_pill.text == "Let's go" and tile_pill.fill() == caption_pills[0].color(), "\"Let's go\" is one color on the caption and the tile")
	_check(tile_pill.relief() == 0.0, "a tile's pills sit flat")

	var previous: StylePreset = Style.current
	Style.apply(StylePreset.load_by_id("quiet"))
	await get_tree().process_frame
	tile = home._tiles.get("lets_go_in_the_car", null)
	tile_pill = tile.chunk_row().pills()[0]
	tile_pill.set_spoken(true)
	_check(tile_pill.fill() == ChunkColors.spoken(tile_pill.color()) and tile_pill.body_scale() == Vector2.ONE, "at motion NONE the spoken chunk brightens and keeps its size")
	tile_pill.set_spoken(false)
	_check(tile_pill.fill() == tile_pill.color(), "at rest it returns to its color")
	Style.apply(previous)
	home.show_explore()
	await get_tree().create_timer(0.3).timeout

## Build: the bank's beginnings and endings as chunk buttons, a strip that fills, says and empties, and a
## built phrase the bank holds speaking as that phrase.
func _check_build(home: ChildHome, p: Profile) -> void:
	home.show_palette()
	await get_tree().process_frame
	_check(home._tiles.size() == p.gestalts.size(), "Palette holds the whole bank (%d of %d)" % [home._tiles.size(), p.gestalts.size()])
	_check(home._tiles.has("lets_go_outside"), "a room's phrase is in Palette")
	var widget: WordsWidget = home.get_node("%WordsWidget") as WordsWidget
	_check(widget.visible, "the Words widget shows in Words")
	var build_button: SdfButton = widget.items()[WordsWidget.Mode.BUILD]
	var pill_px: Vector2 = build_button.get_global_rect().get_center()
	get_viewport().push_input(_mouse(pill_px, true))
	get_viewport().push_input(_mouse(pill_px, false))
	await get_tree().process_frame
	_check(home.words_mode() == WordsWidget.Mode.BUILD and home.build_view().visible, "a tap on Build shows the strip")
	var build: BuildView = home.build_view()
	var beginnings: Array[ChunkButton] = build.beginning_buttons()
	var endings: Array[ChunkButton] = build.ending_buttons()
	_check(beginnings.size() == ChunkBank.beginnings(p.gestalts).size(), "one button per beginning (%d)" % beginnings.size())
	_check(endings.size() == ChunkBank.endings(p.gestalts).size(), "one button per ending (%d)" % endings.size())
	var go: ChunkButton = null
	for button: ChunkButton in beginnings:
		if button.chunk == "Let's go":
			go = button
	var outside: ChunkButton = null
	for button: ChunkButton in endings:
		if button.chunk == "outside":
			outside = button
	_check(go != null and outside != null, "the door's chunks are on offer")
	if go == null or outside == null:
		return
	_check(go.custom_minimum_size.y >= Style.current.tile_min_size, "a chunk button honors the touch floor")
	var go_shape: SdfShape = go.get_node("Shape") as SdfShape
	_check(go_shape != null and go_shape.fill == ChunkColors.color_for("Let's go", Style.current.chunk_palette), "a chunk button wears its chunk's color")
	var begins: Dictionary[String, bool] = {}
	for button: ChunkButton in beginnings:
		begins[ChunkColors.key(button.chunk)] = true
	var empty_leads_right: bool = true
	for button: ChunkButton in beginnings:
		empty_leads_right = empty_leads_right and button.lead
	for button: ChunkButton in endings:
		empty_leads_right = empty_leads_right and button.lead == begins.has(ChunkColors.key(button.chunk))
	_check(empty_leads_right and go.lead and not outside.lead, "an empty strip borders every beginning, and an ending only when it also begins a phrase")
	_check(go_shape != null and go_shape.border_px == ChunkButton.LEAD_BORDER_PX, "the border is the lead mark")
	var speaker: Speaker = home.get_node("%Speaker") as Speaker
	var heard: Array[Gestalt] = []
	speaker.started.connect(func(g: Gestalt, _seconds: float) -> void: heard.push_back(g))
	go.pressed.emit()
	await get_tree().process_frame
	_check(build.chunks() == PackedStringArray(["Let's go"]), "a tapped beginning lands on the strip")
	_check(heard.size() == 1 and heard[0].text == "Let's go", "and is said on its own")
	var after_go: PackedStringArray = ChunkBank.next(p.gestalts, "Let's go")
	_check(build.lead_buttons().size() == after_go.size() and outside.lead and not go.lead, "after a chunk lands, what the bank says next is bordered (%d)" % after_go.size())
	_check(go_shape != null and go_shape.border_px == 0.0, "and the beginning's border is gone")
	outside.pressed.emit()
	await get_tree().process_frame
	_check(build.chunks() == PackedStringArray(["Let's go", "outside"]), "a tapped ending follows it")
	_check(build.strip_row().pills().size() == 2, "the strip shows both pills")
	_check(build.lead_buttons().is_empty(), "a finished phrase borders nothing")
	_tap_strip(build, Vector2(-100.0, -100.0))
	await get_tree().process_frame
	_check(heard.size() == 3 and heard[2].id == "lets_go_outside", "a tap on the strip says the bank's own phrase")
	_tap_strip(build, build.strip_row().pills()[0].get_rect().get_center())
	await get_tree().process_frame
	_check(build.chunks() == PackedStringArray(["outside"]), "a tap on a strip pill takes it off")
	_tap_strip(build, Vector2(-100.0, -100.0))
	await get_tree().process_frame
	_check(heard.size() == 4 and heard[3].id == ChunkBank.BUILD_ID and heard[3].text == "outside", "a strip the bank does not hold is said as itself")
	home.show_explore()
	await get_tree().process_frame
	_check(not widget.visible, "the Words widget hides in Explore")
	home.show_words()
	await get_tree().process_frame
	_check(home.words_mode() == WordsWidget.Mode.BUILD and build.chunks() == PackedStringArray(["outside"]), "Words returns to Build with the strip kept")
	build.clear()
	speaker.stop()
	await get_tree().create_timer(0.2).timeout

## Takes: a whole take and a chunk take recorded through the overlay from a held object, the chunk landing
## under media/chunks/ with the whole-phrase take untouched; the same from a Build chunk; a chunk take voicing
## the strip; a held strip opening on the bank's phrase or on its chunks; and a held remove clearing a take.
func _check_takes(home: ChildHome) -> void:
	var overlay: RecordOverlay = home.get_node("%RecordOverlay") as RecordOverlay
	var speaker: Speaker = home.get_node("%Speaker") as Speaker
	var prof: Profile = home._profile
	var media: String = ProfileStore.media_dir(prof.id)
	var take: AudioStreamWAV = AudioStreamWAV.new()
	take.format = AudioStreamWAV.FORMAT_16_BITS
	take.mix_rate = 16000
	var data: PackedByteArray = PackedByteArray()
	data.resize(16000)
	take.data = data
	home.show_explore()
	await get_tree().process_frame

	# The whole first, as a caregiver does today.
	var g: Gestalt = prof.gestalt("lets_go_outside")
	home._open_recorder(g)
	_check(overlay.visible and overlay.selected_pill() != null and overlay.selected_pill().whole, "the whole is picked on open")
	overlay._take = take
	overlay._on_keep()
	_check(overlay.visible, "Keep leaves the overlay open on the phrase")
	_check(g.recording == "lets_go_outside.wav" and FileAccess.file_exists(media.path_join(g.recording)), "the whole take is saved where it was")
	_check(overlay.pills()[0].recorded and overlay._remove_button.visible, "the whole pill is marked and offers removal")

	# Then one chunk, with the whole left alone.
	var outside_pill: TakePill = overlay.pills()[2]
	outside_pill.pressed.emit()
	_check(overlay.selected_pill() == outside_pill and not outside_pill.recorded and not overlay._remove_button.visible, "a tap picks the chunk")
	overlay._take = take
	overlay._on_keep()
	var relative: String = ChunkTakes.relative_path("outside")
	_check(ChunkTakes.take_for("outside", prof.chunk_takes) == relative, "the chunk take is in the profile by key")
	_check(FileAccess.file_exists(media.path_join(relative)), "the chunk take lands under media/chunks/")
	_check(g.recording == "lets_go_outside.wav" and FileAccess.file_exists(media.path_join(g.recording)), "the whole-phrase take is untouched")
	_check(outside_pill.recorded and overlay._remove_button.visible, "the chunk pill is marked and offers removal")
	var saved: Profile = ProfileStore.load_profile(prof.id)
	_check(ChunkTakes.take_for("outside", saved.chunk_takes) == relative, "the chunk take survives a reload")
	overlay.close()

	# The same from a Build chunk.
	home.show_build()
	await get_tree().process_frame
	var build: BuildView = home.build_view()
	var go: ChunkButton = null
	var outside: ChunkButton = null
	for button: ChunkButton in build.beginning_buttons():
		if button.chunk == "Let's go":
			go = button
	for button: ChunkButton in build.ending_buttons():
		if button.chunk == "outside":
			outside = button
	if go == null or outside == null:
		_check(false, "the door's chunks are on offer in Build")
		return
	go.held.emit()
	var pills: Array[TakePill] = overlay.pills()
	_check(overlay.visible and pills.size() == 1 and not pills[0].whole and pills[0].text == "Let's go", "a held chunk opens on that chunk alone")
	overlay._take = take
	overlay._on_keep()
	_check(FileAccess.file_exists(media.path_join(ChunkTakes.relative_path("Let's go"))), "a chunk take from Build lands under media/chunks/")
	overlay.close()

	# A chunk landing on the strip plays its take; a phrase with one chunk take plays it, then the OS voice.
	go.pressed.emit()
	await get_tree().process_frame
	_check(build.chunks() == PackedStringArray(["Let's go"]) and speaker._player.playing and speaker._player.stream is AudioStreamWAV, "a chunk on the strip plays its take")
	speaker.stop()
	speaker.say(prof.gestalt("lets_go_in_the_car"), media, prof.chunk_takes)
	_check(speaker._player.playing and speaker._queue.size() == 1 and speaker._queue[0] == null, "a phrase with one chunk take plays it, then the rest by the OS voice")
	speaker.stop()

	# A held strip opens on the bank's phrase when it is one, and on its chunks otherwise.
	outside.pressed.emit()
	await get_tree().process_frame
	build._on_strip_held()
	_check(overlay.visible and overlay.gestalt().id == "lets_go_outside" and overlay.pills().size() == 3, "a held strip that is a bank phrase opens on that phrase")
	overlay.close()
	build.clear()
	outside.pressed.emit()
	go.pressed.emit()
	await get_tree().process_frame
	build._on_strip_held()
	_check(overlay.visible and overlay.gestalt().id == ChunkBank.BUILD_ID and overlay.pills().size() == 2 and not overlay.pills()[0].whole, "a held strip the bank does not hold opens on its chunks")
	overlay.close()
	build.clear()
	speaker.stop()

	# A held remove clears the whole take, then a chunk take, and the removal is saved.
	home._open_recorder(g)
	_check(overlay._remove_button.visible, "a recorded pill offers removal")
	overlay._remove_button.held.emit()
	_check(g.recording.is_empty() and not FileAccess.file_exists(media.path_join("lets_go_outside.wav")), "a held remove clears the whole take")
	_check(not overlay._remove_button.visible and not overlay.pills()[0].recorded, "and the pill is unmarked")
	saved = ProfileStore.load_profile(prof.id)
	_check(saved.gestalt("lets_go_outside").recording.is_empty(), "the removal is saved")
	overlay.pills()[2].pressed.emit()
	overlay._remove_button.held.emit()
	_check(not prof.chunk_takes.has("outside") and not FileAccess.file_exists(media.path_join(relative)), "a held remove clears a chunk take")
	overlay.close()
	home.show_explore()
	await get_tree().create_timer(0.2).timeout

## A short press on the strip at `at` in the strip row's coordinates: down, up, then the tap, as a finger
## does, so the strip's hold never counts the press as consumed.
func _tap_strip(build: BuildView, at: Vector2) -> void:
	build._strip.button_down.emit()
	build._strip.button_up.emit()
	build._press_point = at
	build._on_strip_pressed()

## The strip reads Explore then Words, whatever the room and the board are called.
func _check_strip(home: ChildHome, p: Profile) -> void:
	var strip: PillBar = home.get_node("%ModeStrip") as PillBar
	_check(strip.visible, "the strip shows for a profile with a room and words")
	var labels: PackedStringArray = PackedStringArray()
	for button: SdfButton in strip.items():
		labels.push_back(button.text)
	_check(labels == PackedStringArray(["Explore", "Words"]), "the strip reads Explore, Words (%s)" % ", ".join(labels))
	_check(home.mode_button(ChildHome.Mode.EXPLORE).button_pressed, "Explore is pressed on open")
	_check(p.rooms[0].title == _ROOM_TITLE and p.boards[0].title == _BOARD_TITLE, "the room and board keep their titles in the profile")

func _check_name(home: ChildHome, p: Profile) -> void:
	var title: HoldButton = home.get_node("%Title") as HoldButton
	var overlay: RecordOverlay = home.get_node("%RecordOverlay") as RecordOverlay
	var speaker: Speaker = home.get_node("%Speaker") as Speaker
	var heard: Array[Gestalt] = []
	speaker.started.connect(func(g: Gestalt, _seconds: float) -> void: heard.push_back(g))
	title.button_down.emit()
	title.button_up.emit()
	title.pressed.emit()
	_check(heard.size() == 1 and heard[0].text == p.display_name, "tap speaks the name before a recording exists")
	title.button_down.emit()
	title._process(title.hold_seconds)
	title.button_up.emit()
	title.pressed.emit()
	_check(overlay.visible, "holding the name opens the recorder")
	_check(heard.size() == 1, "hold release does not also speak the name")
	overlay.close()
	_check(p.name_recording.is_empty(), "cancel leaves the name unchanged")
	home._on_name_held()
	var take: AudioStreamWAV = AudioStreamWAV.new()
	take.format = AudioStreamWAV.FORMAT_16_BITS
	take.mix_rate = 16000
	var data: PackedByteArray = PackedByteArray()
	data.resize(16000)
	take.data = data
	overlay._take = take
	overlay._on_keep()
	var saved: Profile = ProfileStore.load_profile(p.id)
	_check(saved.name_recording == "name/name.wav", "name recording survives profile reload")
	_check(FileAccess.file_exists(ProfileStore.media_dir(p.id).path_join(saved.name_recording)), "name audio saved in its own directory")
	home.show_profile(saved)
	title.button_down.emit()
	title.button_up.emit()
	title.pressed.emit()
	_check(speaker._player.playing and speaker._player.stream is AudioStreamWAV, "name tap plays the saved WAV")
	home._on_name_held()
	overlay._take = take
	overlay._on_keep()
	_check(FileAccess.file_exists(ProfileStore.media_dir(p.id).path_join("name/name.prev.wav")), "previous name take retained")
	speaker.stop()
	speaker._player.stream = null
	await get_tree().create_timer(0.1).timeout

func _check_cleanup(home: ChildHome, p: Profile) -> void:
	var overlay: RecordOverlay = home.get_node("%RecordOverlay") as RecordOverlay
	var take: AudioStreamWAV = AudioStreamWAV.new()
	take.format = AudioStreamWAV.FORMAT_16_BITS
	take.mix_rate = 16000
	var data: PackedByteArray = PackedByteArray()
	data.resize(32000)
	for i: int in 16000:
		data.encode_s16(i * 2, int(5000.0 * sin(TAU * 700.0 * i / 16000.0)))
	take.data = data
	overlay.open(p.name_gestalt(), p, true)
	overlay._clean_take(take)
	overlay.close()
	overlay.open(p.gestalts[0], p)
	while overlay._cleanup_thread != null:
		await get_tree().process_frame
	_check(overlay._take == null and not overlay._preview.playing, "cancelled cleanup cannot preview in a reopened recorder")
	overlay._clean_take(take)
	while overlay._cleanup_thread != null:
		await get_tree().process_frame
	_check(overlay._take != null and overlay._preview.stream == overlay._take, "preview uses the cleaned worker result")
	_check(overlay._take != take, "raw capture is not used as the saved take")
	overlay.close()
	overlay._preview.stream = null
	await get_tree().create_timer(0.1).timeout

func _finish(repo: ProfileRepo, profile_id: String) -> void:
	if not profile_id.is_empty():
		repo.delete_profile(profile_id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(repo.root))
	if _failures.is_empty():
		print("ROOM-PROBE PASS")
		get_tree().quit(0)
	else:
		print("ROOM-PROBE FAIL (%d)" % _failures.size())
		get_tree().quit(1)

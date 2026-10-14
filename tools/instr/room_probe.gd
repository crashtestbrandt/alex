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
		_check((overlay.get_node("%Phrase") as Label).text == "Let's go outside", "recording prompt matches the spoken caption")
		_check(overlay._gestalt.id == "lets_go_outside", "Keep targets the displayed phrase")
		overlay.close()
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

	# Second tap toggles back.
	for b: SpotBody in bodies:
		room_view.tap(b)
	await get_tree().process_frame
	for b: SpotBody in bodies:
		_check(not b.is_on, "%s toggled off" % b.spot.id)
	_check(room_view.recording_gestalt_for(door.spot).id == "lets_go_inside", "second tap and hold record the alternate")
	await get_tree().create_timer(1.0).timeout

	# Views: the widget offers front, side and top for `camera: views`, and the camera moves to each.
	_check(widget.visible, "the view widget shows for a views room")
	var turn: SdfButton = widget.items()[CameraFraming.View.TURN]
	_check(not turn.visible, "turn is hidden until the room allows an orbit")
	var front_pos: Vector3 = room_view.camera_position()
	room_view.set_view(CameraFraming.View.SIDE, false)
	_check(room_view.camera_position().x > front_pos.x + 1.0, "the side view stands to the right")
	_check(not room_view.wall_visible(Spot.Wall.RIGHT), "the right wall hides in the side view")
	_check(room_view.wall_visible(Spot.Wall.LEFT) and room_view.wall_visible(Spot.Wall.BACK), "the other walls stay")
	room_view.set_view(CameraFraming.View.TOP, false)
	_check(room_view.camera_position().y > front_pos.y + 1.0, "the top view stands above")
	_check(room_view.wall_visible(Spot.Wall.RIGHT), "the right wall shows again")
	for b: SpotBody in bodies:
		# The cup covers the table's center from above. Pick any visible part of each object.
		var bounds: Rect2 = room_view.screen_bounds(b)
		var reachable: bool = false
		for x: int in range(1, 10):
			for y: int in range(1, 10):
				var point: Vector2 = bounds.position + bounds.size * Vector2(x / 10.0, y / 10.0)
				reachable = reachable or room_view.pick_at(point) == b
		_check(reachable, "%s has a reachable surface from above" % b.spot.id)

	# Orbit: a drag past the limits stays inside them, and the view idles back to the front.
	p.rooms[0].camera = Room.Camera.ORBIT
	home.show_room(p.rooms[0])
	await get_tree().process_frame
	_check(turn.visible, "turn shows for an orbit room")
	room_view.orbit_by(Vector2(-100000.0, 100000.0))
	var far: Vector3 = room_view.camera_position()
	_check(room_view.view() == CameraFraming.View.TURN, "a drag puts the view in turn")
	_check(far.y < RoomSpace.HEIGHT / 2.0 + 20.0 and far.x > 0.0, "the orbit stops at its limits (%s)" % far)
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
	home.show_words()
	await get_tree().process_frame

	await _check_name(home, p)
	await _check_cleanup(home, p)
	_finish(repo, p.id)

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

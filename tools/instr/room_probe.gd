extends Control
## Room probe: seed a profile from the home starter, open it in the real main scene, pick every spot through
## its own screen point, tap it twice, move the camera through every view, turn it past its limits, let it
## idle back to the front, and switch to the board. Runs headless (`just room-probe`); it needs the live scene
## tree, which is why it is a probe and not a unit suite (docs/gates.md). Prints ROOM-PROBE PASS or FAIL
## and exits with the matching code. The profile it makes is deleted on the way out.
##
## The root is a Control so the window's theme reaches the home screen.

const _MAIN: PackedScene = preload("res://scenes/main.tscn")

var _failures: PackedStringArray = PackedStringArray()

func _ready() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures.push_back(label)
		print("  FAIL %s" % label)

func _run() -> void:
	var repo: ProfileRepo = ProfileRepo.new("user://profiles")
	var starter: Starter = Starter.find("home_routines")
	var p: Profile = repo.create_profile("Probe", starter, "bold")
	_check(p != null, "profile created")
	if p == null:
		_finish(repo, "")
		return
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

	var bodies: Array[SpotBody] = room_view.bodies()
	_check(bodies.size() == p.rooms[0].spots.size(), "one body per spot (%d of %d)" % [bodies.size(), p.rooms[0].spots.size()])
	var floor_px: float = float(Style.current.tile_min_size)
	for b: SpotBody in bodies:
		var point: Vector2 = room_view.screen_point(b)
		_check(point.x >= 0.0 and point.y >= 0.0 and point.x <= room_view.size.x and point.y <= room_view.size.y,
			"%s is on screen (%s in %s)" % [b.spot.id, point, room_view.size])
		var picked: SpotBody = room_view.pick_at(point)
		_check(picked == b, "%s is picked at its own center (got %s)" % [b.spot.id, picked.spot.id if picked != null else "nothing"])
		var extent: Vector2 = room_view.screen_size(b)
		var px: float = maxf(extent.x, extent.y)
		_check(px >= floor_px * 0.5, "%s projects near the touch floor (%.0f px of %.0f)" % [b.spot.id, px, floor_px])
	_check(room_view.pick_at(Vector2(2.0, 2.0)) == null, "the top corner picks nothing")

	# First tap: every spot toggles on, and a caption row appears for each spot.
	for b: SpotBody in bodies:
		room_view.tap(b)
	await get_tree().process_frame
	for b: SpotBody in bodies:
		_check(b.is_on, "%s toggled on" % b.spot.id)
	_check(captions.get_child_count() == bodies.size(), "one caption row per tapped spot (%d)" % captions.get_child_count())
	var door: SpotBody = room_view.body("door")
	_check(door != null, "the home room has a door")
	if door != null:
		_check(room_view.gestalt_for(door.spot).id == "lets_go_inside", "an open door says the alternate gestalt")
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
		var point: Vector2 = room_view.screen_point(b)
		_check(room_view.pick_at(point) == b, "%s is picked from above" % b.spot.id)

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

	home.show_board(p.boards[0])
	await get_tree().process_frame
	var grid: GridContainer = home.get_node("%Board") as GridContainer
	_check(grid.visible and not room_view.visible, "the board replaces the room")
	_check(grid.get_child_count() == p.boards[0].gestalt_ids.size(), "one tile per board gestalt (%d)" % grid.get_child_count())

	_finish(repo, p.id)

func _finish(repo: ProfileRepo, profile_id: String) -> void:
	if not profile_id.is_empty():
		repo.delete_profile(profile_id)
	if _failures.is_empty():
		print("ROOM-PROBE PASS")
		get_tree().quit(0)
	else:
		print("ROOM-PROBE FAIL (%d)" % _failures.size())
		get_tree().quit(1)

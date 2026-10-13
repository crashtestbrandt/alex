extends Node
## Room probe: seed a profile from the home starter, open it in the real main scene, tap every spot twice,
## switch to the board, and check what the screen holds. Runs headless (`just room-probe`); needs the live
## scene tree, which is why it is a probe and not a unit suite (docs/gates.md). Prints ROOM-PROBE PASS or
## FAIL and exits with the matching code. The profile it makes is deleted on the way out.

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
	_check(home.visible, "home is shown after open_profile")
	_check(room_view.visible, "the room is the first screen")

	var views: Array[SpotView] = []
	for child: Node in room_view.get_children():
		if child is SpotView:
			views.push_back(child as SpotView)
	_check(views.size() == p.rooms[0].spots.size(), "one view per spot (%d of %d)" % [views.size(), p.rooms[0].spots.size()])
	for view: SpotView in views:
		_check(view.size.x >= RoomView.MIN_SPOT_PX, "%s is a touch target (%s)" % [view.spot.id, view.size])
		_check(view.position.x >= 0.0 and view.position.y >= 0.0, "%s is on screen (%s)" % [view.spot.id, view.position])
		_check(view.position.x + view.size.x <= room_view.size.x + 0.5 and view.position.y + view.size.y <= room_view.size.y + 0.5,
			"%s fits inside the room (%s + %s in %s)" % [view.spot.id, view.position, view.size, room_view.size])

	# First tap: every spot toggles on, and a caption row appears for each multi-chunk gestalt.
	for view: SpotView in views:
		view.tapped.emit(view.spot)
	await get_tree().process_frame
	for view: SpotView in views:
		_check(view.is_on, "%s toggled on" % view.spot.id)
	_check(captions.get_child_count() == views.size(), "one caption row per tapped spot (%d)" % captions.get_child_count())

	var door: SpotView = null
	for view: SpotView in views:
		if view.spot.id == "door":
			door = view
	_check(door != null, "the home room has a door")
	if door != null:
		_check(room_view.gestalt_for(door.spot).id == "lets_go_inside", "an open door says the alternate gestalt")

	# Tweens run on wall time, and headless frames run fast, so wait by the clock.
	await get_tree().create_timer(3.5).timeout
	await get_tree().process_frame
	_check(captions.get_child_count() == 0, "captions fade out (%d left)" % captions.get_child_count())

	# Second tap toggles back.
	for view: SpotView in views:
		view.tapped.emit(view.spot)
	await get_tree().process_frame
	for view: SpotView in views:
		_check(not view.is_on, "%s toggled off" % view.spot.id)
	await get_tree().create_timer(1.0).timeout

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

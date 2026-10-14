extends Control
## Screenshot: seed a profile from the home starter, open its room, swing the door and light the lamp, and
## save the viewport to docs/img/room.png (`just screenshot`). Windowed, because it needs a renderer. The
## profile it makes is deleted on the way out. Re-run it whenever the room changes so the README stays true.
##
## The root is a Control, not a Node: a theme set on the window propagates only through Control and Window
## nodes, so a plain Node here would leave the top bar on Godot's default theme.

const _MAIN: PackedScene = preload("res://scenes/main.tscn")
const _OUT: String = "res://docs/img/room.png"
const _TAPPED: PackedStringArray = ["door", "light"]

func _ready() -> void:
	_run()

func _run() -> void:
	var repo: ProfileRepo = ProfileRepo.new("user://profiles")
	var p: Profile = repo.create_profile("Sam", Starter.find("home_routines"), "calm")
	var main: Main = _MAIN.instantiate() as Main
	add_child(main)
	await get_tree().process_frame
	main.open_profile(p.id)
	await get_tree().process_frame
	await get_tree().process_frame
	var home: ChildHome = main.get_node("%ChildHome") as ChildHome
	var room_view: RoomView = home.get_node("%RoomView") as RoomView
	await get_tree().create_timer(0.3).timeout
	for id: String in _TAPPED:
		var body: SpotBody = room_view.body(id)
		if body != null:
			room_view.tap(body)
	# Mid-utterance: the door has finished swinging and the first chunk is lit.
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(_OUT)
	repo.delete_profile(p.id)
	if err == OK:
		print("SCREENSHOT %s %dx%d" % [_OUT, image.get_width(), image.get_height()])
		get_tree().quit(0)
	else:
		print("SCREENSHOT FAIL %s" % error_string(err))
		get_tree().quit(1)

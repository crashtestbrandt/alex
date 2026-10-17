extends Control
## Screenshots: seed a profile from the home starter in the Bold style, open its room, swing the door, and
## save the viewport to docs/img/room.png; then open the recording overlay for the door's phrase and save
## docs/img/record.png; then return to the picker and save docs/img/picker.png (`just screenshot`). Windowed, because it needs a renderer. The
## profile it makes lives in an isolated repository and is deleted on the way out. Re-run it whenever the room changes so the README stays true.
##
## The root is a Control, not a Node: a theme set on the window propagates only through Control and Window
## nodes, so a plain Node here would leave the top bar on Godot's default theme.

const _MAIN: PackedScene = preload("res://scenes/main.tscn")
const _OUT: String = "res://docs/img/room.png"
const _OUT_RECORD: String = "res://docs/img/record.png"
const _OUT_PICKER: String = "res://docs/img/picker.png"
const _STYLE: String = "bold"
const _TAPPED: PackedStringArray = ["door"]

func _ready() -> void:
	_run()

func _run() -> void:
	get_window().size = Vector2i(1280, 800)
	var repo: ProfileRepo = ProfileRepo.new("user://screenshot_probe_%s" % OS.get_process_id())
	ProfileStore.repo = repo
	var p: Profile = repo.create_profile("Sam", Starter.find("home_routines"), _STYLE)
	# The window opens under the real cursor, which would hover a button into its bordered state.
	Input.warp_mouse(Vector2(4.0, 4.0))
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
	# Mid-utterance: the door has finished swinging and the first chunk is marked.
	await get_tree().create_timer(0.6).timeout
	RenderingServer.force_draw()
	var err: Error = _save(_OUT)
	if err == OK:
		await get_tree().create_timer(2.5).timeout
		var overlay: RecordOverlay = home.get_node("%RecordOverlay") as RecordOverlay
		overlay.open(p.gestalt("lets_go_outside"), p)
		await get_tree().create_timer(0.3).timeout
		RenderingServer.force_draw()
		err = _save(_OUT_RECORD)
		overlay.close()
	if err == OK:
		main.show_picker()
		Style.apply(StylePreset.load_by_id("calm"))
		await get_tree().create_timer(0.3).timeout
		RenderingServer.force_draw()
		err = _save(_OUT_PICKER)
	repo.delete_profile(p.id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(repo.root))
	if err == OK:
		get_tree().quit(0)
	else:
		print("SCREENSHOT FAIL %s" % error_string(err))
		get_tree().quit(1)

func _save(path: String) -> Error:
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(path)
	if err == OK:
		print("SCREENSHOT %s %dx%d" % [path, image.get_width(), image.get_height()])
	return err

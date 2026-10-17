extends Control
## Store graphics (`just store-graphics`).
##
## store/play/, for Google Play:
##
## - icon-512.png: the app icon at 512 px, 32-bit PNG.
## - feature-1024x500.png: the icon centered on its own background color.
## - screenshot-*.png: 1920x1080. Play takes 16:9 for phones, 7-inch and 10-inch tablets and Chromebooks.
##
## store/app-store/, for the App Store, with no alpha channel as Apple requires:
##
## - iphone/screenshot-*.png: 2556x1179, the iPhone size App Store Connect requires.
## - ipad/screenshot-*.png: 2752x2064, the 13-inch iPad size it requires.
##
## Windowed, because it needs a renderer. Each set resizes the window in pixels, and a capture of any other size
## fails. The profiles it makes live in an isolated repository and are deleted on the way out. Re-run it
## whenever the screens change.
##
## The root is a Control, not a Node: a theme set on the window propagates only through Control and Window
## nodes, so a plain Node here would leave the top bar on Godot's default theme.

const _MAIN: PackedScene = preload("res://scenes/main.tscn")
const _ICON: String = "res://assets/brand/icon.png"
const _PLAY_DIR: String = "res://store/play"
const _SHOT_DIRS: PackedStringArray = ["res://store/play", "res://store/app-store/iphone", "res://store/app-store/ipad"]
const _SHOT_SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2556, 1179), Vector2i(2752, 2064)]
const _ICON_SIZE: int = 512
const _FEATURE_SIZE: Vector2i = Vector2i(1024, 500)

var _out_dir: String = _PLAY_DIR
var _shot_size: Vector2i = Vector2i.ZERO

func _ready() -> void:
	_run()

func _run() -> void:
	var err: Error = _graphics()
	if err == OK:
		err = await _screenshots()
	if err == OK:
		get_tree().quit(0)
	else:
		print("STORE FAIL %s" % error_string(err))
		get_tree().quit(1)

func _graphics() -> Error:
	var icon: Image = Image.load_from_file(ProjectSettings.globalize_path(_ICON))
	if icon == null:
		return ERR_FILE_CANT_READ
	icon.convert(Image.FORMAT_RGBA8)
	var small: Image = icon.duplicate() as Image
	small.resize(_ICON_SIZE, _ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var err: Error = _save_image(small, "icon-512.png")
	if err != OK:
		return err
	# The icon's corner is its background, so the feature graphic's edges continue it.
	var feature: Image = Image.create_empty(_FEATURE_SIZE.x, _FEATURE_SIZE.y, false, Image.FORMAT_RGBA8)
	feature.fill(icon.get_pixel(8, 8))
	var mark: Image = icon.duplicate() as Image
	mark.resize(_FEATURE_SIZE.y, _FEATURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	feature.blit_rect(mark, Rect2i(Vector2i.ZERO, mark.get_size()),
		Vector2i((_FEATURE_SIZE.x - _FEATURE_SIZE.y) / 2, 0))
	feature.convert(Image.FORMAT_RGB8)
	return _save_image(feature, "feature-1024x500.png")

func _screenshots() -> Error:
	var repo: ProfileRepo = ProfileRepo.new("user://store_probe_%s" % OS.get_process_id())
	ProfileStore.repo = repo
	var home_profile: Profile = repo.create_profile("Sam", Starter.find("home_routines"), "bold")
	var bath_profile: Profile = repo.create_profile("Sam", Starter.find("bath_time"), "calm")
	var err: Error = OK
	for i: int in _SHOT_DIRS.size():
		_out_dir = _SHOT_DIRS[i]
		_shot_size = _SHOT_SIZES[i]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
		# macOS fits a titled window to the screen. A borderless one keeps the size, so the 13-inch iPad set
		# renders on a shorter display.
		get_window().borderless = true
		get_window().position = Vector2i.ZERO
		get_window().size = _shot_size
		# The window opens under the real cursor, which would hover a button into its bordered state.
		Input.warp_mouse(Vector2(4.0, 4.0))
		var main: Main = _MAIN.instantiate() as Main
		add_child(main)
		await get_tree().create_timer(0.3).timeout
		err = await _home_shots(main, home_profile)
		if err == OK:
			err = await _bath_shot(main, bath_profile)
		main.queue_free()
		await get_tree().process_frame
		if err != OK:
			break
	repo.delete_profile(home_profile.id)
	repo.delete_profile(bath_profile.id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(repo.root))
	return err

func _home_shots(main: Main, p: Profile) -> Error:
	main.open_profile(p.id)
	var home: ChildHome = main.get_node("%ChildHome") as ChildHome
	var room_view: RoomView = home.get_node("%RoomView") as RoomView
	await get_tree().create_timer(0.3).timeout
	var door: SpotBody = room_view.body("door")
	if door != null:
		room_view.tap(door)
	# Mid-utterance: the door has finished swinging and the first chunk is marked.
	await get_tree().create_timer(0.6).timeout
	var err: Error = _shoot("screenshot-1-explore.png")
	if err != OK:
		return err
	await get_tree().create_timer(2.5).timeout

	home.show_palette()
	await get_tree().create_timer(0.3).timeout
	var board: Node = home.get_node("%Board")
	if board.get_child_count() > 0:
		var tile: GestaltTile = board.get_child(0) as GestaltTile
		tile.tapped.emit(tile.gestalt)
	await get_tree().create_timer(0.6).timeout
	err = _shoot("screenshot-2-words.png")
	if err != OK:
		return err
	await get_tree().create_timer(2.5).timeout

	home.show_build()
	await get_tree().create_timer(0.3).timeout
	var build: BuildView = home.build_view()
	build.add_chunk("Let's go")
	build.add_chunk("outside")
	await get_tree().create_timer(2.0).timeout
	build.play(2.0)
	await get_tree().create_timer(0.6).timeout
	err = _shoot("screenshot-3-build.png")
	if err != OK:
		return err
	await get_tree().create_timer(2.5).timeout

	home.show_explore()
	await get_tree().create_timer(0.3).timeout
	var overlay: RecordOverlay = home.get_node("%RecordOverlay") as RecordOverlay
	overlay.open(p.gestalt("lets_go_outside"), p)
	await get_tree().create_timer(0.3).timeout
	err = _shoot("screenshot-4-record.png")
	overlay.close()
	return err

func _bath_shot(main: Main, p: Profile) -> Error:
	main.open_profile(p.id)
	var home: ChildHome = main.get_node("%ChildHome") as ChildHome
	var room_view: RoomView = home.get_node("%RoomView") as RoomView
	await get_tree().create_timer(0.3).timeout
	var tub: SpotBody = room_view.body("tub")
	if tub != null:
		room_view.tap(tub)
	await get_tree().create_timer(0.8).timeout
	var err: Error = _shoot("screenshot-5-bath.png")
	await get_tree().create_timer(2.5).timeout
	return err

func _shoot(file: String) -> Error:
	RenderingServer.force_draw()
	var image: Image = get_viewport().get_texture().get_image()
	if image.get_size() != _shot_size:
		print("STORE %s is %dx%d, not %dx%d. The screen is too small for the window." % [file,
			image.get_width(), image.get_height(), _shot_size.x, _shot_size.y])
		return ERR_INVALID_DATA
	# The App Store refuses a screenshot with an alpha channel.
	image.convert(Image.FORMAT_RGB8)
	return _save_image(image, file)

func _save_image(image: Image, file: String) -> Error:
	var path: String = "%s/%s" % [_out_dir, file]
	var err: Error = image.save_png(path)
	if err == OK:
		print("STORE %s %dx%d" % [path, image.get_width(), image.get_height()])
	return err

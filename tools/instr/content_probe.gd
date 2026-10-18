extends Control
## Every shipped room must expose each object to a tap from Front and Top.
## Optional --capture=<directory> saves one front view per room and style.

const MAIN: PackedScene = preload("res://scenes/main.tscn")
var _failed: int = 0
var _out: String = ""

func _ready() -> void:
	_run()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_out = arg.trim_prefix("--capture=")
			DirAccess.make_dir_recursive_absolute(_out)
	var repo: ProfileRepo = ProfileRepo.new("user://content_probe_%s" % OS.get_process_id())
	ProfileStore.repo = repo
	var main: Main = MAIN.instantiate() as Main
	add_child(main)
	get_window().size = Vector2i(1280, 800)
	for pack: Starter in Starter.list_all():
		if pack.rooms.is_empty():
			continue
		var profile: Profile = repo.create_profile("Sam", pack, "calm")
		for style_id: String in ["calm", "bold", "quiet"]:
			profile.style_id = style_id
			repo.save_profile(profile)
			main.open_profile(profile.id)
			for frame: int in 8:
				await get_tree().process_frame
			var home: ChildHome = main.get_node("%ChildHome") as ChildHome
			var room: RoomView = home.get_node("%RoomView") as RoomView
			for view: CameraFraming.View in [CameraFraming.View.FRONT, CameraFraming.View.TOP]:
				room.set_view(view, false)
				await get_tree().process_frame
				for body: SpotBody in room.bodies():
					var reachable: bool = room.pick_at(room.screen_point(body)) == body
					var rect: Rect2 = room.screen_bounds(body)
					for x: int in range(1, 5):
						if reachable:
							break
						for y: int in range(1, 5):
							if room.pick_at(rect.position + rect.size * Vector2(x / 5.0, y / 5.0)) == body:
								reachable = true
								break
					if not reachable:
						_failed += 1
						print("FAIL %s/%s view %d: %s has no reachable surface" % [pack.id, style_id, view, body.spot.id])
				if view == CameraFraming.View.FRONT and not _out.is_empty():
					RenderingServer.force_draw()
					var path: String = _out.path_join("%s-%s.png" % [pack.id, style_id])
					if get_viewport().get_texture().get_image().save_png(path) != OK:
						_failed += 1
			print("CONTENT %s/%s checked" % [pack.id, style_id])
		repo.delete_profile(profile.id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(repo.root))
	print("CONTENT-PROBE %s (%d)" % ["PASS" if _failed == 0 else "FAIL", _failed])
	get_tree().quit(0 if _failed == 0 else 1)

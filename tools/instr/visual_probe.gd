extends Control
## Live layout and render sweep. Fixtures use an isolated profile directory and never record audio.
## Optional --capture[=<directory>] saves screenshots. Run with a real renderer for captures.

class DeleteFailureRepo extends ProfileRepo:
	func delete_profile(_profile_id: String) -> Error:
		return ERR_FILE_CANT_WRITE

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const SIZES: Array[Vector2i] = [Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(640, 640)]
var _failures: PackedStringArray = []
var _capture: bool = false
var _out: String = "user://visual_probe_captures"
var _label: String = ""
var _profile_looks_complete: bool = false

func _ready() -> void:
	_run()

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.push_back(_label + " " + message)
		print("FAIL %s %s" % [_label, message])

func _settle() -> void:
	for frame: int in 8:
		await get_tree().process_frame

func _shot(surface: String) -> void:
	if not _capture:
		return
	RenderingServer.force_draw()
	var path: String = _out.path_join("%s-%s.png" % [_label, surface])
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	_check(error == OK, "screenshot saved %s" % path)

func _square(control: Control, label: String) -> void:
	_check(absf(control.size.x - control.size.y) < 0.01, "%s stays square (%s)" % [label, control.size])

func _inside(control: Control, rect: Rect2, label: String) -> void:
	_check(rect.grow(2.0).encloses(control.get_global_rect()), "%s fits (%s in %s)" % [label, control.get_global_rect(), rect])

func _drag_scroll(scroll: ScrollContainer, at: Vector2) -> void:
	var before_drag: int = scroll.scroll_vertical
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = at
	press.global_position = press.position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	get_viewport().push_input(press, true)
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.relative = Vector2(0.0, -120.0)
	drag.position = press.position + drag.relative
	drag.global_position = drag.position
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(drag, true)
	drag.relative = Vector2(0.0, -60.0)
	drag.position += drag.relative
	drag.global_position = drag.position
	get_viewport().push_input(drag, true)
	await _settle()
	press.pressed = false
	press.position = drag.position
	press.global_position = drag.position
	get_viewport().push_input(press, true)
	await _settle()
	_check(scroll.scroll_vertical > before_drag, "drag scrolls %s" % scroll.name)

## A real press through the viewport that moves by `motion`, held for the button's full time, then released.
func _drag_hold(button: HoldButton, motion: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.position = button.get_global_rect().get_center()
	press.global_position = press.position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	get_viewport().push_input(press, true)
	var drag: InputEventMouseMotion = InputEventMouseMotion.new()
	drag.relative = motion
	drag.position = press.position + motion
	drag.global_position = drag.position
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(drag, true)
	button._process(button.hold_seconds)
	press.pressed = false
	press.position = drag.position
	press.global_position = drag.position
	get_viewport().push_input(press, true)

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--capture" or arg.begins_with("--capture="):
			_capture = true
			if arg.begins_with("--capture="):
				_out = arg.trim_prefix("--capture=")
	if _capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var previous_repo: ProfileRepo = ProfileStore.repo
	ProfileStore.repo = ProfileRepo.new("user://visual_probe_%s" % OS.get_process_id())
	var profile: Profile = ProfileStore.create_profile("Sam", Starter.find("home_routines"), "bold")
	var main: Main = MAIN.instantiate() as Main
	add_child(main)
	await _settle()
	var home: ChildHome = main.get_node("%ChildHome") as ChildHome
	var picker: ProfilePicker = main.get_node("%ProfilePicker") as ProfilePicker
	var room: RoomView = home.get_node("%RoomView") as RoomView
	var grid: HFlowContainer = home.get_node("%Board") as HFlowContainer
	var overlay: RecordOverlay = home.get_node("%RecordOverlay") as RecordOverlay
	for style_id: String in ["calm", "bold", "quiet"]:
		if OS.get_cmdline_user_args().has("--quick") and style_id != "calm":
			continue
		profile.style_id = style_id
		ProfileStore.save_profile(profile)
		for viewport_size: Vector2i in SIZES:
			if OS.get_cmdline_user_args().has("--quick") and viewport_size.x not in [390, 844]:
				continue
			_label = "%s-%dx%d" % [style_id, viewport_size.x, viewport_size.y]
			get_window().size = viewport_size
			main.open_profile(profile.id)
			await _settle()
			var screen: Rect2 = home.get_global_rect()
			var scale_xy: Vector2 = get_viewport().get_final_transform().get_scale()
			_check(absf(scale_xy.x - scale_xy.y) < 0.001, "canvas scales uniformly")
			_square(home.get_node("%ProfilesButton") as Control, "profile button")
			var widget: ViewWidget = room.get_node("%ViewWidget") as ViewWidget
			for button: SdfButton in widget.items():
				if button.visible:
					_square(button, "view button")
					_square(button.get_node("Glyph") as Control, "view glyph")
			var viewport: SubViewport = room.get_node("%Viewport") as SubViewport
			var display: Control = room.get_node("%ViewportContainer") as Control
			_check(absf(float(viewport.size.x) / viewport.size.y - display.size.x / display.size.y) < 0.002, "3D render aspect matches display")
			_inside(home.get_node("%TopBar") as Control, screen, "header")
			_inside(home.get_node("%ModeStrip") as Control, screen, "modes")
			_inside(room.get_node("%ViewWidget") as Control, screen, "views")
			for view: CameraFraming.View in [CameraFraming.View.FRONT, CameraFraming.View.TOP, CameraFraming.View.TILT]:
				room.set_view(view, false)
				await _settle()
				if view != CameraFraming.View.TILT:
					for body: SpotBody in room.bodies():
						_check(room.safe_rect().grow(1.0).encloses(room.screen_bounds(body)), "%s bounds are visible in view %s" % [body.spot.id, view])
				if view == CameraFraming.View.TILT and viewport_size == Vector2i(1280, 800):
					_shot("tilt")
				if view == CameraFraming.View.FRONT:
					room.body("door").react()
					await get_tree().create_timer(0.55).timeout
					_shot("room")
			room.set_view(CameraFraming.View.FRONT, false)
			room.show_chunks(room.body("window").spot, Gestalt.from_text("long", "We can look | through the window | at the trees outside"), 20.0)
			await _settle()
			var captions: Control = room.get_node("%Captions") as Control
			_check(captions.get_child_count() == 1, "current caption remains visible")
			if captions.get_child_count() == 1:
				_inside(captions.get_child(0) as Control, screen, "caption")
			_shot("caption")
			home.show_words()
			await _settle()
			_check(grid.size.x <= screen.size.x, "board fits horizontally")
			for child: Node in grid.get_children():
				var tile: GestaltTile = child as GestaltTile
				_check(tile.size.x <= 320.0, "Words tiles do not stretch to fill a row")
				_check(tile.size.x >= Style.current.tile_min_size and tile.size.y >= Style.current.tile_min_size, "tile meets touch floor")
				_inside(tile.get_node("%Chunks") as Control, tile.get_global_rect(), "tile chunks")
			var modes: PillBar = home.get_node("%ModeStrip") as PillBar
			var selected: int = 0
			for button: SdfButton in modes.items():
				selected += 1 if button.button_pressed else 0
			_check(selected == 1, "exactly one selected mode")
			_check(home.mode_button(ChildHome.Mode.WORDS).button_pressed, "Words is the selected mode")
			_inside(home.get_node("%WordsWidget") as Control, screen, "words widget")
			_shot("board")
			home.show_build()
			await _settle()
			var build: BuildView = home.build_view()
			_inside(build, screen, "build view")
			for button: ChunkButton in build.beginning_buttons() + build.ending_buttons():
				_check(button.size.y >= Style.current.tile_min_size, "chunk button meets touch floor")
				_check(button.get_global_rect().end.x <= screen.end.x + 1.0, "chunk button fits horizontally")
			_shot("build")
			home.show_palette()
			await _settle()
			overlay.open(Gestalt.from_text("long", "Let's go outside together and look at the trees in the garden"), profile)
			await _settle()
			_square(overlay.get_node("%RecordButton") as Control, "record button")
			_inside(overlay.get_node("%Phrase") as Control, screen, "recording phrase")
			var record_column: Control = (overlay.get_node("%Phrase") as Control).get_parent() as Control
			_inside(record_column, (record_column.get_parent() as Control).get_global_rect(), "record content fits panel")
			var record_sheet: ScrollContainer = overlay.get_node("Center") as ScrollContainer
			record_sheet.ensure_control_visible(overlay.get_node("%CancelButton") as Control)
			await _settle()
			_inside(overlay.get_node("%CancelButton") as Control, screen, "record back reachable")
			_shot("record")
			var record_button: Control = overlay.get_node("%RecordButton") as Control
			var review: Control = overlay.get_node("%ReviewRow") as Control
			record_button.hide()
			review.show()
			await _settle()
			_shot("review")
			overlay.close()
			main.show_picker()
			await _settle()
			var create: Control = picker.get_node("%CreateButton") as Control
			var sheet: ScrollContainer = picker.get_node("Center") as ScrollContainer
			_inside(picker.get_node("%NewProfileButton") as Control, screen, "new profile action fits")
			_shot("picker")
			var profile_card: Control = (picker.get_node("%Profiles") as Control).get_child(0) as Control
			(profile_card.get_child(1) as SdfButton).pressed.emit()
			await _settle()
			_inside(picker.get_node("%StyleBar") as Control, screen, "existing profile look choices")
			var scene_rows: Control = picker.get_node("%SceneRows") as Control
			_check(scene_rows.get_child_count() >= 2, "every shipped scene is listed (%d)" % scene_rows.get_child_count())
			sheet.ensure_control_visible(scene_rows)
			await _settle()
			_inside(scene_rows, screen, "scene choices")
			sheet.ensure_control_visible(create)
			await _settle()
			_inside(create, screen, "save look reachable")
			_shot("profile-look")
			(picker.get_node("%BackButton") as SdfButton).pressed.emit()
			(picker.get_node("%NewProfileButton") as SdfButton).pressed.emit()
			await _settle()
			sheet.ensure_control_visible(create)
			await _settle()
			_inside(create, screen, "create reachable by scrolling")
			_shot("new-profile")
			(picker.get_node("%BackButton") as SdfButton).pressed.emit()
			print("VISUAL checked %s" % _label)
	await _safe_areas(main, home, picker, overlay, profile)
	await _profile_looks(main, picker, profile)
	_check(_profile_looks_complete, "profile look flow completed")
	await _short_picker(main, picker)
	await _stress(main, home, picker, overlay, profile)
	ProfileStore.repo.delete_profile(profile.id)
	main.show_picker()
	await _settle()
	_check((picker.get_node("%NameEdit") as Control).is_visible_in_tree(), "empty picker opens creation form")
	_check(not (picker.get_node("%BackButton") as Control).is_visible_in_tree(), "empty picker has no redundant Back action")
	(picker.get_node("%NameEdit") as LineEdit).text = "New profile fixture"
	(picker.get_node("%CreateButton") as SdfButton).pressed.emit()
	_check(not picker.visible and App.active_profile.display_name == "New profile fixture", "creation opens the new profile")
	await _profile_deletion(main, picker, App.active_profile)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileStore.repo.root))
	ProfileStore.repo = previous_repo
	print("VISUAL-PROBE %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)

func _profile_deletion(main: Main, picker: ProfilePicker, target: Profile) -> void:
	_label = "profile-deletion"
	var other: Profile = ProfileStore.create_profile("Keep this profile", null, "calm")
	var media: String = ProfileStore.media_dir(target.id).path_join("name")
	DirAccess.make_dir_recursive_absolute(media)
	var file: FileAccess = FileAccess.open(media.path_join("name.prev.wav"), FileAccess.WRITE)
	file.store_string("synthetic deletion fixture")
	file.close()
	main.show_picker()
	picker._on_edit_profile(target.id)
	await _settle()
	var button: HoldButton = picker.get_node("%DeleteButton") as HoldButton
	var sheet: ScrollContainer = picker.get_node("%Center") as ScrollContainer
	sheet.ensure_control_visible(button)
	await _settle()
	_inside(button, picker.get_global_rect(), "delete action reachable")
	_shot("delete-profile")
	button.button_down.emit()
	button._process(button.hold_seconds - 0.1)
	button.button_up.emit()
	button.pressed.emit()
	_check(ProfileStore.load_profile(target.id) != null, "short press does not delete")
	for notification: int in [Control.NOTIFICATION_SCROLL_BEGIN]:
		button.button_down.emit()
		button.notification(notification)
		button._process(button.hold_seconds)
		button.button_up.emit()
		_check(ProfileStore.load_profile(target.id) != null, "scroll cancels deletion")
	button.button_down.emit()
	button.mouse_exited.emit()
	button._process(button.hold_seconds)
	button.button_up.emit()
	_check(ProfileStore.load_profile(target.id) != null, "leaving the button cancels deletion")
	button.button_down.emit()
	get_window().focus_exited.emit()
	button._process(button.hold_seconds)
	button.button_up.emit()
	_check(ProfileStore.load_profile(target.id) != null, "losing window focus cancels deletion")
	var real_repo: ProfileRepo = ProfileStore.repo
	ProfileStore.repo = DeleteFailureRepo.new(real_repo.root)
	(picker.get_node("%Status") as Label).hide()
	_drag_hold(button, Vector2(1.0, 3.0))
	_check((picker.get_node("%Status") as Label).visible, "a finger's jitter keeps the delete hold")
	_check((picker.get_node("%Status") as Label).visible, "deletion errors remain on the caregiver screen")
	(picker.get_node("%Status") as Label).hide()
	_drag_hold(button, Vector2(0.0, -40.0))
	_check(not (picker.get_node("%Status") as Label).visible, "a drag past the scroll distance cancels the delete hold")
	_check(real_repo.load_profile(target.id) != null and App.active_profile != null, "failed delete preserves selection and disk data")
	ProfileStore.repo = real_repo
	sheet.ensure_control_visible(button)
	await _settle()
	var previous_home: ChildHome = main.get_node("%ChildHome") as ChildHome
	button.button_down.emit()
	button._process(button.hold_seconds)
	button.button_up.emit()
	button.pressed.emit()
	await _settle()
	_check(not DirAccess.dir_exists_absolute(real_repo.profile_dir(target.id)), "successful hold removes profile and all recordings")
	_check(App.active_profile == null, "deleted active profile is cleared")
	_check(not is_instance_valid(previous_home), "deleted profile's playback and recorder controls are discarded")
	_check(real_repo.load_profile(other.id) != null, "other profile is untouched")
	_check(picker.visible and not button.is_visible_in_tree(), "delete returns to the profile list")
	main.open_profile(other.id)
	_check(App.active_profile != null and App.active_profile.id == other.id, "another profile opens after deletion")
	main.show_picker()
	picker._on_edit_profile(other.id)
	await _settle()
	button.button_down.emit()
	button._process(button.hold_seconds)
	button.button_up.emit()
	await _settle()
	_check(ProfileStore.list_ids().is_empty(), "last profile is removed")
	_check((picker.get_node("%NameEdit") as Control).is_visible_in_tree(), "deleting the last profile opens creation")
	_check(not button.is_visible_in_tree(), "creation never exposes delete")

func _profile_looks(main: Main, picker: ProfilePicker, profile: Profile) -> void:
	_label = "profile-looks"
	var saved: Profile = ProfileStore.load_profile(profile.id)
	var expected: String = JSON.stringify(saved.to_dict())
	var other: Profile = ProfileStore.create_profile("Another profile", null, "quiet")
	main.show_picker()
	await _settle()
	var styles: PillBar = picker.get_node("%StyleBar") as PillBar
	var ids: PackedStringArray = StylePreset.list_ids()
	(picker.get_node("%NewProfileButton") as SdfButton).pressed.emit()
	styles.items()[ids.find("bold")].pressed.emit()
	_check(Style.current == StylePreset.load_by_id("bold"), "new-profile look previews immediately")
	_check(ProfileStore.load_profile(profile.id).style_id == saved.style_id, "preview leaves existing profile unchanged")
	(picker.get_node("%BackButton") as SdfButton).pressed.emit()
	var previous: StylePreset = Style.current
	var card: Control = (picker.get_node("%Profiles") as Control).get_child(0) as Control
	(card.get_child(1) as SdfButton).pressed.emit()
	_check(styles.active_index() == ids.find(saved.style_id), "editing selects the saved look")
	styles.items()[ids.find("calm")].pressed.emit()
	_check(Style.current == StylePreset.load_by_id("calm"), "existing-profile look previews immediately")
	_check(JSON.stringify(ProfileStore.load_profile(profile.id).to_dict()) == expected, "preview writes nothing")
	(picker.get_node("%BackButton") as SdfButton).pressed.emit()
	_check(Style.current == previous, "Back restores the previous preview")
	_check(JSON.stringify(ProfileStore.load_profile(profile.id).to_dict()) == expected, "Back preserves the profile")
	card = (picker.get_node("%Profiles") as Control).get_child(0) as Control
	(card.get_child(1) as SdfButton).pressed.emit()
	styles.items()[ids.find("bold")].pressed.emit()
	(picker.get_node("%CreateButton") as SdfButton).pressed.emit()
	saved.style_id = "bold"
	expected = JSON.stringify(saved.to_dict())
	_check(JSON.stringify(ProfileStore.load_profile(profile.id).to_dict()) == expected, "Save changes only the profile's look")
	_check(ProfileStore.load_profile(other.id).style_id == "quiet", "other profile look is unchanged")
	_check(not picker.visible, "Save opens the updated profile")
	Style.apply(StylePreset.load_by_id("calm"))
	main.open_profile(profile.id)
	_check(Style.current == StylePreset.load_by_id("bold"), "reopening loads the saved look")
	ProfileStore.repo.delete_profile(other.id)
	_profile_looks_complete = true

func _short_picker(main: Main, picker: ProfilePicker) -> void:
	for style: String in ["calm", "bold", "quiet"]:
		for window_size: Vector2i in [Vector2i(1280, 360), Vector2i(800, 240), Vector2i(640, 360), Vector2i(390, 280), Vector2i(640, 640)]:
			_label = "short-%s-%dx%d" % [style, window_size.x, window_size.y]
			get_window().size = window_size
			Style.apply(StylePreset.load_by_id(style))
			main.show_picker()
			await _settle()
			var screen: Rect2 = picker.get_global_rect()
			_inside(picker.get_node("%NewProfileButton") as Control, screen, "profile list fits short window")
			_shot("picker")
			(picker.get_node("%NewProfileButton") as SdfButton).pressed.emit()
			await _settle()
			get_window().size = Vector2i(1280, 900)
			await _settle()
			get_window().size = window_size
			await _settle()
			screen = picker.get_global_rect()
			var create: Control = picker.get_node("%CreateButton") as Control
			var sheet: ScrollContainer = picker.get_node("Center") as ScrollContainer
			if sheet.get_v_scroll_bar().max_value > sheet.get_v_scroll_bar().page:
				var wheel: InputEventMouseButton = InputEventMouseButton.new()
				wheel.position = (picker.get_node("%StyleBar") as Control).get_global_rect().get_center()
				wheel.global_position = wheel.position
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = true
				wheel.factor = 20.0
				get_viewport().push_input(wheel, true)
				await _settle()
			_inside(create, screen, "bottom action reachable with native wheel input")
			var content: Control = create.get_parent().get_parent() as Control
			_inside(content, (content.get_parent() as Control).get_global_rect(), "form fits its panel after resize")
			_shot("form")
			(picker.get_node("%BackButton") as SdfButton).pressed.emit()

func _stress(main: Main, home: ChildHome, picker: ProfilePicker, overlay: RecordOverlay, profile: Profile) -> void:
	_label = "long-content"
	get_window().size = Vector2i(320, 568)
	var ids: PackedStringArray = []
	for index: int in 30:
		var id: String = "long_%d" % index
		profile.gestalts.push_back(Gestalt.from_text(id, "We can go | to the garden together | and look at | the leaves on the trees"))
		ids.push_back(id)
	var board: Board = Board.make("long", "Words for our time in the garden", ids)
	profile.boards.push_back(board)
	profile.rooms[0].title = "The bedroom where we get ready in the morning"
	profile.display_name = "A profile with a longer display name"
	profile.style_id = "calm"
	ProfileStore.save_profile(profile)
	main.open_profile(profile.id)
	home.show_profile(profile)
	home.show_words()
	await _settle()
	var screen: Rect2 = home.get_global_rect()
	var grid: HFlowContainer = home.get_node("%Board") as HFlowContainer
	var stage: ScrollContainer = home.get_node("%Stage") as ScrollContainer
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.position = stage.get_global_rect().get_center()
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	get_viewport().push_input(wheel, true)
	await _settle()
	_check(stage.scroll_vertical > 0, "mouse wheel scrolls the board")
	await _drag_scroll(stage, stage.get_global_rect().get_center())
	_check(not overlay.visible, "drag scrolling does not open the recorder")
	_square(home.get_node("%ProfilesButton") as Control, "profile button with wrapped navigation")
	_inside(home.get_node("%TopBar") as Control, screen, "long name header")
	_inside(home.get_node("%ModeStrip") as Control, screen, "mode strip beside a long name")
	_check(home.mode_button(ChildHome.Mode.EXPLORE).text == "Explore", "a long room title stays off the strip")
	_check(home.mode_button(ChildHome.Mode.WORDS).text == "Words", "a long board title stays off the strip")
	_check(grid.get_child_count() == profile.words_gestalts().size(), "Words holds every board's tiles (%d)" % grid.get_child_count())
	for child: Node in grid.get_children():
		var tile: GestaltTile = child as GestaltTile
		_inside(tile.get_node("%Chunks") as Control, tile.get_global_rect(), "long phrase chunks")
	var last: GestaltTile = grid.get_child(grid.get_child_count() - 1) as GestaltTile
	stage.ensure_control_visible(last)
	await _settle()
	_inside(last, stage.get_global_rect(), "last tile reachable")
	last.play(0.5)
	await get_tree().create_timer(0.3).timeout
	_inside(last.get_node("%Chunks") as Control, last.get_global_rect(), "animated chunks")
	var holds: Array[int] = [0]
	last.held.connect(func() -> void: holds[0] += 1)
	last.hold_seconds = 0.03
	last.button_down.emit()
	last.notification(Control.NOTIFICATION_SCROLL_BEGIN)
	await get_tree().create_timer(0.08).timeout
	last.button_up.emit()
	await _settle()
	_check(holds[0] == 0, "scrolling cancels a caregiver hold")
	_check(not overlay.visible, "scrolling never opens the recorder")
	_shot("board")
	last.grab_focus()
	overlay.open(last.gestalt, profile)
	await _settle()
	var tab: InputEventKey = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	for step: int in 6:
		get_viewport().push_input(tab, true)
		await _settle()
		var focused: Control = get_viewport().gui_get_focus_owner()
		_check(focused != null and overlay.is_ancestor_of(focused), "keyboard focus stays in recording overlay")
	overlay.close()
	_check(get_viewport().gui_get_focus_owner() == last, "closing recorder restores tile focus")
	var fixtures: PackedStringArray = []
	for index: int in 10:
		var fixture: Profile = ProfileStore.create_profile("A longer profile name %d" % index, null, "calm")
		fixtures.push_back(fixture.id)
	main.show_picker()
	await _settle()
	var sheet: ScrollContainer = picker.get_node("Center") as ScrollContainer
	var create: Control = picker.get_node("%NewProfileButton") as Control
	sheet.scroll_vertical = 0
	await _settle()
	var first_profile: Control = (picker.get_node("%Profiles") as Control).get_child(0) as Control
	await _drag_scroll(sheet, first_profile.get_global_rect().get_center())
	_check(picker.visible, "dragging a profile does not open it")
	sheet.ensure_control_visible(create)
	await _settle()
	_inside(create, screen, "new profile reachable with many profiles")
	_shot("picker")
	for id: String in fixtures:
		ProfileStore.repo.delete_profile(id)

## Pixel fixtures exercise the same conversion as DisplayServer, including a same-size 180-degree turn.
func _safe_areas(main: Main, home: ChildHome, picker: ProfilePicker, overlay: RecordOverlay, profile: Profile) -> void:
	var sizes: Array[Vector2i] = [Vector2i(390, 844), Vector2i(393, 852), Vector2i(844, 390), Vector2i(844, 390), Vector2i(390, 844), Vector2i(1024, 768)]
	var natives: Array[Rect2] = [Rect2(0, 47, 390, 763), Rect2(0, 59, 393, 759), Rect2(59, 0, 785, 369), Rect2(0, 0, 785, 369), Rect2(0, 0, 390, 844), Rect2(0, 24, 1024, 724)]
	var cutouts: Array[Rect2] = [Rect2(95, 0, 200, 34), Rect2(134, 11, 125, 37), Rect2(0, 95, 34, 200), Rect2(810, 95, 34, 200), Rect2(-10, -10, 1, 1), Rect2(-10, -10, 1, 1)]
	var names: PackedStringArray = ["notch", "island", "landscape-left", "landscape-right", "rounded", "tablet"]
	var mask: ColorRect = ColorRect.new()
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://tools/instr/safe_screen.gdshader") as Shader
	mask.material = material
	add_child(mask)
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var room: RoomView = home.get_node("%RoomView") as RoomView
	for style: String in ["calm", "bold", "quiet"]:
		profile.style_id = style
		ProfileStore.save_profile(profile)
		for index: int in sizes.size():
			_label = "safe-%s-%s" % [style, names[index]]
			get_window().size = sizes[index]
			await _settle()
			main.set_safe_area_override(natives[index])
			material.set_shader_parameter("screen_size", Vector2(sizes[index]))
			var cutout: Rect2 = cutouts[index]
			material.set_shader_parameter("cutout", Vector4(cutout.position.x, cutout.position.y, cutout.size.x, cutout.size.y))
			main.open_profile(profile.id)
			await _settle()
			var safe: Rect2 = main.safe_area_rect()
			var transform: Transform2D = get_viewport().get_final_transform()
			_check(natives[index].grow(1.0).encloses(transform * safe), "logical safe bounds fit native pixels")
			_check(absf(transform.get_scale().x - transform.get_scale().y) < 0.001, "safe layout preserves uniform scale")
			_check(room.get_global_rect().is_equal_approx(main.get_global_rect()), "world remains edge to edge")
			_inside(home.get_node("%TopBar") as Control, safe, "header avoids cutouts")
			_inside(home.get_node("%ModeStrip") as Control, safe, "modes avoid cutouts")
			_inside(room.get_node("%ViewWidget") as Control, safe, "views avoid gesture area")
			_square(home.get_node("%ProfilesButton") as Control, "profile control")
			for view: CameraFraming.View in [CameraFraming.View.FRONT, CameraFraming.View.TOP]:
				room.set_view(view, false)
				await _settle()
				for body: SpotBody in room.bodies():
					_check(room.safe_rect().grow(1.0).encloses(room.screen_bounds(body)), "object avoids cutouts in view %s" % view)
			room.set_view(CameraFraming.View.FRONT, false)
			_check(room.pick_at(Vector2.ZERO) == null, "unsafe edge cannot pick an object")
			room.show_chunks(room.body("window").spot, Gestalt.from_text("safe", "Let's look | through the window"), 20.0)
			await _settle()
			var captions: Control = room.get_node("%Captions") as Control
			_inside(captions.get_child(0) as Control, safe, "caption avoids cutouts")
			_shot("room")
			home.show_words()
			await _settle()
			_inside(home.get_node("%Stage") as Control, safe, "board scroll area avoids cutouts")
			_shot("board")
			overlay.open(Gestalt.from_text("safe", "Let's go outside together and look at the trees"), profile)
			await _settle()
			var record_sheet: ScrollContainer = overlay.get_node("%Center") as ScrollContainer
			_inside(record_sheet, safe, "recording sheet avoids cutouts")
			record_sheet.ensure_control_visible(overlay.get_node("%CancelButton") as Control)
			await _settle()
			_inside(overlay.get_node("%CancelButton") as Control, safe, "recording Back remains reachable")
			_square(overlay.get_node("%RecordButton") as Control, "record control")
			_shot("record")
			overlay.close()
			main.show_picker()
			await _settle()
			_inside(picker, safe, "profile picker avoids cutouts")
			_shot("picker")
			var card: Control = (picker.get_node("%Profiles") as Control).get_child(0) as Control
			(card.get_child(1) as SdfButton).pressed.emit()
			await _settle()
			var sheet: ScrollContainer = picker.get_node("Center") as ScrollContainer
			var save: Control = picker.get_node("%CreateButton") as Control
			sheet.ensure_control_visible(save)
			await _settle()
			_inside(save, safe, "Save look remains reachable")
			_shot("look")
			(picker.get_node("%BackButton") as SdfButton).pressed.emit()
			(picker.get_node("%NewProfileButton") as SdfButton).pressed.emit()
			await _settle()
			sheet.ensure_control_visible(save)
			await _settle()
			_inside(save, safe, "Create remains reachable")
			_shot("create")
			print("VISUAL checked %s" % _label)
	# Rotate while a form is still open, then change the notch side without resizing.
	for index: int in [0, 2, 3]:
		_label = "safe-open-form-%s" % names[index]
		get_window().size = sizes[index]
		await _settle()
		main.set_safe_area_override(natives[index])
		await _settle()
		var create: Control = picker.get_node("%CreateButton") as Control
		(picker.get_node("Center") as ScrollContainer).ensure_control_visible(create)
		await _settle()
		_inside(create, main.safe_area_rect(), "open form reflows on rotation")
	main.open_profile(profile.id)
	overlay.open(Gestalt.from_text("rotation", "Let's go outside"), profile)
	await _settle()
	for index: int in [0, 2, 3]:
		_label = "safe-open-recorder-%s" % names[index]
		get_window().size = sizes[index]
		await _settle()
		main.set_safe_area_override(natives[index])
		await _settle()
		var back: Control = overlay.get_node("%CancelButton") as Control
		(overlay.get_node("%Center") as ScrollContainer).ensure_control_visible(back)
		await _settle()
		_inside(back, main.safe_area_rect(), "open recorder reflows on rotation")
	overlay.close()
	main.clear_safe_area_override()
	mask.queue_free()
	await _settle()
	_check(main.safe_area_rect().is_equal_approx(main.get_global_rect()), "clearing fixture restores desktop bounds")

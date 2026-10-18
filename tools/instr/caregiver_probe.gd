extends Control
## Exercise pointer routing through the real edit sheet and Markdown page, including nested panels.
const MAIN: PackedScene = preload("res://scenes/main.tscn")
var _failures: int = 0

func _ready() -> void:
	_run()

func _check(ok: bool, message: String) -> void:
	print("%s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		_failures += 1

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

func _run() -> void:
	get_window().size = Vector2i(390, 844) if OS.get_cmdline_user_args().has("--phone") else Vector2i(640, 640)
	var repo: ProfileRepo = ProfileRepo.new("user://caregiver_probe_%s" % OS.get_process_id())
	ProfileStore.repo = repo
	var p: Profile = repo.create_profile("Sam", Starter.find("home_routines"), "calm")
	for pack: Starter in Starter.list_all():
		if pack.is_scene() and not p.has_scene(pack.id):
			pack.add_to(p)
	# Simulate a room saved by the previous build.
	p.rooms[0].width = 4.0
	p.rooms[0].depth = 3.0
	p.gestalts[0].recording = "familiar.wav"
	var phrase_before: Dictionary = p.gestalts[0].to_dict()
	repo.save_profile(p)
	repo.remember(p.id)
	var main: Main = MAIN.instantiate() as Main
	add_child(main)
	await _settle()
	_check(Starter.find("home_routines").layout_matches(repo.load_profile(p.id)), "launch refreshes the remembered profile room")
	main.show_picker()
	var picker: ProfilePicker = main.get_node("%ProfilePicker") as ProfilePicker
	picker._on_edit_profile(p.id)
	await _settle()
	var sheet: SdfSheet = picker.get_node("%Center") as SdfSheet
	var notes: SdfTextArea = picker.get_node("%NotesEdit") as SdfTextArea
	sheet.ensure_control_visible(notes)
	await _settle()
	notes.grab_focus()
	_mouse(notes.get_global_rect().get_center(), true)
	_mouse(notes.get_global_rect().get_center(), false)
	_check(notes.has_focus(), "a tap inside the text entry retains focus")
	var outside: Vector2 = notes.global_position + Vector2(10, -12)
	_mouse(outside, true)
	_mouse(outside, false)
	_check(not notes.has_focus(), "a tap outside the text entry releases keyboard focus")
	# Inject a native keyboard height because headless hosts have no virtual keyboard.
	sheet.set_process(false)
	notes.grab_focus()
	var full_height: float = sheet.size.y
	sheet._fit_keyboard(250)
	await _settle()
	var pixels: Transform2D = get_viewport().get_final_transform() * sheet.get_global_transform()
	var bottom: float = (pixels * Vector2(0, sheet.size.y)).y
	_check(absf(bottom - (get_window().size.y - 250)) < 1.0, "sheet bottom meets the keyboard in screen pixels")
	var inset_height: float = sheet.size.y
	_check(sheet.get_global_rect().encloses(notes.get_global_rect()), "the focused entry remains above the keyboard")
	sheet._fit_keyboard(250)
	_check(is_equal_approx(sheet.size.y, inset_height), "keyboard inset does not accumulate across frames")
	sheet._fit_keyboard(0)
	await _settle()
	_check(is_equal_approx(sheet.size.y, full_height), "hiding the keyboard restores the sheet height")
	notes.release_focus()
	sheet.set_process(true)
	var entry: VBoxContainer = picker.scene_rows()[1] as VBoxContainer
	sheet.ensure_control_visible(entry)
	await _settle()
	var before: int = sheet.scroll_vertical
	await _drag(entry.global_position + Vector2(entry.size.x / 2, 100))
	_check(sheet.scroll_vertical > before + 24, "dragging through a nested scene panel scrolls the edit sheet")
	# Scene stages rebuild their controls. Keep the current reading position.
	entry = picker.scene_rows()[2] as VBoxContainer
	var bar: PillBar = (entry.get_child(1) as BoxContainer).get_child(1) as PillBar
	sheet.ensure_control_visible(bar)
	await _settle()
	before = sheet.scroll_vertical
	bar.items()[2].pressed.emit()
	await _settle()
	_check(absi(sheet.scroll_vertical - before) < 3, "changing a scene stage preserves scroll position")
	var saved: Profile = repo.load_profile(p.id)
	for room: Room in saved.rooms:
		room.width = 4.0
		room.depth = 3.0
	repo.save_profile(saved)
	picker.profile_chosen.emit(p.id)
	await _settle()
	var refreshed: Profile = repo.load_profile(p.id)
	for pack: Starter in Starter.list_all():
		if refreshed.has_scene(pack.id):
			_check(pack.layout_matches(refreshed), "profile selection refreshes %s on disk" % pack.id)
	_check(refreshed.gestalts[0].to_dict() == phrase_before, "automatic refresh preserves the recorded phrase")
	_check(refreshed.scene_stages == saved.scene_stages, "automatic refresh preserves scene stages")
	_check(Starter.find("home_routines").layout_matches(App.active_profile), "the active profile displays refreshed geometry")
	main.show_picker()
	picker._on_glossary_pressed()
	await _settle()
	var page: VBoxContainer = picker.get_node("%Page") as VBoxContainer
	var text: RichTextLabel = page.get_child(0) as RichTextLabel
	before = sheet.scroll_vertical
	await _drag(Vector2(260, 450))
	_check(sheet.scroll_vertical > before + 24, "dragging Markdown text scrolls its page")
	_check(not text.selection_enabled and text.get_selected_text().is_empty(), "a page drag never selects text")
	# A different page always begins at its top after a previous page was scrolled.
	picker._on_guide_pressed()
	await _settle()
	_check(sheet.scroll_vertical == 0, "a new Markdown page starts at the top")
	repo.delete_profile(p.id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(repo.root))
	print("CAREGIVER-PROBE %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

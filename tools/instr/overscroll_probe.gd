extends Control
## Overscroll probe: on the Palette stage of the real home screen, drag past the top and the bottom through
## synthetic mouse drags, the events Godot emulates from a finger, release, fling into an end, and repeat with the Quiet style's motion off. Runs headless
## (`just overscroll-probe`); the band lives in the scene tree's input routing, which is why it is a probe and
## not a unit suite (docs/gates.md). Prints OVERSCROLL-PROBE PASS or FAIL and exits with the matching code.
##
## The root is a Control so the window's theme reaches the home screen.

const _MAIN: PackedScene = preload("res://scenes/main.tscn")

var _failures: PackedStringArray = PackedStringArray()

func _ready() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		_failures.push_back(label)

func _run() -> void:
	# Small enough that the starter's board scrolls.
	get_window().size = Vector2i(640, 480)
	var repo: ProfileRepo = ProfileRepo.new("user://overscroll_probe_%s" % OS.get_process_id())
	ProfileStore.repo = repo
	var p: Profile = repo.create_profile("Sam", Starter.find("home_routines"), "bold")
	var main: Main = _MAIN.instantiate() as Main
	add_child(main)
	await _frames(2)
	main.open_profile(p.id)
	var home: ChildHome = main.get_node("%ChildHome") as ChildHome
	home.show_palette()
	await _frames(4)
	var stage: SdfScroll = home.get_node("%Stage") as SdfScroll
	var bar: VScrollBar = stage.get_v_scroll_bar()
	var bottom: int = int(bar.max_value - bar.page)
	_check(bottom > 0, "the board scrolls at 640x480 (%d px)" % bottom)
	var at: Vector2 = stage.get_global_rect().get_center()

	# Past the top.
	stage.scroll_vertical = 0
	await _frames(2)
	await _press(at)
	await _drag(at, Vector2(0.0, 12.0), 20)
	var shown: float = stage.overscroll()
	_check(shown > 0.0, "a pull past the top shows the band (%.1f px)" % shown)
	_check(shown < 240.0 * Overscroll.RESISTANCE, "and shows less than the finger travelled")
	_check(stage.scroll_vertical == 0, "the content stays at its top")
	await _release(at + Vector2(0.0, 240.0))
	await get_tree().create_timer(SdfScroll.RETURN_SECONDS + 0.3).timeout
	_check(stage.overscroll() == 0.0, "a release springs it back")

	# Past the bottom.
	stage.scroll_vertical = bottom
	await _frames(2)
	await _press(at)
	await _drag(at, Vector2(0.0, -12.0), 20)
	_check(stage.overscroll() < 0.0, "a pull past the bottom shows the band (%.1f px)" % stage.overscroll())
	await _release(at - Vector2(0.0, 240.0))
	await get_tree().create_timer(SdfScroll.RETURN_SECONDS + 0.3).timeout
	_check(stage.overscroll() == 0.0, "and springs back")

	# In the middle the content scrolls and nothing bands.
	stage.scroll_vertical = bottom / 2
	await _frames(2)
	var before: int = stage.scroll_vertical
	await _press(at)
	await _drag(at, Vector2(0.0, 6.0), 10)
	_check(stage.overscroll() == 0.0, "a drag in the middle shows no band")
	_check(stage.scroll_vertical < before, "and scrolls the content (%d to %d)" % [before, stage.scroll_vertical])
	await _release(at + Vector2(0.0, 60.0))
	await _frames(2)

	# A screen that opens at its top jumps there from rest. That is not a fling, even soon after a drag. The
	# drag's own inertia is let run out first: content still coasting toward the top does bounce there.
	var still: int = 0
	var last: int = stage.scroll_vertical
	while still < 5:
		await _frames(1)
		still = still + 1 if stage.scroll_vertical == last else 0
		last = stage.scroll_vertical
	stage.scroll_vertical = 0
	var jump_peak: float = 0.0
	for i: int in 20:
		jump_peak = maxf(jump_peak, absf(stage.overscroll()))
		await _frames(1)
	_check(jump_peak == 0.0, "a jump to the top does not bounce")

	# A tap moves nothing.
	stage.scroll_vertical = 0
	await _frames(2)
	await _press(at)
	await _drag(at, Vector2(0.0, 2.0), 3)
	_check(stage.overscroll() == 0.0, "a press inside the scroll deadzone shows no band")
	await _release(at + Vector2(0.0, 6.0))
	await _frames(2)

	# A fling that reaches the top carries past it and settles. A drag hands the content over, then it coasts
	# into the top over several frames, as the native inertia moves it.
	stage.scroll_vertical = 400
	await _frames(2)
	await _press(at)
	await _drag(at, Vector2(0.0, 10.0), 4)
	await _release(at + Vector2(0.0, 40.0))
	var peak: float = 0.0
	for scroll: int in [240, 160, 80, 0]:
		stage.scroll_vertical = scroll
		await _frames(1)
	for i: int in 20:
		peak = maxf(peak, stage.overscroll())
		await _frames(1)
	_check(peak > 0.0, "a fling into the top carries past it (%.1f px)" % peak)
	await get_tree().create_timer(SdfScroll.RETURN_SECONDS + 0.3).timeout
	_check(stage.overscroll() == 0.0, "and settles")

	# A pull that loses the window springs back, as if released.
	stage.scroll_vertical = 0
	await _frames(2)
	await _press(at)
	await _drag(at, Vector2(0.0, 12.0), 20)
	stage.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await get_tree().create_timer(SdfScroll.RETURN_SECONDS + 0.3).timeout
	_check(stage.overscroll() == 0.0, "losing the window mid-pull springs back")
	await _release(at + Vector2(0.0, 240.0))

	# A pull whose screen goes away comes back to rest at once.
	await _press(at)
	await _drag(at, Vector2(0.0, 12.0), 20)
	home.show_explore()
	await _frames(1)
	_check(stage.overscroll() == 0.0, "hiding the scroll mid-pull returns it at once")
	await _release(at + Vector2(0.0, 240.0))
	home.show_palette()
	await _frames(4)

	# With motion off the release returns at once.
	Style.apply(StylePreset.load_by_id("quiet"))
	_check(Style.motion_scale() == 0.0, "the Quiet style has motion off")
	stage.scroll_vertical = 0
	await _frames(2)
	await _press(at)
	await _drag(at, Vector2(0.0, 12.0), 20)
	_check(stage.overscroll() > 0.0, "the band still follows the finger")
	await _release(at + Vector2(0.0, 240.0))
	await _frames(1)
	_check(stage.overscroll() == 0.0, "and a release returns at once")

	repo.delete_profile(p.id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(repo.root))
	print("OVERSCROLL-PROBE %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame

# Mouse events, as a desktop sends them and as Godot emulates them from a finger. The native drag and the band
# both read these.
func _press(at: Vector2) -> void:
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	button.button_mask = MOUSE_BUTTON_MASK_LEFT
	button.position = at
	button.global_position = at
	get_viewport().push_input(button, true)
	await _frames(1)

func _drag(from: Vector2, step: Vector2, count: int) -> void:
	var at: Vector2 = from
	for i: int in count:
		at += step
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = at
		motion.global_position = at
		motion.relative = step
		get_viewport().push_input(motion, true)
		await _frames(1)

func _release(at: Vector2) -> void:
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = false
	button.position = at
	button.global_position = at
	get_viewport().push_input(button, true)
	await _frames(1)

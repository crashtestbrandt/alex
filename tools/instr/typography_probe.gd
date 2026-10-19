extends Control
## Real UI coverage at logical phone sizes and native 3x/2x densities, including 200% text.
const MAIN: PackedScene = preload("res://scenes/main.tscn")
var _failures: int = 0
var _out: String = ""
var _label: String = ""
var _capture_only: bool = false

func _ready() -> void:
	_run()

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL " + _label + " " + message)

func _settle() -> void:
	for frame: int in 12:
		await get_tree().process_frame

func _inspect(node: Node, density: float) -> void:
	if node is Control:
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			return
		if control is PillBar:
			var bar: PillBar = control as PillBar
			_check(bar._shape.get_global_rect().is_equal_approx(bar.get_global_rect()), str(bar.get_path()) + " background follows the bar: " + str(bar._shape.get_global_rect()) + " / " + str(bar.get_global_rect()))
			for item: SdfButton in bar.items():
				if item.is_visible_in_tree():
					_check(bar.get_global_rect().grow(1.0).encloses(item.get_global_rect()), str(bar.get_path()) + " contains its button: " + str(item.get_global_rect()) + " / " + str(bar.get_global_rect()))
		if control is GlyphBar.GlyphButton:
			var glyph_button: GlyphBar.GlyphButton = control as GlyphBar.GlyphButton
			_check(glyph_button._shape.get_global_rect().is_equal_approx(glyph_button.get_global_rect()), "selected glyph background follows the button")
			_check(glyph_button._glyph.get_global_rect().is_equal_approx(glyph_button.get_global_rect()), "glyph stays centered over its button")
		var has_text: bool = false
		var font_size: int = 0
		if control is Label:
			var label: Label = control as Label
			has_text = not label.text.is_empty()
			font_size = label.get_theme_font_size("font_size")
		elif control is Button:
			var button: Button = control as Button
			has_text = not button.text.is_empty()
			font_size = button.get_theme_font_size("font_size")
			var hit_size: Vector2 = button.size / Style.units_per_point
			_check(hit_size.x >= 43.5 and hit_size.y >= 43.5, str(button.get_path()) + " retains a 44-point touch target " + str(hit_size))
		elif control is LineEdit or control is TextEdit:
			has_text = true
			font_size = control.get_theme_font_size("font_size")
		elif control is RichTextLabel:
			var rich: RichTextLabel = control as RichTextLabel
			has_text = true
			font_size = rich.get_theme_font_size("normal_font_size")
			_check(rich.get_content_width() <= rich.size.x + 2.0, "Markdown wraps within its page")
		if has_text:
			var rect: Rect2 = control.get_global_rect()
			_check(rect.position.x >= -1.0 and rect.end.x <= size.x + 1.0, str(control.get_path()) + " stays within screen width " + str(rect))
			_check(control.size.y >= control.get_combined_minimum_size().y - 2.0, str(control.get_path()) + " has room for text height")
			var points: float = font_size * get_viewport().get_final_transform().get_scale().y / density
			_check(points >= Typography.METADATA * Style.text_scale - 0.1, "text remains legible in logical points: " + str(points))
	for child: Node in node.get_children():
		_inspect(child, density)

func _check_icon_bars() -> void:
	var bar: GlyphBar = GlyphBar.new()
	add_child(bar)
	for figure: SdfGlyph.Figure in [SdfGlyph.Figure.FRONT, SdfGlyph.Figure.TOP, SdfGlyph.Figure.TILT, SdfGlyph.Figure.PALETTE, SdfGlyph.Figure.BUILD]:
		bar.add_glyph(figure, "")
	for columns: int in [1, 2, 5]:
		var side: float = bar.items()[0].get_combined_minimum_size().x
		bar.fit_width(side * columns + PillBar.GAP_PX * (columns - 1) + PillBar.PAD_PX * 2.0)
		bar.reset_size()
		await _settle()
		for index: int in bar.items().size():
			bar.show_current(bar.items()[index] as GlyphBar.GlyphButton)
			await _settle()
			var button: SdfButton = bar.items()[index]
			var center: Vector2 = button.get_global_rect().get_center() - bar.global_position
			var radius: float = minf(button.size.x, button.size.y) * 0.5
			for step: int in 32:
				var point: Vector2 = center + Vector2.from_angle(TAU * step / 32.0) * radius
				var corner: float = bar._shape.radius_px
				var q: Vector2 = (point - bar.size * 0.5).abs() - bar.size * 0.5 + Vector2.ONE * corner
				var distance: float = q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - corner
				_check(distance <= 0.5, "selected icon stays on its bar background with %d columns" % columns)
			_check(button._shape.get_global_rect().is_equal_approx(button.get_global_rect()), "selected icon fill matches its hit target")
	bar.queue_free()
	await _settle()

func _reach_action(picker: ProfilePicker, path: String) -> void:
	var sheet: SdfSheet = picker.get_node("%Center") as SdfSheet
	var button: Control = picker.get_node(path) as Control
	sheet.ensure_control_visible(button)
	await _settle()
	var bounds: Rect2 = sheet.get_global_rect().grow(2.0)
	_check(bounds.encloses(button.get_global_rect()), path + " remains reachable by scrolling")

func _capture(surface: String) -> void:
	if _out.is_empty():
		return
	RenderingServer.force_draw()
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(_label + "-" + surface + ".png")) == OK, "capture " + surface)

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--capture-only":
			_capture_only = true
		if arg.begins_with("--capture="):
			_out = arg.trim_prefix("--capture=")
			DirAccess.make_dir_recursive_absolute(_out)
	var repo: ProfileRepo = ProfileRepo.new("user://typography_%s" % OS.get_process_id())
	ProfileStore.repo = repo
	var original_settings: String = Style.settings_path
	Style.settings_path = repo.root + "/accessibility.cfg"
	var profile: Profile = repo.create_profile("Sam", Starter.find("home_routines"), "calm", NlaStage.Stage.SINGLE_WORDS, true)
	profile.notes = "A familiar phrase can be repeated as often as the learner wants.\nThese notes should wrap and grow with larger text."
	var main: Main = MAIN.instantiate() as Main
	add_child(main)
	get_window().borderless = true
	get_window().position = Vector2i.ZERO
	var windows: Array[Vector2i] = [Vector2i(390, 844), Vector2i(1320, 2868), Vector2i(2868, 1320), Vector2i(2048, 2732)]
	var densities: Array[float] = [1.0, 3.0, 3.0, 2.0]
	for style_id: String in ["calm", "bold", "quiet"]:
		if _capture_only and style_id != "calm":
			continue
		profile.style_id = style_id
		repo.save_profile(profile)
		for index: int in windows.size():
			if _capture_only and index > 0:
				continue
			get_window().size = windows[index]
			main.set_display_density_override(densities[index])
			main.open_profile(profile.id)
			if index == 0:
				await _check_icon_bars()
			for text_scale: float in [1.0, 2.0]:
				Style.set_text_scale(text_scale)
				_label = "%s-%dx%d-%d" % [style_id, windows[index].x, windows[index].y, roundi(text_scale * 100)]
				await _settle()
				var home: ChildHome = main.get_node("%ChildHome") as ChildHome
				var picker: ProfilePicker = main.get_node("%ProfilePicker") as ProfilePicker
				var room: RoomView = home.get_node("%RoomView") as RoomView
				home.show_explore()
				room.tap(room.body("door"))
				await _settle()
				_inspect(home, densities[index])
				if style_id == "calm" and index == 0:
					_capture("explore")
				home.show_room_chooser()
				await _settle()
				_inspect(home.room_chooser(), densities[index])
				if style_id == "calm" and index == 0:
					_capture("rooms")
				home.show_explore()
				home.show_palette()
				await _settle()
				_inspect(home, densities[index])
				if style_id == "calm" and index == 0:
					_capture("words")
				home.show_build()
				await _settle()
				var build: BuildView = home.build_view()
				build.clear()
				build.beginning_buttons()[0].pressed.emit()
				await _settle()
				_inspect(home, densities[index])
				if style_id == "calm" and index == 0:
					_capture("build")
				var overlay: RecordOverlay = home.get_node("%RecordOverlay") as RecordOverlay
				overlay.open(Gestalt.from_text("long", "Let’s go outside together and look at the trees in the garden"), profile)
				await _settle()
				_inspect(overlay, densities[index])
				overlay.close()
				main.show_picker()
				picker._on_new_profile()
				await _settle()
				_inspect(picker, densities[index])
				if style_id == "calm" and index == 0:
					_capture("create")
				await _reach_action(picker, "%CreateButton")
				picker._on_edit_profile(profile.id)
				await _settle()
				_inspect(picker, densities[index])
				await _reach_action(picker, "%CreateButton")
				picker._on_guide_pressed()
				await _settle()
				_inspect(picker, densities[index])
				if style_id == "calm" and index == 0:
					_capture("guide")
				picker._on_privacy_pressed()
				await _settle()
				_inspect(picker, densities[index])
				picker._on_glossary_pressed()
				await _settle()
				_inspect(picker, densities[index])
				await _reach_action(picker, "%BackButton")
				# Resizing text must preserve the currently selected room and object state.
				main.open_profile(profile.id)
				room.tap(room.body("door"))
				Style.set_text_scale(1.25 if text_scale == 1.0 else 1.5)
				await _settle()
				_check(room.body("door").is_on, "text resizing retains room state")
				print("TYPE checked " + _label)
	_check(Style.set_text_scale(1.5, true) == OK, "text-size preference saves")
	var saved: ConfigFile = ConfigFile.new()
	_check(saved.load(Style.settings_path) == OK, "text-size preference loads")
	_check(Typography.text_scale(saved.get_value("text", "scale")) == 1.5, "text-size preference persists independently of profiles")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Style.settings_path))
	Style.settings_path = original_settings
	Style.set_text_scale(1.0)
	repo.delete_profile(profile.id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(repo.root))
	print("TYPOGRAPHY-PROBE %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

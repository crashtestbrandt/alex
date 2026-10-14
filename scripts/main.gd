extends Control
class_name Main
## Root coordinator: the adults' profile picker on one side, the child's home on the other. Opening a profile
## applies its style and hands it to the home; holding the home's profiles button comes back here.
##
## `--profile=<id>` after `--` opens straight into a profile, for a smoke run or a kiosk device.

@onready var _picker: ProfilePicker = %ProfilePicker
@onready var _home: ChildHome = %ChildHome

func _ready() -> void:
	get_window().size_changed.connect(_update_canvas)
	_update_canvas()
	_picker.profile_chosen.connect(open_profile)
	_home.profiles_requested.connect(show_picker)
	var requested: String = _profile_arg()
	if not requested.is_empty() and ProfileStore.load_profile(requested) != null:
		open_profile(requested)
	else:
		show_picker()

func show_picker() -> void:
	_picker.refresh()
	_picker.visible = true
	_home.visible = false

func open_profile(profile_id: String) -> void:
	var p: Profile = ProfileStore.load_profile(profile_id)
	if p == null:
		show_picker()
		return
	App.set_active_profile(p)
	Style.apply(StylePreset.load_by_id(p.style_id))
	_home.show_profile(p)
	_picker.visible = false
	_home.visible = true

func _update_canvas() -> void:
	var canvas: Vector2i = UiGeometry.canvas_size(get_window().size)
	if get_window().content_scale_size != canvas:
		get_window().content_scale_size = canvas

static func _profile_arg() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			return arg.substr("--profile=".length())
	return ""

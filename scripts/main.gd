extends Control
class_name Main
## Root coordinator: the adults' profile picker on one side, the child's home on the other. Opening a profile
## applies its style and hands it to the home; holding the home's profiles button comes back here.
##
## `--profile=<id>` after `--` opens straight into a profile, for a smoke run or a kiosk device.

@onready var _picker: ProfilePicker = %ProfilePicker
@onready var _home: ChildHome = %ChildHome

var _safe_rect: Rect2 = Rect2()
var _mobile: bool = false
var _safe_poll: float = 0.0
var _override_safe_area: bool = false
var _safe_pixels: Rect2 = Rect2()

func _ready() -> void:
	_mobile = DisplayServer.get_name() in ["Android", "iOS"]
	get_window().size_changed.connect(_update_canvas)
	get_window().focus_entered.connect(_update_safe_area)
	resized.connect(_update_safe_area.call_deferred)
	_update_canvas()
	_picker.profile_chosen.connect(open_profile)
	_home.profiles_requested.connect(show_picker)
	var requested: String = _profile_arg()
	if not requested.is_empty() and ProfileStore.load_profile(requested) != null:
		open_profile(requested)
	else:
		show_picker()
	set_process(_mobile)
	_update_safe_area.call_deferred()

func _process(delta: float) -> void:
	_safe_poll -= delta
	if _safe_poll <= 0.0:
		_safe_poll = 0.25
		_update_safe_area()

## Insets can change after a rotation or system-bar transition without a window-size signal.
func _update_safe_area() -> void:
	if not is_node_ready():
		return
	var mobile: bool = _mobile or _override_safe_area
	var pixels: Rect2 = _safe_pixels
	if not _override_safe_area:
		pixels = Rect2(DisplayServer.get_display_safe_area()) if _mobile else Rect2(Vector2.ZERO, Vector2(get_window().size))
	var transform_to_window: Transform2D = get_viewport().get_final_transform() * get_global_transform()
	var rect: Rect2 = SafeArea.to_canvas(pixels, Vector2(get_window().size), transform_to_window, mobile)
	rect = rect.intersection(Rect2(Vector2.ZERO, size))
	if rect == _safe_rect or not rect.has_area():
		return
	_safe_rect = rect
	SafeArea.fit_control(_picker, rect)
	_home.set_safe_area(rect)

func safe_area_rect() -> Rect2:
	return _safe_rect

## Instrumentation uses the same conversion and layout path as native phone insets.
func set_safe_area_override(pixels: Rect2) -> void:
	_override_safe_area = true
	_safe_pixels = pixels
	_update_safe_area()

func clear_safe_area_override() -> void:
	_override_safe_area = false
	_update_safe_area()

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
	_update_safe_area.call_deferred()

static func _profile_arg() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			return arg.substr("--profile=".length())
	return ""

extends Control
class_name Main
## Root coordinator: the adults' profile picker on one side, the child's home on the other. Opening a profile
## applies its style, hands it to the home and remembers it. The caregiver chord ([CaregiverGate]) comes back
## here.
##
## Launch reopens the profile opened last, or the picker when none is remembered. `--profile=<id>` after `--`
## opens a given profile instead, for a smoke run or a kiosk device.

const _HOME_SCENE: PackedScene = preload("res://scenes/child/home.tscn")

@onready var _picker: ProfilePicker = %ProfilePicker
@onready var _home: ChildHome = %ChildHome

var _safe_rect: Rect2 = Rect2()
var _mobile: bool = false
var _safe_poll: float = 0.0
var _override_safe_area: bool = false
var _safe_pixels: Rect2 = Rect2()
var _gate: CaregiverGate = CaregiverGate.new()

func _ready() -> void:
	_mobile = DisplayServer.get_name() in ["Android", "iOS"]
	get_window().size_changed.connect(_update_canvas)
	get_window().focus_entered.connect(_update_safe_area)
	resized.connect(_update_safe_area.call_deferred)
	_update_canvas()
	_picker.profile_chosen.connect(open_profile)
	_picker.profile_deleted.connect(_on_profile_deleted)
	_gate.name = "CaregiverGate"
	add_child(_gate)
	_gate.opened.connect(_on_caregiver_chord)
	var requested: String = _profile_arg()
	if requested.is_empty() or ProfileStore.load_profile(requested) == null:
		requested = ProfileStore.last_id()
	if requested.is_empty():
		show_picker()
	else:
		open_profile(requested)
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
	_gate.active = false
	_picker.refresh()
	_picker.visible = true
	_home.visible = false

func _on_caregiver_chord() -> void:
	_home.leave()
	show_picker()

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
	_gate.active = true
	if ProfileStore.remember(profile_id) != OK:
		printerr("Main: could not remember profile %s" % profile_id)

## Discard the deleted profile's controls, playback and recorder references as well as its disk files.
func _on_profile_deleted(profile_id: String) -> void:
	if App.active_profile == null or App.active_profile.id != profile_id:
		return
	App.set_active_profile(null)
	# Disconnect the old screen before the picker restores the previous style.
	_home.free()
	_home = _HOME_SCENE.instantiate() as ChildHome
	_home.name = "ChildHome"
	_home.visible = false
	add_child(_home)
	_home.owner = self
	_home.unique_name_in_owner = true
	_home.set_safe_area(_safe_rect)

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

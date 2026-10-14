extends Control
class_name ProfilePicker
## The adults' screen opens profiles, creates them from starter packs, and changes their saved looks.
## Style pills preview immediately. An existing profile changes only when Save is pressed.

signal profile_chosen(profile_id: String)

@onready var _profiles: GridContainer = %Profiles
@onready var _name_edit: SdfField = %NameEdit
@onready var _starter_bar: PillBar = %StarterBar
@onready var _style_bar: PillBar = %StyleBar
@onready var _create_button: SdfButton = %CreateButton
@onready var _status: Label = %Status
@onready var _heading: Label = %Heading
@onready var _new_heading: Label = %NewHeading
@onready var _starter_row: Control = %StarterRow
@onready var _gap: Control = %Gap
@onready var _back_button: SdfButton = %BackButton

var _starters: Array[Starter] = []
var _style_ids: PackedStringArray = PackedStringArray()
var _editing_id: String = ""
var _previous_style: StylePreset = null

func _ready() -> void:
	_create_button.pressed.connect(_on_create)
	_back_button.pressed.connect(_on_back)
	_name_edit.text_submitted.connect(_on_name_submitted)
	_fill_starters()
	_fill_styles()
	resized.connect(_layout_profiles)
	Style.changed.connect(func(_preset: StylePreset) -> void: _layout_profiles())
	refresh()

func _layout_profiles() -> void:
	_profiles.columns = UiGeometry.grid_columns(minf(size.x - 120.0, 704.0), _profiles.get_child_count(), 280.0, 12.0)

## Re-read the profiles on disk, with separate actions to open each profile or change its look.
func refresh() -> void:
	_editing_id = ""
	_previous_style = null
	_show_form(false)
	for child: Node in _profiles.get_children():
		_profiles.remove_child(child)
		child.queue_free()
	var ids: PackedStringArray = ProfileStore.list_ids()
	for profile_id: String in ids:
		var p: Profile = ProfileStore.load_profile(profile_id)
		if p == null:
			continue
		var card: VBoxContainer = VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_profiles.add_child(card)
		var button: SdfButton = SdfButton.new()
		button.text = p.display_name
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 88)
		button.pressed.connect(_on_profile_pressed.bind(profile_id))
		card.add_child(button)
		var edit: SdfButton = SdfButton.new()
		edit.text = "Change look"
		edit.shape = SdfButton.Shape.PILL
		edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		edit.pressed.connect(_on_edit_profile.bind(profile_id))
		card.add_child(edit)
	_profiles.visible = _profiles.get_child_count() > 0
	_status.text = "Create a profile to begin." if _profiles.get_child_count() == 0 else ""
	_status.visible = not _status.text.is_empty()
	_layout_profiles()
	_style_bar.set_active(_current_style_index())

func _fill_starters() -> void:
	_starter_bar.clear()
	_starters = Starter.list_all()
	var preferred: int = 0
	for i: int in _starters.size():
		var button: SdfButton = SdfButton.new()
		button.text = _starters[i].title
		_starter_bar.add_item(button)
		# Prefer the worked example over the blank start for a first run.
		if _starters[i].id == "home_routines":
			preferred = i
	_starter_bar.set_active(preferred)

func _fill_styles() -> void:
	_style_bar.clear()
	_style_ids = StylePreset.list_ids()
	for style_id: String in _style_ids:
		var button: SdfButton = SdfButton.new()
		button.text = StylePreset.load_by_id(style_id).display_name
		button.pressed.connect(_on_style_pressed.bind(style_id))
		_style_bar.add_item(button)
	_style_bar.set_active(_current_style_index())

## The pill for the style the app is wearing right now, or Calm when the current preset is not one on disk.
func _current_style_index() -> int:
	var current: int = _style_ids.find(Style.current.resource_path.get_file().get_basename())
	if current >= 0:
		return current
	return maxi(_style_ids.find("calm"), 0)

func _on_style_pressed(style_id: String) -> void:
	Style.apply(StylePreset.load_by_id(style_id))
	_style_bar.set_active(_current_style_index())

func _show_form(editing: bool) -> void:
	_new_heading.visible = not editing
	_name_edit.visible = not editing
	_starter_row.visible = not editing
	_gap.visible = not editing
	_back_button.visible = editing
	_create_button.text = "Save" if editing else "Create"
	if not editing:
		_heading.text = "Choose a profile"

func _on_edit_profile(profile_id: String) -> void:
	var profile: Profile = ProfileStore.load_profile(profile_id)
	if profile == null:
		return
	_editing_id = profile_id
	_previous_style = Style.current
	_profiles.hide()
	_status.hide()
	_show_form(true)
	_heading.text = "Look for %s" % profile.display_name
	_on_style_pressed(profile.style_id)
	_style_bar.items()[_current_style_index()].grab_focus()

func _on_back() -> void:
	if _previous_style != null:
		Style.apply(_previous_style)
	refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and not _editing_id.is_empty() and event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

func _save_look(style_id: String) -> void:
	# Reload before saving so previewing a look cannot overwrite other profile changes.
	var profile: Profile = ProfileStore.load_profile(_editing_id)
	if profile == null:
		_status.text = "Could not open the profile."
		return
	profile.style_id = style_id
	if ProfileStore.save_profile(profile) != OK:
		_status.text = "Could not save the look. Try again."
		return
	var profile_id: String = _editing_id
	refresh()
	profile_chosen.emit(profile_id)

func _on_profile_pressed(profile_id: String) -> void:
	profile_chosen.emit(profile_id)

func _on_name_submitted(_text: String) -> void:
	_on_create()

func _on_create() -> void:
	_status.visible = true
	var style_id: String = "calm"
	var style_index: int = _style_bar.active_index()
	if style_index >= 0 and style_index < _style_ids.size():
		style_id = _style_ids[style_index]
	if not _editing_id.is_empty():
		_save_look(style_id)
		return
	var name: String = _name_edit.text.strip_edges()
	if name.is_empty():
		_status.text = "Give the profile a name."
		_name_edit.grab_focus()
		return
	var starter: Starter = null
	var starter_index: int = _starter_bar.active_index()
	if starter_index >= 0 and starter_index < _starters.size():
		starter = _starters[starter_index]
	var p: Profile = ProfileStore.create_profile(name, starter, style_id)
	if p == null:
		_status.text = "Could not save the profile. Check the log."
		return
	_name_edit.text = ""
	refresh()
	profile_chosen.emit(p.id)

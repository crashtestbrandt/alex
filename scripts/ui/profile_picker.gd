extends Control
class_name ProfilePicker
## The adults' screen: pick a profile, or make one from a starter pack and a style. Everything a child sees
## is a consequence of what is chosen here (docs/profiles.md).

signal profile_chosen(profile_id: String)

@onready var _list: ItemList = %ProfileList
@onready var _open_button: Button = %OpenButton
@onready var _name_edit: LineEdit = %NameEdit
@onready var _starter_select: OptionButton = %StarterSelect
@onready var _style_select: OptionButton = %StyleSelect
@onready var _create_button: Button = %CreateButton
@onready var _status: Label = %Status

var _ids: PackedStringArray = PackedStringArray()
var _starters: Array[Starter] = []
var _style_ids: PackedStringArray = PackedStringArray()

func _ready() -> void:
	_open_button.pressed.connect(_on_open)
	_create_button.pressed.connect(_on_create)
	_list.item_activated.connect(_on_item_activated)
	_name_edit.text_submitted.connect(_on_name_submitted)
	_fill_starters()
	_fill_styles()
	refresh()

## Re-read the profiles on disk.
func refresh() -> void:
	_list.clear()
	_ids = ProfileStore.list_ids()
	for profile_id: String in _ids:
		var p: Profile = ProfileStore.load_profile(profile_id)
		_list.add_item(profile_id if p == null else p.display_name)
	_open_button.disabled = _ids.is_empty()
	_status.text = "No profiles yet. Make one below." if _ids.is_empty() else ""

func _fill_starters() -> void:
	_starter_select.clear()
	_starters = Starter.list_all()
	for s: Starter in _starters:
		_starter_select.add_item(s.title)
	# Prefer the worked example over the blank start for a first run.
	for i: int in _starters.size():
		if _starters[i].id == "home_routines":
			_starter_select.select(i)

func _fill_styles() -> void:
	_style_select.clear()
	_style_ids = StylePreset.list_ids()
	for style_id: String in _style_ids:
		_style_select.add_item(StylePreset.load_by_id(style_id).display_name)

func _on_open() -> void:
	var selected: PackedInt32Array = _list.get_selected_items()
	if selected.is_empty():
		_status.text = "Pick a profile first."
		return
	profile_chosen.emit(_ids[selected[0]])

func _on_item_activated(index: int) -> void:
	profile_chosen.emit(_ids[index])

func _on_name_submitted(_text: String) -> void:
	_on_create()

func _on_create() -> void:
	var name: String = _name_edit.text.strip_edges()
	if name.is_empty():
		_status.text = "Give the profile a name."
		return
	var starter: Starter = null
	if _starter_select.selected >= 0 and _starter_select.selected < _starters.size():
		starter = _starters[_starter_select.selected]
	var style_id: String = "calm"
	if _style_select.selected >= 0 and _style_select.selected < _style_ids.size():
		style_id = _style_ids[_style_select.selected]
	var p: Profile = ProfileStore.create_profile(name, starter, style_id)
	if p == null:
		_status.text = "Could not save the profile. Check the log."
		return
	_name_edit.text = ""
	refresh()
	profile_chosen.emit(p.id)

extends Control
class_name ProfilePicker
## The adults' screen opens, creates and permanently deletes profiles, changes their saved looks, and adds,
## removes and picks the entry scene for them. Style pills preview immediately. Saving a look, changing a
## scene or completing the delete hold changes a profile.
##
## It also shows two shipped pages ([PageText]), so nothing leaves the app to show them: the caregiver guide,
## GUIDE.md, and the privacy policy, PRIVACY.md, which Google Play's Families policy requires inside the app. Both
## open on a tap; the picker sits behind the caregiver chord.

signal profile_chosen(profile_id: String)
signal profile_deleted(profile_id: String)

enum Mode { PICK, CREATE, LOOK, POLICY, GUIDE }

const PRIVACY_URL: String = "https://github.com/crashtestbrandt/alex/blob/main/PRIVACY.md"
## The stages a scene can be at, in pill order. A bar's index is the stage less one.
const _STAGES: Array[NlaStage.Stage] = [
	NlaStage.Stage.ECHOLALIA, NlaStage.Stage.MITIGATION, NlaStage.Stage.SINGLE_WORDS,
	NlaStage.Stage.EARLY_GRAMMAR, NlaStage.Stage.COMPLEX_GRAMMAR, NlaStage.Stage.FULL_GRAMMAR,
]

@onready var _profiles: GridContainer = %Profiles
@onready var _name_edit: SdfField = %NameEdit
@onready var _starter_bar: PillBar = %StarterBar
@onready var _style_bar: PillBar = %StyleBar
@onready var _create_button: SdfButton = %CreateButton
@onready var _status: Label = %Status
@onready var _heading: Label = %Heading
@onready var _new_button: SdfButton = %NewProfileButton
@onready var _starter_row: BoxContainer = %StarterRow
@onready var _style_row: BoxContainer = %StyleRow
@onready var _actions: Control = %Actions
@onready var _sheet: SdfSheet = %Center
@onready var _back_button: SdfButton = %BackButton
@onready var _delete_section: VBoxContainer = %DeleteSection
@onready var _delete_button: HoldButton = %DeleteButton
@onready var _scene_section: VBoxContainer = %SceneSection
@onready var _scene_rows: VBoxContainer = %SceneRows
@onready var _stage_section: VBoxContainer = %StageSection
@onready var _stage_row: BoxContainer = %StageRow
@onready var _stage_bar: PillBar = %StageBar
@onready var _stage_name: Label = %StageName
@onready var _stage_model: Label = %StageModel
@onready var _notes_section: VBoxContainer = %NotesSection
@onready var _notes_edit: SdfTextArea = %NotesEdit
@onready var _guide_button: SdfButton = %GuideButton
@onready var _privacy_button: SdfButton = %PrivacyButton
@onready var _page: VBoxContainer = %Page
@onready var _build_stamp: Label = %BuildStamp

var _starters: Array[Starter] = []
var _style_ids: PackedStringArray = PackedStringArray()
var _editing_id: String = ""
var _previous_style: StylePreset = null
var _mode: Mode = Mode.PICK

func _ready() -> void:
	_create_button.pressed.connect(_on_create)
	_back_button.pressed.connect(_on_back)
	_new_button.pressed.connect(_on_new_profile)
	_delete_button.held.connect(_on_delete_held)
	_privacy_button.pressed.connect(_on_privacy_pressed)
	_guide_button.pressed.connect(_on_guide_pressed)
	_build_stamp.text = BuildStamp.current()
	_name_edit.text_submitted.connect(_on_name_submitted)
	_fill_starters()
	_fill_styles()
	_fill_stages()
	resized.connect(_layout_profiles)
	_starter_row.resized.connect(_layout_choices)
	_style_row.resized.connect(_layout_choices)
	_stage_row.resized.connect(_layout_choices)
	_scene_rows.resized.connect(_layout_choices)
	Style.changed.connect(func(_preset: StylePreset) -> void: _layout_choices.call_deferred())
	refresh()

func _layout_profiles() -> void:
	_profiles.columns = 1
	_layout_choices.call_deferred()

func _layout_choices() -> void:
	for row: BoxContainer in [_starter_row, _style_row, _stage_row]:
		_layout_choice_row(row)
	# A scene row puts its title over its buttons when the two do not fit side by side, and its stage bar
	# under its label the same way the profile's does.
	for entry: VBoxContainer in _scene_rows.get_children():
		var row: BoxContainer = entry.get_child(0) as BoxContainer
		var title: Label = row.get_child(0) as Label
		var actions: Control = row.get_child(1) as Control
		var font: Font = title.get_theme_font("font")
		var title_px: float = font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title.get_theme_font_size("font_size")).x
		row.vertical = row.size.x < title_px + 12.0 + actions.get_combined_minimum_size().x
		if entry.get_child_count() > 1:
			_layout_choice_row(entry.get_child(1) as BoxContainer)

## A label beside a pill bar, or over it when the two do not fit side by side.
func _layout_choice_row(row: BoxContainer) -> void:
	var label: Control = row.get_child(0) as Control
	var bar: PillBar = row.get_child(1) as PillBar
	var natural: float = label.get_combined_minimum_size().x + 12.0 + PillBar.PAD_PX * 2.0
	for button: SdfButton in bar.items():
		natural += button.get_combined_minimum_size().x + PillBar.GAP_PX
	row.vertical = row.size.x < natural - PillBar.GAP_PX
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

## Re-read the profiles on disk, with separate actions to open each profile or change its look.
func refresh() -> void:
	_editing_id = ""
	_previous_style = null
	for child: Node in _profiles.get_children():
		_profiles.remove_child(child)
		child.queue_free()
	var ids: PackedStringArray = ProfileStore.list_ids()
	for profile_id: String in ids:
		var p: Profile = ProfileStore.load_profile(profile_id)
		if p == null:
			continue
		var card: HBoxContainer = HBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 12)
		_profiles.add_child(card)
		var button: SdfButton = SdfButton.new()
		button.text = p.display_name
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 88)
		button.pressed.connect(_on_profile_pressed.bind(profile_id))
		card.add_child(button)
		var edit: SdfButton = SdfButton.new()
		edit.text = "Edit"
		edit.tooltip_text = "Change look or scenes, or delete profile"
		edit.shape = SdfButton.Shape.PILL
		edit.quiet = true
		edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		edit.pressed.connect(_on_edit_profile.bind(profile_id))
		card.add_child(edit)
	_show_mode(Mode.PICK if _profiles.get_child_count() > 0 else Mode.CREATE)
	_layout_profiles()
	_style_bar.set_active(_current_style_index())

func _fill_starters() -> void:
	_starter_bar.clear()
	_starters = Starter.list_all()
	var preferred: int = 0
	for i: int in _starters.size():
		var button: SdfButton = SdfButton.new()
		button.text = _starters[i].title
		button.pressed.connect(_on_starter_pressed.bind(i))
		_starter_bar.add_item(button)
		# Prefer the worked example over the blank start for a first run.
		if _starters[i].id == "home_routines":
			preferred = i
	_starter_bar.set_active(preferred)

## Whether the starter picked on the New profile form is a scene, and so takes a stage.
func _starter_is_scene() -> bool:
	var index: int = _starter_bar.active_index()
	return index >= 0 and index < _starters.size() and _starters[index].is_scene()

## The stage row belongs to the starter scene. A blank start has none.
func _on_starter_pressed(index: int) -> void:
	_starter_bar.set_active(index)
	_stage_section.visible = _mode == Mode.CREATE and _starter_is_scene()
	_layout_choices.call_deferred()

func _fill_styles() -> void:
	_style_bar.clear()
	_style_ids = StylePreset.list_ids()
	for style_id: String in _style_ids:
		var button: SdfButton = SdfButton.new()
		button.text = StylePreset.load_by_id(style_id).display_name
		button.pressed.connect(_on_style_pressed.bind(style_id))
		_style_bar.add_item(button)
	_style_bar.set_active(_current_style_index())

## The starter scene's stage on the New profile form: one numbered pill per stage, 1 to 6, so six fit one
## row on a phone. The lines under the bar carry the picked stage's name and what the adults model there.
func _fill_stages() -> void:
	_stage_bar.clear()
	for stage: NlaStage.Stage in _STAGES:
		var button: SdfButton = SdfButton.new()
		button.text = str(int(stage))
		button.tooltip_text = NlaStage.label(stage)
		button.pressed.connect(_on_stage_pressed.bind(stage))
		_stage_bar.add_item(button)
	_stage_bar.set_active(0)
	_show_stage(NlaStage.Stage.ECHOLALIA)

func _on_stage_pressed(stage: NlaStage.Stage) -> void:
	_stage_bar.set_active(int(stage) - 1)
	_show_stage(stage)

## The stage picked on the New profile form, from the bar's index.
func _picked_stage() -> NlaStage.Stage:
	return NlaStage.from_value(_stage_bar.active_index() + 1)

## The stage's name and its model line.
func _show_stage(stage: NlaStage.Stage) -> void:
	_stage_name.text = NlaStage.label(stage)
	_stage_model.text = NlaStage.models(stage)

## The pill for the style the app is wearing right now, or Calm when the current preset is not one on disk.
func _current_style_index() -> int:
	var current: int = _style_ids.find(Style.current.resource_path.get_file().get_basename())
	if current >= 0:
		return current
	return maxi(_style_ids.find("calm"), 0)

func _on_style_pressed(style_id: String) -> void:
	Style.apply(StylePreset.load_by_id(style_id))
	_style_bar.set_active(_current_style_index())

func _show_mode(mode: Mode) -> void:
	_mode = mode
	_profiles.visible = mode == Mode.PICK
	_new_button.visible = mode == Mode.PICK
	_name_edit.visible = mode == Mode.CREATE
	_starter_row.visible = mode == Mode.CREATE
	_style_row.visible = mode == Mode.CREATE or mode == Mode.LOOK
	_actions.visible = mode != Mode.PICK
	_delete_section.visible = mode == Mode.LOOK
	_scene_section.visible = mode == Mode.LOOK
	_stage_section.visible = mode == Mode.CREATE and _starter_is_scene()
	_notes_section.visible = mode == Mode.LOOK
	var reading: bool = mode == Mode.POLICY or mode == Mode.GUIDE
	_page.visible = reading
	_guide_button.visible = mode == Mode.PICK or mode == Mode.CREATE
	_privacy_button.visible = mode == Mode.PICK or mode == Mode.CREATE
	_back_button.visible = reading or (mode != Mode.PICK and _profiles.get_child_count() > 0)
	_create_button.visible = not reading
	_create_button.text = "Save" if mode == Mode.LOOK else "Create"
	match mode:
		Mode.CREATE:
			_heading.text = "New profile"
		Mode.POLICY:
			_heading.text = "Privacy policy"
		Mode.GUIDE:
			_heading.text = "Caregiver guide"
		_:
			_heading.text = "Choose a profile"
	_status.hide()
	_sheet.scroll_vertical = 0
	_layout_choices.call_deferred()

func _on_new_profile() -> void:
	_previous_style = Style.current
	_show_mode(Mode.CREATE)
	_name_edit.grab_focus()

func _on_edit_profile(profile_id: String) -> void:
	var profile: Profile = ProfileStore.load_profile(profile_id)
	if profile == null:
		return
	_editing_id = profile_id
	_previous_style = Style.current
	_show_mode(Mode.LOOK)
	_heading.text = "Edit %s" % profile.display_name
	_fill_scenes(profile)
	_notes_edit.text = profile.notes
	_on_style_pressed(profile.style_id)
	_style_bar.items()[_current_style_index()].grab_focus()

## One entry per shipped scene: its title, then Add, or Start here and Remove for a scene the profile holds.
## The scene Explore opens on reads Starts here and takes no tap. A held scene also gets a stage bar,
## Profile's then 1 to 6, that pins the scene to a stage of its own (`Profile.pin_scene_stage`).
func _fill_scenes(profile: Profile) -> void:
	for child: Node in _scene_rows.get_children():
		_scene_rows.remove_child(child)
		child.queue_free()
	var opens: Room = profile.explore_room()
	var entry: String = profile.scene_of(opens.id) if opens != null else ""
	for s: Starter in _starters:
		if not s.is_scene():
			continue
		var scene_entry: VBoxContainer = VBoxContainer.new()
		scene_entry.add_theme_constant_override("separation", 8)
		_scene_rows.add_child(scene_entry)
		var row: BoxContainer = BoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var title: Label = Label.new()
		title.text = s.title
		title.tooltip_text = s.description
		title.mouse_filter = Control.MOUSE_FILTER_PASS
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(title)
		var actions: HBoxContainer = HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_END
		actions.add_theme_constant_override("separation", 12)
		row.add_child(actions)
		if not profile.has_scene(s.id):
			actions.add_child(_scene_button("Add", false, _on_add_scene.bind(s)))
		else:
			if profile.scene_has_room(s.id):
				var here: bool = s.id == entry
				actions.add_child(_scene_button("Starts here" if here else "Start here", here, _on_entry_scene.bind(s)))
			actions.add_child(_scene_button("Remove", false, _on_remove_scene.bind(s)))
		scene_entry.add_child(row)
		if profile.has_scene(s.id):
			scene_entry.add_child(_scene_stage_row(profile, s))
			scene_entry.add_child(_scene_stage_line(profile, s))
	_layout_choices.call_deferred()

## A held scene's stage bar, 1 to 6. The active pill is the scene's stage.
func _scene_stage_row(profile: Profile, s: Starter) -> BoxContainer:
	var row: BoxContainer = BoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label: Label = Label.new()
	label.text = "Stage"
	label.custom_minimum_size = Vector2(120, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var bar: PillBar = PillBar.new()
	for stage: NlaStage.Stage in _STAGES:
		var button: SdfButton = SdfButton.new()
		button.text = str(int(stage))
		button.tooltip_text = NlaStage.label(stage)
		button.pressed.connect(_on_scene_stage.bind(s, stage))
		bar.add_item(button)
	bar.set_active(int(profile.stage_for_scene(s.id)) - 1)
	row.add_child(bar)
	return row

## The line under a held scene's stage bar: the stage's name and what the adults model there.
func _scene_stage_line(profile: Profile, s: Starter) -> Label:
	var line: Label = Label.new()
	line.theme_type_variation = &"HintLabel"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var at: NlaStage.Stage = profile.stage_for_scene(s.id)
	line.text = "%s. %s" % [NlaStage.label(at), NlaStage.models(at)]
	return line

func _on_scene_stage(s: Starter, stage: NlaStage.Stage) -> void:
	var change: Callable = func(p: Profile) -> bool: return p.set_scene_stage(s.id, stage)
	_change_scene(change, "%s says its stage %d phrases." % [s.title, stage], "Could not save the stage. Try again.")

func _scene_button(text: String, done: bool, on_pressed: Callable) -> SdfButton:
	var button: SdfButton = SdfButton.new()
	button.text = text
	button.disabled = done
	button.shape = SdfButton.Shape.PILL
	button.quiet = done
	button.pressed.connect(on_pressed)
	return button

func scene_rows() -> Array[Node]:
	return _scene_rows.get_children()

func _on_add_scene(s: Starter) -> void:
	_change_scene(s.add_to, "Added %s." % s.title, "Could not save the scene. Try again.")

func _on_remove_scene(s: Starter) -> void:
	var remove: Callable = func(p: Profile) -> bool: return p.remove_scene(s.id)
	_change_scene(remove, "Removed %s. Phrases you recorded stay." % s.title, "Could not remove the scene. Try again.")

func _on_entry_scene(s: Starter) -> void:
	var make_entry: Callable = func(p: Profile) -> bool: return p.set_entry(s.id)
	_change_scene(make_entry, "Explore opens on %s." % s.title, "Could not save the change. Try again.")

## Apply `change` to a fresh copy of the profile and save it. `change` returns false when it changed nothing.
func _change_scene(change: Callable, done: String, failed: String) -> void:
	if _editing_id.is_empty():
		return
	# Reload before changing, so a previewed look never rides along.
	var profile: Profile = ProfileStore.load_profile(_editing_id)
	if profile == null:
		_status.text = "Could not open the profile."
		_status.show()
		return
	var changed: bool = change.call(profile)
	if not changed:
		_fill_scenes(profile)
		return
	if ProfileStore.save_profile(profile) != OK:
		_status.text = failed
		_status.show()
		return
	_status.text = done
	_status.show()
	_fill_scenes(profile)

func _on_back() -> void:
	if _previous_style != null:
		Style.apply(_previous_style)
	refresh()

func _on_delete_held() -> void:
	if not is_visible_in_tree() or _mode != Mode.LOOK or _editing_id.is_empty():
		return
	var profile_id: String = _editing_id
	var err: Error = ProfileStore.delete_profile(profile_id)
	if err != OK:
		_status.text = "Could not delete everything. Try again."
		_status.show()
		_sheet.ensure_control_visible(_status)
		return
	profile_deleted.emit(profile_id)
	_on_back()
	if _mode == Mode.CREATE:
		_name_edit.grab_focus()
	else:
		_new_button.grab_focus()

func _on_privacy_pressed() -> void:
	_show_page(PageText.PRIVACY, Mode.POLICY)

func _on_guide_pressed() -> void:
	_show_page(PageText.GUIDE, Mode.GUIDE)

## Fill the page from the shipped Markdown at `path` and show it in `mode`.
func _show_page(path: String, mode: Mode) -> void:
	for child: Node in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	var headings: PackedStringArray = PageText.load_headings(path)
	var blocks: PackedStringArray = PageText.load_blocks(path)
	if mode == Mode.POLICY:
		blocks.push_back("This policy is also at %s" % PRIVACY_URL)
	for block: String in blocks:
		var label: Label = Label.new()
		label.text = block
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if headings.has(block):
			label.theme_type_variation = &"SectionLabel"
		_page.add_child(label)
	# Focus stays put: the sheet follows focus, and the page reads from the top.
	_show_mode(mode)

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and _mode != Mode.PICK and _back_button.visible and event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

## Save writes the look and the notes. Scenes and their stages were saved as they changed.
func _save_look(style_id: String) -> void:
	# Reload before saving so previewing a look cannot overwrite other profile changes.
	var profile: Profile = ProfileStore.load_profile(_editing_id)
	if profile == null:
		_status.text = "Could not open the profile."
		return
	profile.style_id = style_id
	profile.notes = _notes_edit.text
	if ProfileStore.save_profile(profile) != OK:
		_status.text = "Could not save the changes. Try again."
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
	# The starter scene's stage, picked on the form. A blank start has no scene to stage.
	if starter != null and starter.is_scene() and p.set_scene_stage(starter.id, _picked_stage()):
		if ProfileStore.save_profile(p) != OK:
			_status.text = "Could not save the stage. Try again."
			return
	_name_edit.text = ""
	refresh()
	profile_chosen.emit(p.id)

extends Control
class_name RecordOverlay
## The caregiver's one real task: record a gestalt in a familiar voice. Opened by holding a spot or tile.
## Hold the big button and say the phrase; let go; hear it back; keep it or try again.
##
## Low-risk by construction: nothing is written until Keep is pressed, the previous take is kept beside the
## new one, and the overlay closes itself after a short idle so a learner who wandered in is back on the
## board without having changed anything.

signal kept(gestalt: Gestalt)
signal closed

const IDLE_SECONDS: float = 20.0
const MIN_TAKE_SECONDS: float = 0.3

@onready var _phrase: Label = %Phrase
@onready var _status: Label = %Status
@onready var _record_button: Button = %RecordButton
@onready var _keep_button: Button = %KeepButton
@onready var _again_button: Button = %AgainButton
@onready var _cancel_button: Button = %CancelButton
@onready var _review_row: HFlowContainer = %ReviewRow
@onready var _recorder: Recorder = %Recorder
@onready var _preview: AudioStreamPlayer = %Preview
@onready var _sheet: SdfSheet = %Center

var _gestalt: Gestalt = null
var _profile: Profile = null
var _take: AudioStreamWAV = null
var _idle: float = 0.0
var _previous_focus: Control = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_record_button.button_down.connect(_on_record_down)
	_record_button.button_up.connect(_on_record_up)
	_keep_button.pressed.connect(_on_keep)
	_again_button.pressed.connect(_reset)
	_cancel_button.pressed.connect(close)
	get_window().focus_exited.connect(_cancel_capture)
	set_process(false)

func open(g: Gestalt, p: Profile) -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	_gestalt = g
	_profile = p
	_phrase.text = g.text
	_reset()
	visible = true
	_idle = 0.0
	set_process(true)
	if not _recorder.is_available():
		_status.text = "This device has no microphone available."
		_record_button.disabled = true
		(_record_button as SdfButton).refresh()
	_focus_controls()

func set_safe_area(rect: Rect2) -> void:
	SafeArea.fit_control(_sheet, rect)

func close() -> void:
	if _recorder.is_recording():
		_recorder.stop()
	_preview.stop()
	_take = null
	visible = false
	set_process(false)
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null
	closed.emit()

func _process(delta: float) -> void:
	if _recorder.is_recording() or _preview.playing:
		_idle = 0.0
		return
	_idle += delta
	if _idle >= IDLE_SECONDS:
		close()

func _input(event: InputEvent) -> void:
	if visible and (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey):
		_idle = 0.0
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func _cancel_capture() -> void:
	if _recorder.is_recording():
		_recorder.stop()
		_reset()

func _reset() -> void:
	_take = null
	_preview.stop()
	_review_row.visible = false
	_record_button.visible = true
	_record_button.disabled = false
	(_record_button as SdfButton).refresh()
	_status.text = "Hold the button, say it, let go."
	if visible:
		_focus_controls()

## Keyboard navigation stays in the caregiver overlay until Back or Escape closes it.
func _focus_controls() -> void:
	var controls: Array[Control] = []
	if _review_row.visible:
		controls.assign([_keep_button, _again_button])
	elif not _record_button.disabled:
		controls.push_back(_record_button)
	controls.push_back(_cancel_button)
	for index: int in controls.size():
		var control: Control = controls[index]
		var previous: NodePath = controls[(index - 1 + controls.size()) % controls.size()].get_path()
		var next: NodePath = controls[(index + 1) % controls.size()].get_path()
		control.focus_previous = previous
		control.focus_next = next
		control.focus_neighbor_left = previous
		control.focus_neighbor_top = previous
		control.focus_neighbor_right = next
		control.focus_neighbor_bottom = next
	controls[0].grab_focus()

func _on_record_down() -> void:
	_preview.stop()
	_recorder.start()
	_status.text = "Listening…"

func _on_record_up() -> void:
	if not _recorder.is_recording():
		return
	var take: AudioStreamWAV = _recorder.stop()
	if take == null or take.get_length() < MIN_TAKE_SECONDS:
		_status.text = "That was very short. Hold the button while you speak."
		return
	_take = take
	_preview.stream = take
	_preview.play()
	_status.text = "Here is how it sounds."
	_record_button.visible = false
	_review_row.visible = true
	_focus_controls()

func _on_keep() -> void:
	if _take == null:
		return
	var err: Error = Recorder.save(_take, _gestalt, ProfileStore.media_dir(_profile.id))
	if err != OK:
		_status.text = "Could not save the recording (%s)." % error_string(err)
		return
	err = ProfileStore.save_profile(_profile)
	if err != OK:
		_status.text = "Saved the sound, but not the profile (%s)." % error_string(err)
		return
	kept.emit(_gestalt)
	close()

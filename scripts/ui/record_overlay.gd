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
@onready var _review_row: HBoxContainer = %ReviewRow
@onready var _recorder: Recorder = %Recorder
@onready var _preview: AudioStreamPlayer = %Preview

var _gestalt: Gestalt = null
var _profile: Profile = null
var _take: AudioStreamWAV = null
var _idle: float = 0.0

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_record_button.button_down.connect(_on_record_down)
	_record_button.button_up.connect(_on_record_up)
	_keep_button.pressed.connect(_on_keep)
	_again_button.pressed.connect(_reset)
	_cancel_button.pressed.connect(close)
	set_process(false)

func open(g: Gestalt, p: Profile) -> void:
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

func close() -> void:
	if _recorder.is_recording():
		_recorder.stop()
	_preview.stop()
	visible = false
	set_process(false)
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

func _reset() -> void:
	_take = null
	_preview.stop()
	_review_row.visible = false
	_record_button.visible = true
	_record_button.disabled = false
	_status.text = "Hold the button, say it, let go."

func _on_record_down() -> void:
	_preview.stop()
	_recorder.start()
	_status.text = "Listening…"

func _on_record_up() -> void:
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

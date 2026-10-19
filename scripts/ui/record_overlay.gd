extends Control
class_name RecordOverlay
## The caregiver's one real task: record a phrase in a familiar voice. Opened by holding a spot, a tile, a
## chunk or the strip. The phrase shows as its pills, the same colored chunks the learner sees, plus one
## pill for the whole. A tap on a pill picks what the big button records; the whole is picked on open. Hold
## the big button and say it; let go; hear it back; keep it or try again. Keep saves the picked pill and
## leaves the overlay open on the phrase, so every chunk is recorded in one visit. A picked pill with a take
## offers a held button that removes it, and the OS voice says that part again.
##
## Low-risk by construction: nothing is written until Keep is pressed, the previous take is kept beside the
## new one, removal takes a hold, and the overlay closes itself after a short idle so a learner who wandered
## in is back on the board without having changed anything.

## A take was saved for `gestalt`, whole or for one of its chunks.
signal kept(gestalt: Gestalt)
## A take was removed from `gestalt`, whole or for one of its chunks.
signal removed(gestalt: Gestalt)
signal closed

const IDLE_SECONDS: float = 20.0
const MIN_TAKE_SECONDS: float = 0.3

@onready var _pills: HFlowContainer = %Pills
@onready var _status: Label = %Status
@onready var _record_button: Button = %RecordButton
@onready var _keep_button: Button = %KeepButton
@onready var _again_button: Button = %AgainButton
@onready var _remove_button: HoldButton = %RemoveButton
@onready var _cancel_button: Button = %CancelButton
@onready var _review_row: HFlowContainer = %ReviewRow
@onready var _recorder: Recorder = %Recorder
@onready var _preview: AudioStreamPlayer = %Preview
@onready var _sheet: SdfSheet = %Center

var _gestalt: Gestalt = null
var _profile: Profile = null
var _take: AudioStreamWAV = null
var _idle: float = 0.0
var _recording_name: bool = false
var _previous_focus: Control = null
var _cleanup_thread: Thread = null
var _cleanup_cancelled: bool = false
var _whole_pill: TakePill = null
var _chunk_pills: Array[TakePill] = []
var _selected: TakePill = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_record_button.button_down.connect(_on_record_down)
	_record_button.button_up.connect(_on_record_up)
	_keep_button.pressed.connect(_on_keep)
	_again_button.pressed.connect(_reset)
	_remove_button.held.connect(_on_remove_held)
	_cancel_button.pressed.connect(close)
	_recorder.permission_answered.connect(_on_permission_answered)
	_pills.resized.connect(_fit_pills)
	_sheet.resized.connect(_fit_pills)
	Style.fonts_changed.connect(_fit_pills.call_deferred)
	get_window().focus_exited.connect(_cancel_capture)
	set_process(false)

## Open on `g`: its whole pill, picked, and one pill per chunk when it has more than one. The name
## (`recording_name`) is whole only and keeps its own files.
func open(g: Gestalt, p: Profile, recording_name: bool = false) -> void:
	_begin(g, p, recording_name, true, not recording_name and g.chunks.size() > 1)

## Open on `chunks` alone, the first picked, with no whole pill: a held chunk in Build, or a held strip the
## bank does not hold as a phrase.
func open_chunks(chunks: PackedStringArray, p: Profile) -> void:
	_begin(ChunkBank.phrase(chunks), p, false, false, true)

func _begin(g: Gestalt, p: Profile, recording_name: bool, with_whole: bool, with_chunks: bool) -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	_recording_name = recording_name
	_gestalt = g
	_profile = p
	_build_pills(with_whole, with_chunks)
	_selected = null
	_select(_whole_pill if _whole_pill != null else _chunk_pills[0])
	visible = true
	_idle = 0.0
	set_process(true)
	if not _recorder.is_available():
		_status.text = "This device has no microphone available."
		_record_button.disabled = true
		(_record_button as SdfButton).refresh()
	elif not _recorder.ensure_permission():
		_status.text = "Allow the microphone to record."
		_record_button.disabled = true
		(_record_button as SdfButton).refresh()
	_focus_controls()

## The pills the overlay shows, in order. The whole first when there is one.
func pills() -> Array[TakePill]:
	var out: Array[TakePill] = []
	if _whole_pill != null:
		out.push_back(_whole_pill)
	out.append_array(_chunk_pills)
	return out

## What the big button records now.
func selected_pill() -> TakePill:
	return _selected

## The gestalt the overlay is open on. Transient (`ChunkBank.BUILD_ID`) for chunks alone.
func gestalt() -> Gestalt:
	return _gestalt

func _build_pills(with_whole: bool, with_chunks: bool) -> void:
	for child: Node in _pills.get_children():
		_pills.remove_child(child)
		child.queue_free()
	_whole_pill = null
	_chunk_pills.clear()
	if with_whole:
		_whole_pill = TakePill.new()
		_whole_pill.whole = true
		_whole_pill.chunk = _gestalt.text
		_whole_pill.recorded = not _gestalt.recording.is_empty()
		_whole_pill.pressed.connect(_select.bind(_whole_pill))
		_pills.add_child(_whole_pill)
	if with_chunks:
		for chunk: String in _gestalt.chunks:
			var pill: TakePill = TakePill.new()
			pill.chunk = chunk
			pill.recorded = ChunkTakes.has_take(chunk, _profile.chunk_takes)
			pill.pressed.connect(_select.bind(pill))
			_pills.add_child(pill)
			_chunk_pills.push_back(pill)
	_fit_pills()

## Every pill takes its text's width up to the row's width, and wraps past it.
func _fit_pills() -> void:
	# A long phrase must not expand the sheet and then use that expanded width as its own cap.
	var available: float = maxf(_sheet.size.x - 48.0 - SdfPanel.CONTENT_MARGIN_PX * 2.0, 1.0)
	for pill: TakePill in pills():
		pill.fit_width(clampf(_pills.size.x, 1.0, available))

## Pick `pill` for the big button. A take not yet kept is dropped; it was for the pill picked before.
func _select(pill: TakePill) -> void:
	if pill == _selected:
		return
	for other: TakePill in pills():
		other.selected = other == pill
	_selected = pill
	_reset()

func _on_permission_answered(granted: bool) -> void:
	if not visible:
		return
	if granted:
		_reset()
	else:
		_status.text = "Turn on the microphone for this app in Settings to record."

func set_safe_area(rect: Rect2) -> void:
	SafeArea.fit_control(_sheet, rect)

func close() -> void:
	_cleanup_cancelled = true
	if _recorder.is_recording():
		_recorder.stop()
	_preview.stop()
	_take = null
	visible = false
	set_process(_cleanup_thread != null)
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null
	closed.emit()

func _process(delta: float) -> void:
	if _cleanup_thread != null:
		_idle = 0.0
		if not _cleanup_thread.is_alive():
			var result: Variant = _cleanup_thread.wait_to_finish()
			_cleanup_thread = null
			if _cleanup_cancelled or not visible:
				if visible:
					_reset()
				else:
					set_process(false)
			elif result is AudioStreamWAV:
				var cleaned: AudioStreamWAV = result
				_review_take(cleaned)
			else:
				_review_take(null)
		return
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
	if _cleanup_thread != null:
		_cleanup_cancelled = true
	if _recorder.is_recording():
		_recorder.stop()
		_reset()

func _reset() -> void:
	_cleanup_cancelled = true
	_take = null
	_preview.stop()
	_review_row.visible = false
	_record_button.visible = true
	_record_button.disabled = _cleanup_thread != null
	(_record_button as SdfButton).refresh()
	var recorded: bool = _selected != null and _selected.recorded
	_remove_button.visible = recorded
	_status.text = "Recorded. Hold the button to record it again." if recorded else "Hold the button, say it, let go."
	if _cleanup_thread != null:
		_status.text = "Finishing the previous take…"
	if visible:
		_focus_controls()

## Keyboard navigation stays in the caregiver overlay until Back or Escape closes it. Focus lands on the
## action: the record button, or Keep while a take is under review.
func _focus_controls() -> void:
	var controls: Array[Control] = []
	for pill: TakePill in pills():
		controls.push_back(pill)
	var action: Control = _cancel_button
	if _review_row.visible:
		controls.push_back(_keep_button)
		controls.push_back(_again_button)
		action = _keep_button
	elif not _record_button.disabled:
		controls.push_back(_record_button)
		action = _record_button
	if _remove_button.visible:
		controls.push_back(_remove_button)
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
	action.grab_focus()

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
	_clean_take(take)

func _clean_take(take: AudioStreamWAV) -> void:
	_status.text = "Cleaning up the recording…"
	_record_button.disabled = true
	(_record_button as SdfButton).refresh()
	_cleanup_cancelled = false
	_cleanup_thread = Thread.new()
	var err: Error = _cleanup_thread.start(RecordingCleanup.process.bind(take))
	if err != OK:
		_cleanup_thread = null
		_review_take(RecordingCleanup.process(take))

func _review_take(take: AudioStreamWAV) -> void:
	_record_button.disabled = false
	(_record_button as SdfButton).refresh()
	if take == null:
		_status.text = "That was too quiet. Try again closer to the microphone."
		return
	_take = take
	_preview.stream = take
	_preview.play()
	_status.text = "Here is how it sounds."
	_record_button.visible = false
	_remove_button.visible = false
	_review_row.visible = true
	_focus_controls()

func _exit_tree() -> void:
	if _cleanup_thread != null:
		_cleanup_thread.wait_to_finish()

## Save the take for the picked pill and the profile, then stay open on the phrase.
func _on_keep() -> void:
	if _take == null or _selected == null:
		return
	var media_dir: String = ProfileStore.media_dir(_profile.id)
	var err: Error = OK
	if _recording_name:
		err = Recorder.save(_take, _gestalt, media_dir.path_join("name"))
		if err == OK:
			_gestalt.recording = "name/" + _gestalt.recording
			_profile.name_recording = _gestalt.recording
	elif _selected == _whole_pill:
		err = Recorder.save(_take, _gestalt, media_dir)
	else:
		err = ChunkTakes.save(_take, _selected.chunk, media_dir, _profile.chunk_takes)
	if err != OK:
		_status.text = "Could not save the recording (%s)." % error_string(err)
		return
	err = ProfileStore.save_profile(_profile)
	if err != OK:
		_status.text = "Saved the sound, but not the profile (%s)." % error_string(err)
		return
	_selected.recorded = true
	kept.emit(_gestalt)
	_reset()
	_status.text = "Kept."

## Remove the picked pill's take and its previous take, and save the profile. The OS voice says that part
## until a new take is kept.
func _on_remove_held() -> void:
	if _selected == null or not _selected.recorded:
		return
	var media_dir: String = ProfileStore.media_dir(_profile.id)
	var err: Error = OK
	if _recording_name:
		err = Recorder.remove_at(media_dir, _profile.name_recording)
		if err == OK:
			_profile.name_recording = ""
			_gestalt.recording = ""
	elif _selected == _whole_pill:
		err = Recorder.remove_at(media_dir, _gestalt.recording)
		if err == OK:
			_gestalt.recording = ""
	else:
		err = ChunkTakes.clear(_selected.chunk, media_dir, _profile.chunk_takes)
	if err != OK:
		_status.text = "Could not remove the recording (%s)." % error_string(err)
		return
	err = ProfileStore.save_profile(_profile)
	if err != OK:
		_status.text = "Removed the sound, but could not save the profile (%s)." % error_string(err)
		return
	_selected.recorded = false
	removed.emit(_gestalt)
	_reset()
	_status.text = "Removed. The device's own voice says it now."

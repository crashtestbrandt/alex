extends Node
class_name CaregiverGate
## Watches the learner's screen for the caregiver chord ([CaregiverChord]) and emits `opened` when one is
## held. Nothing on the learner's screen shows it. Input passes through untouched, so the room still pans and
## zooms under the fingers.
##
## When a chord starts forming, every node in `HOLD_GROUP` gets `cancel_hold()`, so a record hold under the
## first finger or the left button never fires before the chord does.

signal opened

## Nodes with a hold of their own: [HoldButton] and [RoomView].
const HOLD_GROUP: StringName = &"caregiver_cancels_hold"

## Off while the adults' picker shows.
var active: bool = false:
	set(value):
		active = value
		_chord.reset()
		_was_forming = false

var _chord: CaregiverChord = CaregiverChord.new()
var _was_forming: bool = false

func _ready() -> void:
	get_window().focus_exited.connect(_chord.reset)

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		_chord.touch(touch.index, touch.pressed, touch.position)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_chord.drag(drag.index, drag.position)
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		_chord.mouse_button(button.button_index, button.pressed)
	elif event is InputEventKey:
		var key: InputEventKey = event
		if key.keycode == KEY_ESCAPE and not key.echo:
			_chord.escape(key.pressed)
	var forming: bool = _chord.forming()
	if forming and not _was_forming:
		# Deferred, so a hold the same event starts in the GUI, which runs after _input, is cancelled too.
		get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED, HOLD_GROUP, "cancel_hold")
	_was_forming = forming

func _process(delta: float) -> void:
	if active and _chord.advance(delta):
		_was_forming = false
		opened.emit()

extends RefCounted
class_name CaregiverChord
## The gesture that leaves the learner's screen for the adults' picker. Any one of three chords, held for
## `HOLD_SECONDS`:
##
## - exactly three fingers, each within `STILL_PX` of where the chord formed;
## - the left and right mouse buttons together;
## - the Escape key.
##
## A fourth finger, a lifted finger or a finger that wanders breaks the chord. Pure state: [CaregiverGate]
## feeds it input and time.

const HOLD_SECONDS: float = 3.0
const FINGERS: int = 3
const STILL_PX: float = 48.0

## Where each finger is now, and where it was when the finger count last changed.
var _touches: Dictionary[int, Vector2] = {}
var _anchors: Dictionary[int, Vector2] = {}
var _wandered: bool = false
var _left: bool = false
var _right: bool = false
var _escape: bool = false
var _held_for: float = 0.0

func touch(index: int, pressed: bool, at: Vector2) -> void:
	if pressed:
		_touches[index] = at
	elif _touches.has(index):
		_touches.erase(index)
	else:
		return
	_anchors = _touches.duplicate()
	_wandered = false
	_held_for = 0.0

func drag(index: int, at: Vector2) -> void:
	if not _touches.has(index):
		return
	_touches[index] = at
	if at.distance_to(_anchors[index]) > STILL_PX:
		_wandered = true

func mouse_button(button: MouseButton, pressed: bool) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_left = pressed
	elif button == MOUSE_BUTTON_RIGHT:
		_right = pressed

## A press or release of Escape. The caller drops key echoes.
func escape(pressed: bool) -> void:
	_escape = pressed

## Whether a chord is down and counting.
func forming() -> bool:
	return (_touches.size() == FINGERS and not _wandered) or (_left and _right) or _escape

## Count `delta` seconds of the current chord. Returns true once, when a chord reaches `HOLD_SECONDS`; the
## chord then starts over from nothing, so a hand that stays down does not fire again.
func advance(delta: float) -> bool:
	if not forming():
		_held_for = 0.0
		return false
	_held_for += delta
	if _held_for < HOLD_SECONDS:
		return false
	reset()
	return true

## Forget every finger, button and key, for a window that lost focus or a screen that was hidden.
func reset() -> void:
	_touches.clear()
	_anchors.clear()
	_wandered = false
	_left = false
	_right = false
	_escape = false
	_held_for = 0.0

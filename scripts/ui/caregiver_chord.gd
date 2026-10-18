extends RefCounted
class_name CaregiverChord
## The gesture that leaves the learner's screen for the adults' picker. Any one of three chords, held for
## `HOLD_SECONDS`:
##
## - exactly three fingers;
## - the left and right mouse buttons together;
## - the Escape key.
##
## A fourth finger or a lifted finger breaks the chord. A hand whose center moves more than `STILL_PX` from
## where the count began starts the count again from where it is. The center averages the three fingers, so
## one finger rolling on the glass moves it a third as far. Pure state: [CaregiverGate] feeds it input and
## time, and shows `progress()` once `shows_progress()`.

## Which chord is down, in the order `source()` checks them.
enum Source { NONE, FINGERS, MOUSE, ESCAPE }

const HOLD_SECONDS: float = 3.0
const FINGERS: int = 3
const STILL_PX: float = 120.0
## How long a chord is held before its progress shows, so a brief three-finger touch shows nothing.
const SHOW_AFTER: float = 0.5

var _touches: Dictionary[int, Vector2] = {}
## The hand's center when the count last began.
var _anchor: Vector2 = Vector2.ZERO
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
	_restart()

func drag(index: int, at: Vector2) -> void:
	if not _touches.has(index):
		return
	_touches[index] = at
	if _center().distance_to(_anchor) > STILL_PX:
		_restart()

func mouse_button(button: MouseButton, pressed: bool) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_left = pressed
	elif button == MOUSE_BUTTON_RIGHT:
		_right = pressed

## A press or release of Escape. The caller drops key echoes.
func escape(pressed: bool) -> void:
	_escape = pressed

func source() -> Source:
	if _touches.size() == FINGERS:
		return Source.FINGERS
	if _left and _right:
		return Source.MOUSE
	if _escape:
		return Source.ESCAPE
	return Source.NONE

## Whether a chord is down and counting.
func forming() -> bool:
	return source() != Source.NONE

## Whether the current chord has been held long enough to show its progress.
func shows_progress() -> bool:
	return forming() and _held_for >= SHOW_AFTER

## How far the shown part of the hold has run, 0 when its progress first shows and 1 when the chord fires.
func progress() -> float:
	if not shows_progress():
		return 0.0
	return clampf((_held_for - SHOW_AFTER) / (HOLD_SECONDS - SHOW_AFTER), 0.0, 1.0)

## The smallest rect around every finger down, or an empty rect at the origin with none.
func hand() -> Rect2:
	var rect: Rect2 = Rect2()
	var first: bool = true
	for at: Vector2 in _touches.values():
		if first:
			rect = Rect2(at, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(at)
	return rect

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
	_anchor = Vector2.ZERO
	_left = false
	_right = false
	_escape = false
	_held_for = 0.0

func _restart() -> void:
	_anchor = _center()
	_held_for = 0.0

func _center() -> Vector2:
	if _touches.is_empty():
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	for at: Vector2 in _touches.values():
		sum += at
	return sum / float(_touches.size())

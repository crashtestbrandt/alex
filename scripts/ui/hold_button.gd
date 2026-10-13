extends Button
class_name HoldButton
## A button that fires only after being held. The adult-facing screens sit behind one so a stray tap from
## the child never leaves the board. `held` fires once per press, at `hold_seconds`.

signal held

@export_range(0.3, 5.0, 0.1) var hold_seconds: float = 2.0

var _down_for: float = -1.0
var _fired: bool = false

func _ready() -> void:
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	set_process(false)

func _process(delta: float) -> void:
	if _down_for < 0.0:
		return
	_down_for += delta
	if _down_for >= hold_seconds:
		_down_for = -1.0
		_fired = true
		set_process(false)
		held.emit()

## How far through the hold the current press is, 0 to 1. For a progress ring.
func progress() -> float:
	if _down_for < 0.0:
		return 0.0
	return clampf(_down_for / hold_seconds, 0.0, 1.0)

## Whether the press that just ended had already fired `held`. A subclass that also acts on `pressed` reads
## this to keep a hold from counting as a tap too.
func consumed_by_hold() -> bool:
	return _fired

func _on_down() -> void:
	_down_for = 0.0
	_fired = false
	set_process(true)

func _on_up() -> void:
	_down_for = -1.0
	set_process(false)

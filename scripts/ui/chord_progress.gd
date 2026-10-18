extends Control
class_name ChordProgress
## The bar [CaregiverGate] shows while a caregiver chord is held: a pill track in the style's surface color and
## a pill fill in its accent that grows to the track's end as the chord nears `HOLD_SECONDS`. It sits above
## the hand, or below it when the hand is near the top edge, and never takes input.

const BAR_SIZE: Vector2 = Vector2(320.0, 32.0)
## The gap between the track's edge and the fill.
const INSET_PX: float = 5.0
## The gap between the bar and the nearest finger, so a fingertip does not cover it.
const GAP_PX: float = 72.0
## The nearest the bar comes to a screen edge.
const MARGIN_PX: float = 24.0

var _track: SdfShape = SdfShape.new()
var _fill: SdfShape = SdfShape.new()
var _fraction: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BAR_SIZE
	_track.size = BAR_SIZE
	_track.radius_px = BAR_SIZE.y * 0.5
	_fill.position = Vector2(INSET_PX, INSET_PX)
	_fill.radius_px = BAR_SIZE.y * 0.5 - INSET_PX
	_fill.relief = 0.0
	add_child(_track)
	add_child(_fill)
	visible = false

## Show the bar at `fraction` of the way to the chord firing, placed beside `hand` on a screen of `screen`.
func show_at(fraction: float, hand: Rect2, screen: Rect2) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	var inner: Vector2 = BAR_SIZE - Vector2(INSET_PX, INSET_PX) * 2.0
	_fill.size = Vector2(lerpf(inner.y, inner.x, _fraction), inner.y)
	var preset: StylePreset = Style.current
	_track.fill = preset.surface
	_track.border_color = Color(preset.text, 0.25)
	_track.border_px = 1.0
	_fill.fill = preset.accent
	position = place(hand, screen)
	visible = true

## How full the bar is, or 0 while it is hidden.
func fraction() -> float:
	return _fraction if visible else 0.0

## Where the bar's top left goes: centered over `hand`, `GAP_PX` above it, or below it when above would cross
## the top margin, and kept `MARGIN_PX` inside `screen`.
static func place(hand: Rect2, screen: Rect2) -> Vector2:
	var at: Vector2 = Vector2(hand.get_center().x - BAR_SIZE.x * 0.5, hand.position.y - GAP_PX - BAR_SIZE.y)
	if at.y < screen.position.y + MARGIN_PX:
		at.y = hand.end.y + GAP_PX
	var lo: Vector2 = screen.position + Vector2(MARGIN_PX, MARGIN_PX)
	var hi: Vector2 = screen.end - BAR_SIZE - Vector2(MARGIN_PX, MARGIN_PX)
	return Vector2(clampf(at.x, lo.x, maxf(lo.x, hi.x)), clampf(at.y, lo.y, maxf(lo.y, hi.y)))

extends Control
class_name SpotView
## Draws one [Spot] from primitives and reacts to touch. A tap fires `tapped` and plays the reaction; a hold
## fires `held`, which the home turns into the caregiver's recording flow. The spot keeps an on/off state
## (door open, light on) so the same object says a different thing the second time.
##
## Everything here is drawn, never loaded: no art asset, no LFS, and every color comes from the style.

signal tapped(spot: Spot)
signal held(spot: Spot)

const HOLD_SECONDS: float = 2.0

var spot: Spot = null
## The toggled state: door open, light on, window bright.
var is_on: bool = false

var _down_for: float = -1.0
var _tween: Tween = null
var _rest_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_exited.connect(_cancel_press)
	set_process(false)

func setup(s: Spot) -> void:
	spot = s
	queue_redraw()

## Where the spot sits when nothing is moving it. RoomView sets this on layout.
func set_rest_position(p: Vector2) -> void:
	_rest_position = p
	position = p

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_down_for = 0.0
			set_process(true)
		elif _down_for >= 0.0:
			_down_for = -1.0
			set_process(false)
			tapped.emit(spot)
		accept_event()

func _process(delta: float) -> void:
	if _down_for < 0.0:
		return
	_down_for += delta
	if _down_for >= HOLD_SECONDS:
		_down_for = -1.0
		set_process(false)
		held.emit(spot)

func _cancel_press() -> void:
	_down_for = -1.0
	set_process(false)

## Play the spot's reaction and toggle its state. Reads the style's motion scale; at zero the state still
## toggles so the picture changes, with no movement.
func react() -> void:
	is_on = not is_on
	queue_redraw()
	var scale_factor: float = Style.motion_scale()
	if scale_factor <= 0.0:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	pivot_offset = size / 2.0
	match spot.reaction:
		Spot.Reaction.BOUNCE:
			var lift: float = size.y * 0.35
			_tween.tween_property(self, "position:y", _rest_position.y - lift, 0.18 * scale_factor) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			_tween.tween_property(self, "position:y", _rest_position.y, 0.28 * scale_factor) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		Spot.Reaction.OPEN:
			pivot_offset = Vector2(0.0, size.y / 2.0)
			_tween.tween_property(self, "scale:x", 0.35 if is_on else 1.0, 0.35 * scale_factor) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		Spot.Reaction.GLOW:
			_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12 * scale_factor)
			_tween.tween_property(self, "scale", Vector2.ONE, 0.25 * scale_factor)
		Spot.Reaction.SPIN:
			_tween.tween_property(self, "rotation", rotation + TAU, 0.7 * scale_factor) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		Spot.Reaction.WOBBLE:
			for i: int in 3:
				var swing: float = 0.18 * (1.0 - i / 3.0)
				_tween.tween_property(self, "rotation", swing, 0.09 * scale_factor)
				_tween.tween_property(self, "rotation", -swing, 0.09 * scale_factor)
			_tween.tween_property(self, "rotation", 0.0, 0.08 * scale_factor)
		Spot.Reaction.GROW:
			_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2 * scale_factor) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			_tween.tween_property(self, "scale", Vector2.ONE, 0.3 * scale_factor)

func _draw() -> void:
	if spot == null:
		return
	var preset: StylePreset = Style.current
	var w: float = size.x
	var h: float = size.y
	var m: float = minf(w, h)
	var c: Vector2 = size / 2.0
	var line: Color = preset.text
	match spot.kind:
		Spot.Kind.DOOR:
			var door: Rect2 = Rect2(w * 0.15, h * 0.04, w * 0.7, h * 0.94)
			draw_rect(door, preset.accent.darkened(0.25))
			draw_rect(door, line, false, 3.0)
			draw_rect(Rect2(w * 0.25, h * 0.12, w * 0.5, h * 0.3), line, false, 2.0)
			draw_rect(Rect2(w * 0.25, h * 0.5, w * 0.5, h * 0.36), line, false, 2.0)
			draw_circle(Vector2(w * 0.76, h * 0.52), m * 0.05, preset.surface)
		Spot.Kind.LIGHT:
			draw_line(Vector2(c.x, 0.0), Vector2(c.x, h * 0.3), line, 3.0)
			var bulb: Vector2 = Vector2(c.x, h * 0.58)
			if is_on:
				draw_circle(bulb, m * 0.42, Color(1.0, 0.85, 0.3, 0.18))
				draw_circle(bulb, m * 0.34, Color(1.0, 0.85, 0.3, 0.35))
				draw_circle(bulb, m * 0.26, Color(1.0, 0.9, 0.45))
			else:
				draw_circle(bulb, m * 0.26, preset.surface)
			draw_arc(bulb, m * 0.26, 0.0, TAU, 48, line, 3.0)
			draw_rect(Rect2(c.x - m * 0.1, h * 0.3, m * 0.2, h * 0.06), line)
		Spot.Kind.WINDOW:
			var frame: Rect2 = Rect2(w * 0.08, h * 0.08, w * 0.84, h * 0.84)
			draw_rect(frame, Color(0.62, 0.82, 0.95) if is_on else Color(0.16, 0.22, 0.4))
			if is_on:
				draw_circle(Vector2(w * 0.68, h * 0.32), m * 0.12, Color(1.0, 0.9, 0.45))
			else:
				draw_circle(Vector2(w * 0.68, h * 0.3), m * 0.08, Color(0.95, 0.95, 0.85))
			draw_rect(frame, line, false, 4.0)
			draw_line(Vector2(c.x, frame.position.y), Vector2(c.x, frame.end.y), line, 3.0)
			draw_line(Vector2(frame.position.x, c.y), Vector2(frame.end.x, c.y), line, 3.0)
		Spot.Kind.BALL:
			draw_circle(c, m * 0.45, preset.accent)
			draw_arc(c, m * 0.3, -0.6, 2.2, 32, preset.surface, m * 0.08)
			draw_arc(c, m * 0.45, 0.0, TAU, 48, line, 2.0)
		Spot.Kind.BED:
			draw_rect(Rect2(w * 0.05, h * 0.45, w * 0.9, h * 0.35), preset.accent)
			draw_rect(Rect2(w * 0.05, h * 0.45, w * 0.9, h * 0.35), line, false, 2.0)
			draw_rect(Rect2(w * 0.1, h * 0.3, w * 0.3, h * 0.18), preset.surface)
			draw_rect(Rect2(w * 0.1, h * 0.3, w * 0.3, h * 0.18), line, false, 2.0)
			draw_rect(Rect2(w * 0.02, h * 0.15, w * 0.06, h * 0.75), line)
			draw_rect(Rect2(w * 0.92, h * 0.35, w * 0.06, h * 0.55), line)
		Spot.Kind.CUP:
			var body: Rect2 = Rect2(w * 0.2, h * 0.3, w * 0.5, h * 0.55)
			draw_rect(body, preset.surface)
			draw_rect(body, line, false, 3.0)
			draw_arc(Vector2(w * 0.7, h * 0.55), m * 0.14, -PI / 2.0, PI / 2.0, 24, line, 3.0)
			if is_on:
				for i: int in 3:
					var sx: float = w * (0.3 + 0.15 * i)
					draw_line(Vector2(sx, h * 0.24), Vector2(sx + w * 0.04, h * 0.1), line.lerp(preset.surface, 0.5), 2.0)
		Spot.Kind.SHOES:
			for i: int in 2:
				var ox: float = w * (0.08 + 0.46 * i)
				var shoe: PackedVector2Array = _ellipse(Vector2(ox + w * 0.2, h * 0.6), w * 0.2, h * 0.16)
				draw_colored_polygon(shoe, preset.accent)
				draw_polyline(shoe, line, 2.0)
				draw_circle(Vector2(ox + w * 0.14, h * 0.42), m * 0.09, preset.accent)
		Spot.Kind.TUB:
			draw_rect(Rect2(w * 0.08, h * 0.38, w * 0.84, h * 0.42), preset.surface)
			draw_rect(Rect2(w * 0.08, h * 0.38, w * 0.84, h * 0.42), line, false, 3.0)
			if is_on:
				draw_colored_polygon(_ellipse(Vector2(c.x, h * 0.42), w * 0.36, h * 0.07), Color(0.6, 0.8, 0.95))
			draw_rect(Rect2(w * 0.14, h * 0.8, w * 0.08, h * 0.12), line)
			draw_rect(Rect2(w * 0.78, h * 0.8, w * 0.08, h * 0.12), line)
		Spot.Kind.STAR:
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in 10:
				var r: float = m * (0.46 if i % 2 == 0 else 0.2)
				var a: float = -PI / 2.0 + i * PI / 5.0
				pts.push_back(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, preset.accent)
			pts.push_back(pts[0])
			draw_polyline(pts, line, 2.0)
		_:
			draw_circle(c, m * 0.45, preset.accent)
			draw_arc(c, m * 0.45, 0.0, TAU, 48, line, 2.0)

static func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 32:
		var a: float = i * TAU / 32.0
		pts.push_back(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

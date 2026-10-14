extends RefCounted
class_name SafeArea
## Native mobile bounds are in window pixels. Layout uses the inverse canvas transform, never a second scale.

## A minimum edge inset also protects rounded corners when the OS reports no cutout on that edge.
const EDGE_FRACTION: float = 0.06

static func to_canvas(reported: Rect2, window_size: Vector2, canvas_to_window: Transform2D, mobile: bool) -> Rect2:
	var window: Rect2 = Rect2(Vector2.ZERO, window_size)
	var safe: Rect2 = reported.intersection(window) if reported.has_area() else window
	if not safe.has_area():
		safe = window
	if mobile:
		var guard: float = ceilf(minf(window_size.x, window_size.y) * EDGE_FRACTION)
		var edges: Rect2 = window.grow(-guard)
		var guarded: Rect2 = safe.intersection(edges)
		if guarded.has_area():
			safe = guarded
	return canvas_to_window.affine_inverse() * safe

static func fit_control(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Preserve requested edges while containers recompute their minimum size after rotation.
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y

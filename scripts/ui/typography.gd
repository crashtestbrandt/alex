extends RefCounted
class_name Typography
## Type sizes in logical mobile points/dp, converted to the app's layout canvas by Style.
## Apple HIG defaults and Material's body/title hierarchy inform these roles (docs/ui.md).
const BODY: int = 14
const SUPPORTING: int = 12
const CONTROL: int = 14
const TITLE: int = 20
const SECTION: int = 17
const METADATA: int = 11
const PHRASE: int = 16
const CAPTION: int = 18
const TEXT_SCALES: Array[float] = [1.0, 1.25, 1.5, 2.0]

static func canvas_units_per_point(window: Vector2i, canvas: Vector2i, density: float) -> float:
	return maxf(density, 0.1) * float(canvas.y) / maxf(window.y, 1.0)

static func font_size(points: int, units: float, preset_scale: float, text_scale: float) -> int:
	return maxi(1, ceili(maxf(points * preset_scale, METADATA) * units * clampf(text_scale, 1.0, 2.0)))

static func text_scale(value: Variant) -> float:
	if not (value is float or value is int):
		return 1.0
	var scale_value: float = value
	return clampf(scale_value, 1.0, 2.0) if is_finite(scale_value) else 1.0

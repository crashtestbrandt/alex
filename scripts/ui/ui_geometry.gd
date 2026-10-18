extends RefCounted
class_name UiGeometry
## The few numbers behind the interface's shapes, pure (docs/ui.md). Corners are concentric: a control inside a
## bar or a panel takes the outer radius minus the padding between them, so the two curves share a center.

## A corner never gets tighter than this; below it the rim and the border stop reading.
const MIN_RADIUS_PX: float = 4.0

## Keep small screens legible without imposing a landscape canvas on portrait devices.
static func canvas_size(window_size: Vector2i, density: float = 1.0) -> Vector2i:
	var logical_size: Vector2 = Vector2(window_size) / maxf(density, 0.1)
	var short_side: float = maxf(minf(logical_size.x, logical_size.y), 1.0)
	var scale_factor: float = maxf(640.0 / short_side, 1.0)
	return Vector2i(logical_size * scale_factor)

## Columns are limited by both the touch floor and a readable phrase width.
static func grid_columns(width: float, count: int, tile_floor: float, gap: float = 16.0) -> int:
	var tile_width: float = maxf(tile_floor, 280.0)
	var capacity: int = clampi(int((width + gap) / (tile_width + gap)), 1, maxi(1, mini(count, 4)))
	var rows: int = ceili(float(maxi(count, 1)) / capacity)
	return ceili(float(maxi(count, 1)) / rows)

## The radius of a shape nested `padding_px` inside one of `outer_radius_px`.
static func concentric(outer_radius_px: float, padding_px: float) -> float:
	return maxf(outer_radius_px - padding_px, MIN_RADIUS_PX)

## A pill is a rounded rectangle whose radius is half its shorter side.
static func pill_radius(size: Vector2) -> float:
	return minf(size.x, size.y) / 2.0

## The radius a rounded shape of `size` uses when the style asks for `preset_radius_px`: the preset's, capped
## so the two corners of the shorter side never overlap.
static func rounded_radius(size: Vector2, preset_radius_px: float) -> float:
	return clampf(preset_radius_px, MIN_RADIUS_PX, maxf(pill_radius(size), MIN_RADIUS_PX))

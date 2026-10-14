extends RefCounted
class_name CameraFraming
## The camera math for a room, pure so it can be unit-tested: which vertical extent fits a view, how far the
## camera stands for that framing, where an orbit may go, and where a camera at an azimuth and elevation
## sits (docs/geometry.md "Views").
##
## The learner's views are all perspective: front, side and top are three angles on one orbit, and a room in
## perspective reads as a room. The frame extent is the vertical span of the world, in meters, visible at
## the room's center; the camera's distance follows from it. An orthographic camera would take the extent as
## its `size` directly, which is what an editor's plan and elevation views will do.

enum View {
	FRONT = 0,
	SIDE = 1,
	TOP = 2,
	TURN = 3,
}

const FOV_DEG: float = 50.0
const MARGIN: float = 1.12
const AZIMUTH_LIMIT_DEG: float = 65.0
const ELEVATION_MIN_DEG: float = 6.0
const ELEVATION_MAX_DEG: float = 80.0
const FRONT_ELEVATION_DEG: float = 18.0
const TURN_AZIMUTH_DEG: float = 32.0
const TURN_ELEVATION_DEG: float = 24.0
## How far the touch floor may pull the frame in past the fit. Past this the room is visibly cropped, and the
## pick radius, which already guarantees the floor, covers what the camera cannot.
const MAX_PULL_IN: float = 1.15

## Azimuth and elevation in degrees for a view. Azimuth 0 faces the back wall from the open front; the side
## view sits at the orbit's azimuth limit and the top view at its elevation limit, so every view is a place
## the orbit can reach.
static func view_angles(view: View) -> Vector2:
	match view:
		View.SIDE:
			return Vector2(AZIMUTH_LIMIT_DEG, FRONT_ELEVATION_DEG)
		View.TOP:
			return Vector2(0.0, ELEVATION_MAX_DEG)
		View.TURN:
			return Vector2(TURN_AZIMUTH_DEG, TURN_ELEVATION_DEG)
		_:
			return Vector2(0.0, FRONT_ELEVATION_DEG)

## The vertical extent that fits the whole room box seen from `azimuth_deg` and `elevation_deg` on a viewport
## of `aspect` (width over height), with the margin. The box's silhouette is projected along the view axis.
static func fit_extent(azimuth_deg: float, elevation_deg: float, room: Vector3, aspect: float) -> float:
	var a: float = maxf(aspect, 0.1)
	var az: float = deg_to_rad(azimuth_deg)
	var el: float = deg_to_rad(elevation_deg)
	var footprint_depth: float = room.z * absf(cos(az)) + room.x * absf(sin(az))
	var footprint_width: float = room.x * absf(cos(az)) + room.z * absf(sin(az))
	var vertical: float = room.y * cos(el) + footprint_depth * sin(el)
	return maxf(vertical, footprint_width / a) * MARGIN

## The largest extent at which an object `smallest_m` across still projects to `floor_px` on a viewport
## `viewport_height_px` tall. Zero when there is no such object.
static func floor_extent(smallest_m: float, viewport_height_px: float, floor_px: float) -> float:
	if smallest_m <= 0.0 or viewport_height_px <= 0.0 or floor_px <= 0.0:
		return 0.0
	return smallest_m * viewport_height_px / floor_px

## The extent a view uses: the fit, pulled in when the smallest spot would fall under the touch floor, by at
## most `MAX_PULL_IN`.
static func frame_extent(azimuth_deg: float, elevation_deg: float, room: Vector3, aspect: float, smallest_m: float, viewport_height_px: float, floor_px: float) -> float:
	var fit: float = fit_extent(azimuth_deg, elevation_deg, room, aspect)
	var floor_limit: float = floor_extent(smallest_m, viewport_height_px, floor_px)
	if floor_limit <= 0.0 or floor_limit >= fit:
		return fit
	return maxf(floor_limit, fit / MAX_PULL_IN)

## How far a perspective camera stands from the target so the target plane spans `extent` vertically.
static func perspective_distance(extent: float, fov_deg: float) -> float:
	return extent / (2.0 * tan(deg_to_rad(fov_deg) / 2.0))

## The extent the full viewport needs so that a band `safe_height_px` tall out of `viewport_height_px` shows
## `safe_extent`. Floating controls take the rest.
static func full_extent(safe_extent: float, safe_height_px: float, viewport_height_px: float) -> float:
	if safe_height_px <= 0.0:
		return safe_extent
	return safe_extent * viewport_height_px / safe_height_px

## Camera3D's `v_offset` that lands the target `offset_px` below the viewport's center: a positive offset
## raises the camera, which moves everything down on the screen by the same share of the extent.
static func center_offset(offset_px: float, viewport_height_px: float, extent: float) -> float:
	if viewport_height_px <= 0.0:
		return 0.0
	return offset_px / viewport_height_px * extent

## How many pixels an object `size_m` across covers at the target plane.
static func projected_px(size_m: float, extent: float, viewport_height_px: float) -> float:
	if extent <= 0.0:
		return 0.0
	return size_m / extent * viewport_height_px

static func clamp_orbit(azimuth_deg: float, elevation_deg: float) -> Vector2:
	return Vector2(clampf(azimuth_deg, -AZIMUTH_LIMIT_DEG, AZIMUTH_LIMIT_DEG),
		clampf(elevation_deg, ELEVATION_MIN_DEG, ELEVATION_MAX_DEG))

## The unit direction from the target toward a camera at `azimuth_deg` and `elevation_deg`.
static func orbit_direction(azimuth_deg: float, elevation_deg: float) -> Vector3:
	var az: float = deg_to_rad(azimuth_deg)
	var el: float = deg_to_rad(elevation_deg)
	return Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))

## The camera's up vector at the same angles: always perpendicular to the view direction, and continuous
## from the front view through to straight down, where it points at the back wall.
static func orbit_up(azimuth_deg: float, elevation_deg: float) -> Vector3:
	var az: float = deg_to_rad(azimuth_deg)
	var el: float = deg_to_rad(elevation_deg)
	return Vector3(-sin(az) * sin(el), cos(el), -cos(az) * sin(el))

static func camera_transform(target: Vector3, azimuth_deg: float, elevation_deg: float, distance: float) -> Transform3D:
	var direction: Vector3 = orbit_direction(azimuth_deg, elevation_deg)
	var up: Vector3 = orbit_up(azimuth_deg, elevation_deg)
	var origin: Vector3 = target + direction * distance
	return Transform3D(Basis.looking_at(-direction, up), origin)

## Fit actual world points in perspective, including the depth-dependent camera offset.
## Orthographic silhouette estimates clip near objects on portrait and overhead views.
static func points_extent(points: Array[Vector3], target: Vector3, azimuth: float, elevation: float, viewport: Vector2, safe: Rect2) -> float:
	var direction: Vector3 = orbit_direction(azimuth, elevation)
	var up: Vector3 = orbit_up(azimuth, elevation)
	var right: Vector3 = up.cross(direction)
	var tangent: float = tan(deg_to_rad(FOV_DEG) / 2.0)
	var height: float = maxf(viewport.y, 1.0)
	var half_width: float = maxf(safe.size.x / 2.0, 1.0)
	var half_band: float = maxf(safe.size.y / 2.0, 1.0)
	var distance: float = 0.1
	for point: Vector3 in points:
		var delta: Vector3 = point - target
		var depth: float = delta.dot(direction)
		var x: float = delta.dot(right)
		var y: float = delta.dot(up)
		distance = maxf(distance, (x * height / (2.0 * tangent) + (safe.end.x - viewport.x / 2.0) * depth) / half_width)
		distance = maxf(distance, (-x * height / (2.0 * tangent) + (viewport.x / 2.0 - safe.position.x) * depth) / half_width)
		distance = maxf(distance, (y * height / (2.0 * tangent) + (height / 2.0 - safe.position.y) * depth) / half_band)
		distance = maxf(distance, (-y * height / (2.0 * tangent) + (safe.end.y - height / 2.0) * depth) / half_band)
	return distance * 2.0 * tangent

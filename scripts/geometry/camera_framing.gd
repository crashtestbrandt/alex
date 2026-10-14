extends RefCounted
class_name CameraFraming
## The camera math for a room, pure so it can be unit-tested: which vertical extent fits a view, how far the
## camera stands for that framing, how far a pan and a zoom may go, and where a camera sits for an orbit
## angle or for a look around from the room's center (docs/geometry.md "Views").
##
## The learner's views are all perspective. Front and Top are two angles on one orbit, each with a clamped
## pan and zoom on top; Tilt stands at the room's center and turns in place, its zoom a field-of-view
## change. The frame extent is the vertical span of the world, in meters, visible at the room's center; the
## camera's distance follows from it. An orthographic camera would take the extent as its `size` directly,
## which is what an editor's plan and elevation views will do.

enum View {
	FRONT = 0,
	TOP = 1,
	TILT = 2,
}

const FOV_DEG: float = 50.0
const MARGIN: float = 1.12
const ELEVATION_MAX_DEG: float = 80.0
const FRONT_ELEVATION_DEG: float = 18.0
## Zoom on an orbit view: 1 is the fit, and the frame may close in to a third of it.
const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 3.0
## Tilt's pitch, in degrees, positive up. Yaw is free.
const TILT_PITCH_MIN_DEG: float = -40.0
const TILT_PITCH_MAX_DEG: float = 30.0
## Tilt's zoom: 1 is `FOV_DEG`, under 1 is wider, over 1 is narrower.
const TILT_ZOOM_MIN: float = 0.75
const TILT_ZOOM_MAX: float = 2.0

## Azimuth and elevation in degrees for an orbit view. Azimuth 0 faces the back wall from the open front and
## the top view sits at the elevation limit. Tilt is not on the orbit and takes the front's angles here.
static func view_angles(view: View) -> Vector2:
	match view:
		View.TOP:
			return Vector2(0.0, ELEVATION_MAX_DEG)
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

static func clamp_zoom(zoom: float) -> float:
	return clampf(zoom, ZOOM_MIN, ZOOM_MAX)

## The pan, in meters on the target plane, that keeps a frame zoomed by `zoom` inside the fitted frame. The
## fitted frame is `extent` tall and `extent * aspect` wide, so at zoom 1 no pan is possible.
static func clamp_pan(pan: Vector2, extent: float, aspect: float, zoom: float) -> Vector2:
	var z: float = clamp_zoom(zoom)
	var reach: Vector2 = Vector2(extent * maxf(aspect, 0.0), extent) * 0.5 * (1.0 - 1.0 / z)
	return Vector2(clampf(pan.x, -reach.x, reach.x), clampf(pan.y, -reach.y, reach.y))

## Meters on the target plane per pixel of a viewport `viewport_height_px` tall at `zoom`.
static func meters_per_px(extent: float, viewport_height_px: float, zoom: float) -> float:
	if viewport_height_px <= 0.0:
		return 0.0
	return extent / clamp_zoom(zoom) / viewport_height_px

## The pan after a zoom from `zoom_from` to `zoom_to` that keeps the world point under `point_px` fixed.
## `point_px` is measured from the viewport's center, screen down positive; the pan is right and up.
static func zoom_about(pan: Vector2, extent: float, viewport_height_px: float, point_px: Vector2, zoom_from: float, zoom_to: float) -> Vector2:
	var before: float = meters_per_px(extent, viewport_height_px, zoom_from)
	var after: float = meters_per_px(extent, viewport_height_px, zoom_to)
	var shift: Vector2 = Vector2(point_px.x, -point_px.y) * (before - after)
	return pan + shift

## Yaw wrapped to a half turn either way, pitch inside Tilt's limits.
static func clamp_tilt(yaw_deg: float, pitch_deg: float) -> Vector2:
	return Vector2(wrapf(yaw_deg, -180.0, 180.0), clampf(pitch_deg, TILT_PITCH_MIN_DEG, TILT_PITCH_MAX_DEG))

static func clamp_tilt_zoom(zoom: float) -> float:
	return clampf(zoom, TILT_ZOOM_MIN, TILT_ZOOM_MAX)

## Tilt's vertical field of view at `zoom`, in degrees.
static func tilt_fov(zoom: float) -> float:
	return FOV_DEG / clamp_tilt_zoom(zoom)

## The direction a Tilt camera looks: yaw 0 faces the back wall, positive yaw turns right, positive pitch
## looks up.
static func tilt_direction(yaw_deg: float, pitch_deg: float) -> Vector3:
	var yaw: float = deg_to_rad(yaw_deg)
	var pitch: float = deg_to_rad(pitch_deg)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))

## A camera standing at `origin`, turned to `yaw_deg` and `pitch_deg`, upright.
static func tilt_transform(origin: Vector3, yaw_deg: float, pitch_deg: float) -> Transform3D:
	var direction: Vector3 = tilt_direction(yaw_deg, pitch_deg)
	return Transform3D(Basis.looking_at(direction, Vector3.UP), origin)

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

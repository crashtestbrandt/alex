extends UnitTest
## [CameraFraming]: the fit, the pan and zoom limits, Tilt's limits and basis, and the orbit basis are what
## the room view relies on, all pure.

const ROOM: Vector3 = Vector3(4.0, 2.6, 3.0)

func test_front_fit_covers_width_and_height() -> void:
	var wide: float = CameraFraming.fit_extent(0.0, 0.0, ROOM, 2.0)
	assert_almost_eq(wide, 2.6 * CameraFraming.MARGIN, 0.001, "a wide viewport is limited by the room's height")
	var tall: float = CameraFraming.fit_extent(0.0, 0.0, ROOM, 1.0)
	assert_almost_eq(tall, 4.0 * CameraFraming.MARGIN, 0.001, "a square viewport is limited by the room's width")

func test_elevation_adds_the_floor_to_the_fit() -> void:
	var flat: float = CameraFraming.fit_extent(0.0, 0.0, ROOM, 2.0)
	var raised: float = CameraFraming.fit_extent(0.0, 45.0, ROOM, 2.0)
	assert_true(raised > flat, "looking down shows floor depth too")
	var top: float = CameraFraming.fit_extent(0.0, 90.0, ROOM, 2.0)
	assert_almost_eq(top, 3.0 * CameraFraming.MARGIN, 0.001, "straight down is the depth")

func test_perspective_distance_matches_the_extent() -> void:
	var d: float = CameraFraming.perspective_distance(2.0, 90.0)
	assert_almost_eq(d, 1.0, 0.0001, "a 90 degree camera sees twice its distance")

func test_zoom_is_clamped_between_the_fit_and_its_limit() -> void:
	assert_almost_eq(CameraFraming.clamp_zoom(0.2), CameraFraming.ZOOM_MIN, 0.0001, "never wider than the fit")
	assert_almost_eq(CameraFraming.clamp_zoom(50.0), CameraFraming.ZOOM_MAX, 0.0001, "never closer than the limit")
	assert_almost_eq(CameraFraming.clamp_zoom(2.0), 2.0, 0.0001, "inside the range it is itself")

func test_room_silhouette_follows_the_view() -> void:
	var target: Vector3 = Vector3(0.0, 1.0, 0.0)
	var level: Rect2 = CameraFraming.room_silhouette(ROOM, target, 0.0, 0.0)
	assert_almost_eq(level.size.x, 4.0, 0.0001, "level from the front, the room's width")
	assert_almost_eq(level.size.y, 2.6, 0.0001, "and its height")
	assert_almost_eq(level.position.y, -1.0, 0.0001, "the floor is a meter under the target")
	assert_almost_eq(level.get_center().x, 0.0, 0.0001, "centered across")
	var raised: Rect2 = CameraFraming.room_silhouette(ROOM, target, 0.0, 18.0)
	assert_almost_eq(raised.size.y, 2.6 * cos(deg_to_rad(18.0)) + 3.0 * sin(deg_to_rad(18.0)), 0.0001, "raised, the floor's depth joins the height")
	var top: Rect2 = CameraFraming.room_silhouette(ROOM, target, 0.0, 90.0)
	assert_almost_eq(top.size.y, 3.0, 0.0001, "straight down, the depth")
	assert_almost_eq(top.size.x, 4.0, 0.0001, "and the width")

func test_pan_stays_inside_the_room() -> void:
	var room: Rect2 = Rect2(-2.0, -1.0, 4.0, 2.6)
	var wide: Vector2 = CameraFraming.clamp_pan(Vector2(5.0, -5.0), Vector2(6.0, 4.0), room)
	assert_true(wide.is_equal_approx(Vector2.ZERO), "a frame larger than the room does not pan")
	var half: Vector2 = CameraFraming.clamp_pan(Vector2(100.0, -100.0), Vector2(2.0, 1.3), room)
	assert_almost_eq(half.x, 1.0, 0.0001, "the frame's right edge stops at the right wall")
	assert_almost_eq(half.y, -1.0 + 0.65, 0.0001, "the frame's bottom edge stops at the floor")
	var other: Vector2 = CameraFraming.clamp_pan(Vector2(-100.0, 100.0), Vector2(2.0, 1.3), room)
	assert_almost_eq(other.x, -1.0, 0.0001, "and the left wall")
	assert_almost_eq(other.y, 1.6 - 0.65, 0.0001, "and the ceiling")
	var inside: Vector2 = CameraFraming.clamp_pan(Vector2(0.3, -0.2), Vector2(2.0, 1.3), room)
	assert_true(inside.is_equal_approx(Vector2(0.3, -0.2)), "inside the room it is itself")
	var off_center: Rect2 = Rect2(-2.0, 0.5, 4.0, 2.6)
	var rest: Vector2 = CameraFraming.clamp_pan(Vector2.ZERO, Vector2(2.0, 2.5), off_center)
	assert_true(rest.is_equal_approx(Vector2.ZERO), "rest stays in range when the room sits off the target")
	var slight: Vector2 = CameraFraming.clamp_pan(Vector2(0.0, -0.1), Vector2(2.0, 2.5), off_center)
	assert_almost_eq(slight.y, 0.0, 0.0001, "but never past rest on the far side")
	var tall: Vector2 = CameraFraming.clamp_pan(Vector2(0.0, 100.0), Vector2(2.0, 1.0), off_center)
	assert_almost_eq(tall.y, 3.1 - 0.5, 0.0001, "the top edge stops at the ceiling")

func test_meters_per_px_follows_the_zoom() -> void:
	assert_almost_eq(CameraFraming.meters_per_px(3.0, 600.0, 1.0), 0.005, 0.0001, "the extent over the height")
	assert_almost_eq(CameraFraming.meters_per_px(3.0, 600.0, 2.0), 0.0025, 0.0001, "half as much per pixel zoomed in")
	assert_almost_eq(CameraFraming.meters_per_px(3.0, 0.0, 2.0), 0.0, 0.0001, "no height, nothing")

func test_zoom_about_a_point_keeps_it_fixed() -> void:
	var extent: float = 3.0
	var height: float = 600.0
	var point: Vector2 = Vector2(120.0, -90.0)
	var pan: Vector2 = CameraFraming.zoom_about(Vector2.ZERO, extent, height, point, 1.0, 2.0)
	# The world point under the finger was `point` pixels from the center at zoom 1. After the zoom it must sit
	# at the same pixels, so the pan moves by its displacement at both zooms.
	var before: Vector2 = Vector2(point.x, -point.y) * CameraFraming.meters_per_px(extent, height, 1.0)
	var after: Vector2 = Vector2(point.x, -point.y) * CameraFraming.meters_per_px(extent, height, 2.0)
	assert_true(pan.is_equal_approx(before - after), "the pan takes up the difference")
	assert_true(pan.x > 0.0 and pan.y > 0.0, "zooming in on the upper right pans up and right")
	var centered: Vector2 = CameraFraming.zoom_about(Vector2(0.3, 0.2), extent, height, Vector2.ZERO, 1.0, 3.0)
	assert_true(centered.is_equal_approx(Vector2(0.3, 0.2)), "zooming about the center leaves the pan alone")

func test_tilt_is_clamped_in_pitch_and_wraps_in_yaw() -> void:
	var down: Vector2 = CameraFraming.clamp_tilt(0.0, -200.0)
	assert_almost_eq(down.y, CameraFraming.TILT_PITCH_MIN_DEG, 0.0001, "never further down")
	var up: Vector2 = CameraFraming.clamp_tilt(0.0, 200.0)
	assert_almost_eq(up.y, CameraFraming.TILT_PITCH_MAX_DEG, 0.0001, "never further up")
	assert_almost_eq(CameraFraming.clamp_tilt(190.0, 0.0).x, -170.0, 0.0001, "yaw wraps past a half turn")
	assert_almost_eq(CameraFraming.clamp_tilt(-190.0, 0.0).x, 170.0, 0.0001, "and back the other way")
	assert_almost_eq(CameraFraming.clamp_tilt(45.0, 10.0).x, 45.0, 0.0001, "inside the range it is itself")

func test_tilt_zoom_narrows_the_view_within_limits() -> void:
	var a: float = 16.0 / 9.0
	assert_true(CameraFraming.tilt_fov(2.0, a) < CameraFraming.tilt_fov(1.0, a), "zooming in narrows the view")
	var rest: float = tan(deg_to_rad(CameraFraming.tilt_fov(1.0, a)) / 2.0)
	var double: float = tan(deg_to_rad(CameraFraming.tilt_fov(2.0, a)) / 2.0)
	assert_almost_eq(double, rest / 2.0, 0.0001, "zoom 2 shows half the span")
	assert_almost_eq(CameraFraming.tilt_fov(100.0, a), CameraFraming.tilt_fov(CameraFraming.TILT_ZOOM_MAX, a), 0.0001, "never narrower than the limit")
	assert_almost_eq(CameraFraming.tilt_fov(0.01, a), CameraFraming.tilt_fov(1.0, a), 0.0001, "the resting view is the widest")

func test_tilt_rest_keeps_its_diagonal_on_any_screen() -> void:
	var diagonal: float = tan(deg_to_rad(CameraFraming.TILT_DIAGONAL_DEG) / 2.0)
	for a: float in [390.0 / 844.0, 3.0 / 4.0, 1.0, 4.0 / 3.0, 844.0 / 390.0]:
		var v: float = tan(deg_to_rad(CameraFraming.tilt_fov(1.0, a)) / 2.0)
		assert_almost_eq(Vector2(v * a, v).length(), diagonal, 0.0001, "the corners span the diagonal at %.2f" % a)
		assert_true(CameraFraming.tilt_fov(1.0, a) < 120.0, "the view is still a lens at %.2f" % a)
	var portrait: float = CameraFraming.tilt_fov(1.0, 390.0 / 844.0)
	var landscape: float = CameraFraming.tilt_fov(1.0, 844.0 / 390.0)
	assert_true(portrait > landscape, "a portrait screen sees taller")
	var landscape_wide: float = rad_to_deg(2.0 * atan(tan(deg_to_rad(landscape) / 2.0) * 844.0 / 390.0))
	assert_almost_eq(landscape_wide, portrait, 0.0001, "turning the device swaps the two angles")
	assert_true(landscape >= CameraFraming.FOV_DEG, "never tighter than the room's lens on a phone")

func test_tilt_camera_turns_in_place_and_stays_upright() -> void:
	var origin: Vector3 = Vector3(0.0, 1.4, 0.0)
	var back: Transform3D = CameraFraming.tilt_transform(origin, 0.0, 0.0)
	assert_true(back.origin.is_equal_approx(origin), "stands where it is put")
	assert_almost_eq((-back.basis.z).dot(Vector3.FORWARD), 1.0, 0.0001, "yaw 0 faces the back wall")
	assert_almost_eq(back.basis.y.dot(Vector3.UP), 1.0, 0.0001, "level is upright")
	var right: Transform3D = CameraFraming.tilt_transform(origin, 90.0, 0.0)
	assert_almost_eq((-right.basis.z).dot(Vector3.RIGHT), 1.0, 0.0001, "yaw 90 faces the right wall")
	var front: Transform3D = CameraFraming.tilt_transform(origin, 180.0, 0.0)
	assert_almost_eq((-front.basis.z).dot(Vector3.BACK), 1.0, 0.0001, "yaw 180 faces the open front")
	var up: Transform3D = CameraFraming.tilt_transform(origin, 0.0, CameraFraming.TILT_PITCH_MAX_DEG)
	assert_true((-up.basis.z).y > 0.0, "positive pitch looks up")
	assert_true(up.basis.y.y > 0.0, "and the camera stays upright")
	var down: Transform3D = CameraFraming.tilt_transform(origin, 0.0, CameraFraming.TILT_PITCH_MIN_DEG)
	assert_true((-down.basis.z).y < 0.0, "negative pitch looks down")
	assert_true(down.basis.y.y > 0.0, "upright looking down too")
	for yaw: float in [-170.0, -45.0, 30.0, 120.0]:
		var xf: Transform3D = CameraFraming.tilt_transform(origin, yaw, -20.0)
		assert_almost_eq(xf.origin.distance_to(origin), 0.0, 0.0001, "never leaves the center at yaw %.0f" % yaw)
		assert_true(xf.basis.x.y < 0.0001 and xf.basis.x.y > -0.0001, "no roll at yaw %.0f" % yaw)

func test_every_orbit_view_is_above_the_floor_and_at_the_open_front() -> void:
	for view: CameraFraming.View in [CameraFraming.View.FRONT, CameraFraming.View.TOP]:
		var angles: Vector2 = CameraFraming.view_angles(view)
		assert_almost_eq(angles.x, 0.0, 0.0001, "view %d faces the back wall" % view)
		assert_true(angles.y > 0.0 and angles.y <= CameraFraming.ELEVATION_MAX_DEG, "view %d is above the floor" % view)
	var tilt: Vector2 = CameraFraming.view_angles(CameraFraming.View.TILT)
	assert_true(tilt.is_equal_approx(CameraFraming.view_angles(CameraFraming.View.FRONT)), "tilt takes the front's angles on the orbit")

func test_camera_basis_is_continuous_and_looks_at_the_target() -> void:
	var target: Vector3 = Vector3(0.0, 1.3, 0.0)
	var previous: Basis = Basis.IDENTITY
	for i: int in 17:
		var el: float = 0.0 + 80.0 * i / 16.0
		var xf: Transform3D = CameraFraming.camera_transform(target, 20.0, el, 5.0)
		var forward: Vector3 = -xf.basis.z
		assert_almost_eq(forward.dot((target - xf.origin).normalized()), 1.0, 0.0001, "looks at the target at %.0f" % el)
		assert_true(xf.basis.y.y >= 0.0, "up never flips at %.0f" % el)
		if i > 0:
			assert_true(xf.basis.y.dot(previous.y) > 0.9, "up turns smoothly at %.0f" % el)
		previous = xf.basis
	var front: Transform3D = CameraFraming.camera_transform(target, 0.0, 0.0, 5.0)
	assert_almost_eq(front.origin.z, 5.0, 0.0001, "azimuth 0 stands at the open front")
	assert_almost_eq(front.basis.y.dot(Vector3.UP), 1.0, 0.0001, "level view is upright")

func test_safe_band_scales_the_extent_and_shifts_the_center() -> void:
	assert_almost_eq(CameraFraming.full_extent(3.0, 600.0, 800.0), 4.0, 0.0001, "a 600 px band of 800 needs a third more")
	assert_almost_eq(CameraFraming.full_extent(3.0, 0.0, 800.0), 3.0, 0.0001, "no band, no change")
	assert_almost_eq(CameraFraming.center_offset(100.0, 800.0, 4.0), 0.5, 0.0001, "100 px down of 800 is half a meter of 4, camera up")
	assert_almost_eq(CameraFraming.center_offset(0.0, 800.0, 4.0), 0.0, 0.0001, "centered")

func test_perspective_points_fit_asymmetric_safe_bands() -> void:
	var points: Array[Vector3] = []
	var box: AABB = AABB(Vector3(-2.0, 0.0, -1.5), Vector3(4.0, 2.2, 3.0))
	for corner: int in 8:
		points.push_back(box.get_endpoint(corner))
	var target: Vector3 = Vector3(0.0, 0.924, 0.0)
	for viewport: Vector2 in [Vector2(640, 1385), Vector2(1385, 640), Vector2(1280, 800), Vector2(1920, 1080)]:
		for edges: Vector2 in [Vector2(16, 32), Vector2(120, 32), Vector2(240, 32), Vector2(32, 240)]:
			var safe: Rect2 = Rect2(edges.x, 160.0, viewport.x - edges.x - edges.y, viewport.y - 340.0)
			for view: CameraFraming.View in [CameraFraming.View.FRONT, CameraFraming.View.TOP]:
				var angles: Vector2 = CameraFraming.view_angles(view)
				var extent: float = CameraFraming.points_extent(points, target, angles.x, angles.y, viewport, safe)
				var distance: float = CameraFraming.perspective_distance(extent, CameraFraming.FOV_DEG)
				var direction: Vector3 = CameraFraming.orbit_direction(angles.x, angles.y)
				var up: Vector3 = CameraFraming.orbit_up(angles.x, angles.y)
				var right: Vector3 = up.cross(direction)
				var offset: float = CameraFraming.center_offset(safe.get_center().y - viewport.y / 2.0, viewport.y, extent)
				var offset_x: float = CameraFraming.center_offset(safe.get_center().x - viewport.x / 2.0, viewport.y, extent)
				for point: Vector3 in points:
					var delta: Vector3 = point - target
					var depth: float = distance - delta.dot(direction)
					assert_true(depth > 0.0, "point is in front of camera")
					var scale_px: float = viewport.y / (2.0 * tan(deg_to_rad(CameraFraming.FOV_DEG) / 2.0) * depth)
					var screen: Vector2 = viewport / 2.0 + Vector2(delta.dot(right) + offset_x, offset - delta.dot(up)) * scale_px
					assert_true(safe.grow(0.01).has_point(screen), "perspective corner fits %s %s" % [viewport, view])

extends UnitTest
## [CameraFraming]: the fit, the touch floor, the orbit limits and the camera basis are what the room view
## relies on, all pure.

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

func test_floor_pulls_the_frame_in() -> void:
	var fit: float = CameraFraming.fit_extent(0.0, 18.0, ROOM, 1.6)
	var tiny: float = CameraFraming.frame_extent(0.0, 18.0, ROOM, 1.6, 0.3, 600.0, 160.0)
	assert_true(tiny < fit, "a small spot pulls the camera in")
	assert_almost_eq(tiny, fit / CameraFraming.MAX_PULL_IN, 0.0001, "a tiny spot pulls in only to the limit")
	var medium: float = CameraFraming.frame_extent(0.0, 18.0, ROOM, 1.6, 0.9, 600.0, 160.0)
	assert_true(medium < fit and medium > tiny, "a medium spot pulls in less")
	assert_almost_eq(CameraFraming.projected_px(0.9, medium, 600.0), 160.0, 0.001, "and projects exactly at the floor")
	var big: float = CameraFraming.frame_extent(0.0, 18.0, ROOM, 1.6, 2.0, 600.0, 160.0)
	assert_almost_eq(big, fit, 0.0001, "a big spot leaves the fit alone")
	assert_almost_eq(CameraFraming.frame_extent(0.0, 18.0, ROOM, 1.6, 0.0, 600.0, 160.0), fit, 0.0001, "no spots, the fit")

func test_perspective_distance_matches_the_extent() -> void:
	var d: float = CameraFraming.perspective_distance(2.0, 90.0)
	assert_almost_eq(d, 1.0, 0.0001, "a 90 degree camera sees twice its distance")

func test_orbit_is_clamped() -> void:
	var c: Vector2 = CameraFraming.clamp_orbit(500.0, -30.0)
	assert_almost_eq(c.x, CameraFraming.AZIMUTH_LIMIT_DEG, 0.0001, "azimuth limit")
	assert_almost_eq(c.y, CameraFraming.ELEVATION_MIN_DEG, 0.0001, "never below the floor")
	assert_almost_eq(CameraFraming.clamp_orbit(0.0, 200.0).y, CameraFraming.ELEVATION_MAX_DEG, 0.0001, "never past straight down")

func test_every_view_is_within_the_orbit() -> void:
	for v: int in CameraFraming.View.values():
		var view: CameraFraming.View = v as CameraFraming.View
		var angles: Vector2 = CameraFraming.view_angles(view)
		var clamped: Vector2 = CameraFraming.clamp_orbit(angles.x, angles.y)
		assert_almost_eq(clamped.x, angles.x, 0.0001, "view %d azimuth is reachable" % v)
		assert_almost_eq(clamped.y, angles.y, 0.0001, "view %d elevation is reachable" % v)

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

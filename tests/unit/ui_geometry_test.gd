extends UnitTest
## [UiGeometry]: concentric corners, pills, the cap on a rounded radius, and the scroll drag distance.

func test_concentric_subtracts_the_padding() -> void:
	assert_almost_eq(UiGeometry.concentric(40.0, 8.0), 32.0, 0.0001, "outer minus padding")
	assert_almost_eq(UiGeometry.concentric(6.0, 8.0), UiGeometry.MIN_RADIUS_PX, 0.0001, "never below the floor")

func test_pill_is_half_the_short_side() -> void:
	assert_almost_eq(UiGeometry.pill_radius(Vector2(200.0, 60.0)), 30.0, 0.0001, "wide pill")
	assert_almost_eq(UiGeometry.pill_radius(Vector2(60.0, 60.0)), 30.0, 0.0001, "a square pill is a circle")

func test_rounded_radius_is_capped_by_the_short_side() -> void:
	assert_almost_eq(UiGeometry.rounded_radius(Vector2(300.0, 100.0), 18.0), 18.0, 0.0001, "the preset's radius")
	assert_almost_eq(UiGeometry.rounded_radius(Vector2(300.0, 20.0), 18.0), 10.0, 0.0001, "capped at half the short side")
	assert_almost_eq(UiGeometry.rounded_radius(Vector2(300.0, 100.0), 0.0), UiGeometry.MIN_RADIUS_PX, 0.0001, "never sharp")

func test_canvas_preserves_aspect_and_legibility() -> void:
	for viewport: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1280, 800), Vector2i(2560, 1080)]:
		var canvas: Vector2i = UiGeometry.canvas_size(viewport)
		assert_true(mini(canvas.x, canvas.y) >= 639, "short side remains legible %s" % viewport)
		assert_almost_eq(float(canvas.x) / canvas.y, float(viewport.x) / viewport.y, 0.002, "aspect is preserved")
	assert_eq(UiGeometry.canvas_size(Vector2i(1280, 800)), Vector2i(1280, 800), "desktop retains its density")

func test_columns_fit_without_shrinking_touch_targets() -> void:
	for width: float in [320.0, 592.0, 720.0, 1232.0, 2500.0]:
		for floor_px: float in [160.0, 200.0, 340.0]:
			var columns: int = UiGeometry.grid_columns(width, 12, floor_px)
			assert_true(columns >= 1 and columns <= 4, "bounded column count")
			assert_true(columns == 1 or columns * maxf(floor_px, 280.0) + (columns - 1) * 16 <= width, "columns fit the width")
	assert_eq(UiGeometry.grid_columns(1200, 1, 160), 1, "one tile uses one column")
	assert_eq(UiGeometry.grid_columns(600, 0, 160), 1, "empty grid remains valid")

func test_a_scroll_waits_for_the_drag_distance() -> void:
	# A deadzone of 0 lets a resting finger's jitter start a scroll, which cancels a hold (#39).
	var deadzone: int = ProjectSettings.get_setting("gui/common/default_scroll_deadzone", 0)
	assert_eq(deadzone, int(RoomView.DRAG_PX), "scroll containers and the room share one drag distance")

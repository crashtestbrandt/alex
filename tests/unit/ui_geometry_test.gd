extends UnitTest
## [UiGeometry]: concentric corners, pills, and the cap on a rounded radius.

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

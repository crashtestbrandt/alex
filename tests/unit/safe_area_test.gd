extends UnitTest
## Native pixel bounds become logical bounds through the actual canvas transform.

func test_high_density_and_canvas_translation() -> void:
	var native: Rect2 = Rect2(0, 177, 1170, 2253)
	var transform: Transform2D = Transform2D(Vector2(3, 0), Vector2(0, 3), Vector2(12, 6))
	var safe: Rect2 = SafeArea.to_canvas(native, Vector2(1170, 2532), transform, true)
	assert_true(safe.is_equal_approx(Rect2(59.0 / 3.0, 57, 1028.0 / 3.0, 751)), "pixel insets convert once, including canvas origin")

func test_landscape_cutout_can_change_sides_without_resize() -> void:
	var size: Vector2 = Vector2(844, 390)
	var left: Rect2 = SafeArea.to_canvas(Rect2(59, 0, 785, 369), size, Transform2D.IDENTITY, true)
	var right: Rect2 = SafeArea.to_canvas(Rect2(0, 0, 785, 369), size, Transform2D.IDENTITY, true)
	assert_eq(left, Rect2(59, 24, 761, 342), "left cutout and rounded edges")
	assert_eq(right, Rect2(24, 24, 761, 342), "right cutout after rotation")
	assert_eq(left.size, right.size, "rotation moves the usable rectangle without stretching")

func test_missing_or_outside_native_bounds_keep_corner_guard() -> void:
	var size: Vector2 = Vector2(390, 844)
	var expected: Rect2 = Rect2(24, 24, 342, 796)
	for native: Rect2 in [Rect2(), Rect2(900, 900, 10, 10), Rect2(-100, -100, 1000, 2000)]:
		assert_eq(SafeArea.to_canvas(native, size, Transform2D.IDENTITY, true), expected, "invalid or oversized native bounds stay within the display")

func test_desktop_uses_full_canvas_without_mobile_guard() -> void:
	var size: Vector2 = Vector2(1280, 800)
	assert_eq(SafeArea.to_canvas(Rect2(Vector2.ZERO, size), size, Transform2D.IDENTITY, false), Rect2(Vector2.ZERO, size), "desktop padding is unchanged")

func test_large_os_insets_are_not_added_twice() -> void:
	var native: Rect2 = Rect2(40, 60, 310, 744)
	assert_eq(SafeArea.to_canvas(native, Vector2(390, 844), Transform2D.IDENTITY, true), native, "native bounds already exceed the edge guard")

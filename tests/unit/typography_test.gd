extends UnitTest

func test_type_roles_keep_a_readable_hierarchy() -> void:
	assert_true(Typography.BODY >= 17, "body meets the iOS default and exceeds Material body large")
	assert_true(Typography.METADATA >= 12, "small text stays above Apple's minimum")
	assert_true(Typography.TITLE > Typography.SECTION and Typography.SECTION > Typography.BODY, "headings have distinct sizes")
	assert_true(Typography.PHRASE > Typography.BODY, "learner phrases remain prominent")

func test_font_size_is_stable_across_pixel_densities_and_rotation() -> void:
	for logical: Vector2i in [Vector2i(360, 800), Vector2i(440, 956), Vector2i(956, 440), Vector2i(1024, 1366)]:
		for density: float in [1.0, 2.0, 2.75, 3.0]:
			var window: Vector2i = Vector2i(Vector2(logical) * density)
			var canvas: Vector2i = UiGeometry.canvas_size(window, density)
			assert_true(canvas.distance_to(UiGeometry.canvas_size(logical)) <= 2.0, "density does not change layout")
			var units: float = Typography.canvas_units_per_point(window, canvas, density)
			for scale_value: float in Typography.TEXT_SCALES:
				for role: int in [Typography.BODY, Typography.SUPPORTING, Typography.TITLE, Typography.PHRASE, Typography.METADATA]:
					var font: int = Typography.font_size(role, units, 1.0, scale_value)
					var rendered: float = font / units
					assert_true(rendered >= role * scale_value - 0.001, "text never shrinks below its logical size")
					assert_true(rendered < role * scale_value + 1.01, "only canvas rounding changes the point size")

func test_accessibility_scale_rejects_invalid_saved_values() -> void:
	for value: Variant in [null, "large", NAN, INF, -1.0, 0.5]:
		assert_almost_eq(Typography.text_scale(value), 1.0, 0.0001, "invalid or too-small text scale defaults safely")
	assert_almost_eq(Typography.text_scale(1.5), 1.5, 0.0001, "chosen enlargement retained")
	assert_almost_eq(Typography.text_scale(7), 2.0, 0.0001, "bounded at the largest offered size")

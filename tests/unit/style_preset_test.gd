extends UnitTest
## The shipped style presets load as [StylePreset] resources with sane sizes, and an unknown id falls back
## to the defaults rather than failing.

func test_every_shipped_preset_loads() -> void:
	var ids: PackedStringArray = StylePreset.list_ids()
	assert_true(ids.has("calm"), "calm ships")
	for preset_id: String in ids:
		var preset: StylePreset = StylePreset.load_by_id(preset_id)
		assert_false(preset.display_name.is_empty(), "%s has a display name" % preset_id)
		assert_true(preset.tile_min_size >= 96, "%s tiles are touchable" % preset_id)
		assert_true(preset.font_scale > 0.0, "%s has a font scale" % preset_id)

func test_unknown_id_falls_back_to_defaults() -> void:
	var preset: StylePreset = StylePreset.load_by_id("no-such-style")
	assert_eq(preset.display_name, "Calm", "the default preset")

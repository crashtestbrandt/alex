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

## Chunk text keeps the preset's text color on every pill, so every pill must carry it.
func test_every_chunk_color_carries_the_text() -> void:
	for preset_id: String in StylePreset.list_ids():
		var preset: StylePreset = StylePreset.load_by_id(preset_id)
		assert_true(preset.chunk_palette.size() >= 8, "%s has a chunk palette of 8 or more" % preset_id)
		var seen: Dictionary[Color, bool] = {}
		for c: Color in preset.chunk_palette:
			assert_false(seen.has(c), "%s chunk color %s appears once" % [preset_id, c.to_html(false)])
			seen[c] = true
			assert_true(_contrast(c, preset.text) >= 4.5, "%s chunk %s carries text at rest (%.2f)" % [preset_id, c.to_html(false), _contrast(c, preset.text)])
			var lit: Color = ChunkColors.spoken(c)
			assert_true(_contrast(lit, preset.text) >= 4.5, "%s chunk %s carries text brightened (%.2f)" % [preset_id, c.to_html(false), _contrast(lit, preset.text)])

func test_default_preset_has_a_palette() -> void:
	assert_true(StylePreset.new().chunk_palette.size() >= 8, "a preset that omits the field still colors chunks")

## The WCAG 2 contrast ratio of two opaque colors, 1 to 21.
static func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

static func _luminance(c: Color) -> float:
	var lin: Color = c.srgb_to_linear()
	return 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b

func test_unknown_id_falls_back_to_defaults() -> void:
	var preset: StylePreset = StylePreset.load_by_id("no-such-style")
	assert_eq(preset.display_name, "Calm", "the default preset")

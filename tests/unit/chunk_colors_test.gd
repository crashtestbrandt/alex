extends UnitTest
## [ChunkColors]: the same text gets the same color whatever its casing or surrounding space, the hash is
## pinned so an upgrade never recolors a family's chunks, and the spoken color keeps the hue.

var _palette: PackedColorArray = PackedColorArray([
	Color(0.9, 0.2, 0.2), Color(0.2, 0.9, 0.2), Color(0.2, 0.2, 0.9), Color(0.9, 0.9, 0.2), Color(0.2, 0.9, 0.9),
	Color(0.9, 0.2, 0.9), Color(0.5, 0.5, 0.5), Color(0.9, 0.6, 0.3), Color(0.3, 0.6, 0.9), Color(0.6, 0.3, 0.9),
])

func test_same_text_same_color() -> void:
	assert_eq(ChunkColors.color_for("Let's go", _palette), ChunkColors.color_for("Let's go", _palette), "repeatable")

func test_casing_and_space_do_not_change_the_color() -> void:
	var expected: Color = ChunkColors.color_for("Let's go", _palette)
	for variant: String in ["let's go", "LET'S GO", "  Let's go ", "\tlet's Go\n"]:
		assert_eq(ChunkColors.color_for(variant, _palette), expected, "'%s' matches \"Let's go\"" % variant)

func test_key_lowercases_and_trims() -> void:
	assert_eq(ChunkColors.key("  Let's GO "), "let's go", "lowercased and trimmed")
	assert_eq(ChunkColors.key("Let's  go"), "let's  go", "inner space is kept")

func test_hash_is_pinned() -> void:
	# FNV-1a then the murmur3 finalizer, computed independently. A change here recolors every chunk for every
	# family.
	assert_eq(ChunkColors.hash_text(""), 2872998923, "the mixed offset basis")
	assert_eq(ChunkColors.hash_text("let's go"), 1273556149, "let's go")
	assert_eq(ChunkColors.hash_text("outside"), 1068607018, "outside")
	assert_eq(ChunkColors.hash_text("café"), 3746663762, "UTF-8 bytes, not code points")

func test_hash_stays_32_bit() -> void:
	for text: String in ["", "a", "let's go", "a much longer chunk than any phrase would hold, repeated twice over"]:
		var h: int = ChunkColors.hash_text(text)
		assert_true(h >= 0 and h <= 0xFFFFFFFF, "'%s' hashes inside 32 bits (%d)" % [text, h])

func test_index_spreads_over_the_palette() -> void:
	assert_eq(ChunkColors.index_for("Let's go", 10), 9, "let's go")
	assert_eq(ChunkColors.index_for("outside", 10), 8, "outside")
	assert_eq(ChunkColors.index_for("in the car", 10), 8, "in the car")
	assert_eq(ChunkColors.index_for("inside", 10), 1, "inside")

func test_different_text_can_differ() -> void:
	assert_true(ChunkColors.color_for("Let's go", _palette) != ChunkColors.color_for("outside", _palette), "two chunks, two colors")

func test_empty_palette_is_transparent() -> void:
	assert_eq(ChunkColors.index_for("Let's go", 0), -1, "no slot")
	assert_eq(ChunkColors.color_for("Let's go", PackedColorArray()).a, 0.0, "no pill")

func test_spoken_keeps_the_hue_and_brightens() -> void:
	var rest: Color = Color(0.6, 0.75, 0.9)
	var lit: Color = ChunkColors.spoken(rest)
	assert_almost_eq(lit.h, rest.h, 0.01, "the hue is kept")
	assert_true(lit.s > rest.s, "more saturated")
	assert_true(lit.v >= rest.v, "no darker")
	assert_eq(ChunkColors.spoken(Color(1.0, 1.0, 1.0, 0.5)).a, 0.5, "alpha is kept")

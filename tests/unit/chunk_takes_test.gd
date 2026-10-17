extends UnitTest
## [ChunkTakes]: the key, the file name, the lookup, the playback choice, and saving, replacing and removing
## a take on a temporary media directory under user://. Every method gets a fresh directory and teardown
## removes it.

var _media: String = ""

func setup() -> void:
	_media = "user://test-takes-%08x" % (randi() % 0x7fffffff)

func teardown() -> void:
	for sub: String in ["", ChunkTakes.DIR]:
		var dir_path: String = _media.path_join(sub) if not sub.is_empty() else _media
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		for file: String in dir.get_files():
			dir.remove(file)
	DirAccess.remove_absolute(_media.path_join(ChunkTakes.DIR))
	DirAccess.remove_absolute(_media)

func _stream() -> AudioStreamWAV:
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = 16000
	var data: PackedByteArray = PackedByteArray()
	data.resize(3200)
	s.data = data
	return s

func test_key_is_the_color_key() -> void:
	assert_eq(ChunkTakes.key("  Let's GO "), "let's go", "lowercased and trimmed")
	assert_eq(ChunkTakes.key("Outside"), ChunkColors.key("Outside"), "the same key the color uses")

func test_file_name_is_safe_stable_and_distinct() -> void:
	var name: String = ChunkTakes.file_name("Let's go")
	assert_true(name.is_valid_filename(), "a valid file name (%s)" % name)
	assert_true(name.begins_with("let_s_go-") and name.ends_with(".wav"), "the key's letters, then the hash (%s)" % name)
	assert_eq(ChunkTakes.file_name("  let's GO"), name, "the same key gives the same file")
	assert_true(ChunkTakes.file_name("Let's go!") != name, "a key that differs only in punctuation gets its own file")
	assert_true(ChunkTakes.file_name("日本語").begins_with("chunk-"), "a key with no ASCII letters still names a file")
	var long_name: String = ChunkTakes.file_name("a very long chunk that goes on and on and on and on and on")
	assert_true(long_name.length() <= ChunkTakes.SLUG_MAX + 13, "a long key is cut before the hash (%s)" % long_name)
	assert_eq(ChunkTakes.relative_path("Let's go"), "chunks/" + name, "under the chunks directory")

func test_take_for_matches_by_key() -> void:
	var takes: Dictionary[String, String] = {"let's go": "chunks/x.wav"}
	assert_eq(ChunkTakes.take_for("LET'S GO ", takes), "chunks/x.wav", "any casing and spacing")
	assert_true(ChunkTakes.has_take("Let's go", takes), "has it")
	assert_false(ChunkTakes.has_take("outside", takes), "not that one")
	assert_eq(ChunkTakes.take_for("outside", takes), "", "empty for none")

func test_plan_prefers_the_whole_take() -> void:
	var g: Gestalt = Gestalt.from_text("a", "Let's go | outside")
	g.recording = "a.wav"
	var takes: Dictionary[String, String] = {"let's go": "chunks/go.wav", "outside": "chunks/out.wav"}
	var segments: Array[ChunkTakes.Segment] = ChunkTakes.plan(g, takes)
	assert_eq(segments.size(), 1, "one segment")
	assert_eq(segments[0].path, "a.wav", "the whole take")
	assert_eq(segments[0].text, "Let's go outside", "the whole text")

func test_plan_says_each_chunk_from_its_take_or_the_os_voice() -> void:
	var g: Gestalt = Gestalt.from_text("a", "Let's go | outside")
	var takes: Dictionary[String, String] = {"let's go": "chunks/go.wav"}
	var segments: Array[ChunkTakes.Segment] = ChunkTakes.plan(g, takes)
	assert_eq(segments.size(), 2, "one segment per chunk")
	assert_eq(segments[0].text, "Let's go", "the first chunk")
	assert_eq(segments[0].path, "chunks/go.wav", "from its take")
	assert_true(segments[0].is_recorded(), "recorded")
	assert_eq(segments[1].text, "outside", "the second chunk")
	assert_false(segments[1].is_recorded(), "by the OS voice")

func test_plan_with_no_take_is_one_os_segment() -> void:
	var g: Gestalt = Gestalt.from_text("a", "Let's go | outside")
	var segments: Array[ChunkTakes.Segment] = ChunkTakes.plan(g, {} as Dictionary[String, String])
	assert_eq(segments.size(), 1, "one segment")
	assert_eq(segments[0].text, "Let's go outside", "the whole text")
	assert_false(segments[0].is_recorded(), "by the OS voice")

func test_save_keeps_the_previous_take_and_clear_removes_both() -> void:
	var takes: Dictionary[String, String] = {}
	assert_eq(ChunkTakes.save(_stream(), "Let's go", _media, takes), OK, "saved")
	var relative: String = ChunkTakes.relative_path("Let's go")
	assert_eq(takes.get("let's go", ""), relative, "recorded in the map by key")
	assert_true(FileAccess.file_exists(_media.path_join(relative)), "the file is under chunks/")
	var previous: String = Recorder.previous_name(relative)
	assert_false(FileAccess.file_exists(_media.path_join(previous)), "no previous take yet")
	assert_eq(ChunkTakes.save(_stream(), "let's go", _media, takes), OK, "saved again")
	assert_true(FileAccess.file_exists(_media.path_join(previous)), "the first take is kept as the previous one")
	assert_eq(takes.size(), 1, "still one key")
	assert_eq(ChunkTakes.clear("LET'S GO", _media, takes), OK, "cleared")
	assert_false(FileAccess.file_exists(_media.path_join(relative)), "the take is gone")
	assert_false(FileAccess.file_exists(_media.path_join(previous)), "and its previous take")
	assert_true(takes.is_empty(), "and the key")
	assert_eq(ChunkTakes.clear("Let's go", _media, takes), OK, "clearing again is fine")

func test_previous_name_sits_beside_the_take() -> void:
	assert_eq(Recorder.previous_name("chunks/a-1.wav"), "chunks/a-1.prev.wav", "under the same directory")
	assert_eq(Recorder.previous_name("lets_go.wav"), "lets_go.prev.wav", "a whole-phrase take")

func test_remove_at_is_fine_with_nothing_there() -> void:
	assert_eq(Recorder.remove_at(_media, "chunks/nothing.wav"), OK, "nothing to remove")

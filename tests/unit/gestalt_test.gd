extends UnitTest
## [Gestalt]: chunking on `|`, the function names a starter file uses, and the dictionary round-trip.

func test_bars_split_into_chunks() -> void:
	var g: Gestalt = Gestalt.from_text("g1", "Let's go | to the park")
	assert_eq(g.chunks.size(), 2, "two chunks")
	assert_eq(g.chunks[0], "Let's go", "first chunk trimmed")
	assert_eq(g.chunks[1], "to the park", "second chunk trimmed")
	assert_eq(g.text, "Let's go to the park", "the spoken text has no bars")

func test_no_bar_is_one_chunk() -> void:
	var g: Gestalt = Gestalt.from_text("g1", "All done")
	assert_eq(g.chunks.size(), 1, "one chunk")
	assert_eq(g.text, "All done", "text unchanged")

func test_empty_chunks_are_dropped() -> void:
	var g: Gestalt = Gestalt.from_text("g1", " Let's go || outside | ")
	assert_eq(g.chunks.size(), 2, "doubled and trailing bars add nothing")
	assert_eq(g.authored_text(), "Let's go | outside", "authored form is normalized")

func test_dict_round_trip() -> void:
	var g: Gestalt = Gestalt.from_text("snack", "It's time for | a snack")
	g.source = "Mum"
	g.function = Gestalt.Function.ROUTINE
	g.stage = NlaStage.Stage.ECHOLALIA
	g.recording = "snack.ogg"
	var back: Gestalt = Gestalt.from_dict(g.to_dict())
	assert_not_null(back, "parses")
	assert_eq(back.id, "snack", "id")
	assert_eq(back.chunks, g.chunks, "chunks")
	assert_eq(back.source, "Mum", "source")
	assert_eq(back.function, Gestalt.Function.ROUTINE, "function")
	assert_eq(back.stage, NlaStage.Stage.ECHOLALIA, "stage")
	assert_eq(back.recording, "snack.ogg", "recording")

func test_unknown_function_and_stage_fall_back() -> void:
	var g: Gestalt = Gestalt.from_dict({"id": "x", "text": "hi", "function": "singing", "stage": 9})
	assert_eq(g.function, Gestalt.Function.UNKNOWN, "an unlisted function is UNKNOWN")
	assert_eq(g.stage, NlaStage.Stage.UNKNOWN, "a stage outside 1..6 is UNKNOWN")

func test_stage_accepts_json_numbers_and_strings() -> void:
	assert_eq(NlaStage.from_value(2.0), NlaStage.Stage.MITIGATION, "JSON floats")
	assert_eq(NlaStage.from_value("3"), NlaStage.Stage.SINGLE_WORDS, "numeric strings")
	assert_eq(NlaStage.from_value("three"), NlaStage.Stage.UNKNOWN, "words are not stages")

func test_missing_id_or_text_is_rejected() -> void:
	assert_null(Gestalt.from_dict({"text": "hi"}), "no id")
	assert_null(Gestalt.from_dict({"id": "x", "text": " | "}), "no chunks")

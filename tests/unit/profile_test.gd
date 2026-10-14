extends UnitTest
## [Profile]: construction, lookups, and the dictionary round-trip that ProfileRepo writes to disk.

func _sample() -> Profile:
	var p: Profile = Profile.make("p1", "  Sam  ")
	p.stage = NlaStage.Stage.MITIGATION
	p.style_id = "bold"
	p.put_gestalt(Gestalt.from_text("a", "Let's go | outside"))
	p.put_gestalt(Gestalt.from_text("b", "All done"))
	p.boards.push_back(Board.make("home", "Home", PackedStringArray(["b", "a", "missing"])))
	p.rooms.push_back(Room.from_dict({"id": "room", "spots": [{"id": "door", "gestalt": "a", "kind": "door"}]}))
	return p

func test_make_trims_the_name() -> void:
	assert_eq(_sample().display_name, "Sam", "surrounding whitespace dropped")

func test_put_gestalt_replaces_by_id() -> void:
	var p: Profile = _sample()
	p.put_gestalt(Gestalt.from_text("a", "Let's go | in the car"))
	assert_eq(p.gestalts.size(), 2, "still two gestalts")
	assert_eq(p.gestalt("a").text, "Let's go in the car", "the new text wins")

func test_board_gestalts_follow_board_order_and_skip_unknown_ids() -> void:
	var p: Profile = _sample()
	var listed: Array[Gestalt] = p.board_gestalts(p.board("home"))
	assert_eq(listed.size(), 2, "the missing id is skipped")
	assert_eq(listed[0].id, "b", "board order, not bank order")

func test_words_join_every_board_in_order_once() -> void:
	var p: Profile = _sample()
	p.put_gestalt(Gestalt.from_text("c", "See you | later"))
	p.boards.push_back(Board.make("more", "More", PackedStringArray(["a", "c"])))
	var ids: PackedStringArray = PackedStringArray()
	for g: Gestalt in p.words_gestalts():
		ids.push_back(g.id)
	assert_eq(ids, PackedStringArray(["b", "a", "c"]), "board order, a repeat dropped, a missing id skipped")

func test_words_fall_back_to_the_bank() -> void:
	var p: Profile = _sample()
	p.boards.clear()
	assert_eq(p.words_gestalts().size(), 2, "no boards: the whole bank")
	p.boards.push_back(Board.make("gone", "Gone", PackedStringArray(["missing"])))
	assert_eq(p.words_gestalts().size(), 2, "boards that name nothing held: the whole bank")
	assert_true(Profile.make("p2", "Empty").words_gestalts().is_empty(), "an empty bank has no words")

func test_dict_round_trip() -> void:
	var p: Profile = _sample()
	var back: Profile = Profile.from_dict(p.to_dict())
	assert_not_null(back, "parses")
	assert_eq(back.id, "p1", "id")
	assert_eq(back.display_name, "Sam", "name")
	assert_eq(back.stage, NlaStage.Stage.MITIGATION, "stage")
	assert_eq(back.style_id, "bold", "style")
	assert_eq(back.created_at, p.created_at, "created_at")
	assert_eq(back.gestalts.size(), 2, "gestalts")
	assert_eq(back.boards.size(), 1, "boards")
	assert_eq(back.boards[0].gestalt_ids, PackedStringArray(["b", "a", "missing"]), "board ids kept verbatim")
	assert_eq(back.rooms.size(), 1, "rooms")
	assert_eq(back.rooms[0].spots[0].kind, Spot.Kind.DOOR, "a spot survives the trip")

func test_wrong_schema_is_rejected() -> void:
	assert_null(Profile.from_dict({"schema": 99, "id": "p"}), "a future schema is not guessed at")
	assert_null(Profile.from_dict({"id": "p"}), "a missing schema is not guessed at")

func test_bad_rows_are_skipped_not_fatal() -> void:
	# Through JSON, as on disk, so the row arrays are untyped and a bad row can be inserted.
	var d: Dictionary = JSON.parse_string(JSON.stringify(_sample().to_dict()))
	var gestalt_rows: Array = d["gestalts"]
	gestalt_rows.push_back({"text": "no id"})
	gestalt_rows.push_back("not even a dict")
	var board_rows: Array = d["boards"]
	board_rows.push_back({"title": "no id"})
	var back: Profile = Profile.from_dict(d)
	assert_not_null(back, "still parses")
	assert_eq(back.gestalts.size(), 2, "bad gestalt rows dropped")
	assert_eq(back.boards.size(), 1, "bad board rows dropped")

func test_json_round_trip_keeps_stage_as_int() -> void:
	# JSON turns every number into a float; from_dict must take that back to a Stage.
	var text: String = JSON.stringify(_sample().to_dict())
	var parsed: Dictionary = JSON.parse_string(text)
	var back: Profile = Profile.from_dict(parsed)
	assert_eq(back.stage, NlaStage.Stage.MITIGATION, "stage survives JSON")
	assert_eq(back.gestalts[0].stage, NlaStage.Stage.UNKNOWN, "an unstaged gestalt stays unstaged")

func test_name_recording_round_trip_is_separate_from_bank() -> void:
	var p: Profile = _sample()
	p.name_recording = "name/name.wav"
	var back: Profile = Profile.from_dict(p.to_dict())
	assert_eq(back.name_gestalt().text, "Sam", "name utterance")
	assert_eq(back.name_gestalt().recording, "name/name.wav", "name recording survives reload")
	assert_eq(back.gestalts.size(), 2, "name never adds a Words tile")

func test_v1_migration_preserves_existing_recordings() -> void:
	var p: Profile = _sample()
	p.gestalts[0].recording = "a.wav"
	var old: Dictionary = p.to_dict()
	old["schema"] = 1
	old.erase("name_recording")
	var back: Profile = Profile.from_dict(old)
	assert_not_null(back, "version 1 loads")
	assert_eq(back.name_recording, "", "old profile starts with synthetic name")
	assert_eq(back.gestalts[0].recording, "a.wav", "familiar recordings preserved")
	assert_eq(back.rooms[0].to_dict(), p.rooms[0].to_dict(), "room configuration preserved")
	assert_eq(old["schema"], 1, "migration does not mutate its input")
	assert_eq(back.to_dict()["schema"], 2, "next save writes version 2")

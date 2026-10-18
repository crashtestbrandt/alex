extends UnitTest
## [Profile]: construction, lookups, and the dictionary round-trip that ProfileRepo writes to disk.

func _sample() -> Profile:
	var p: Profile = Profile.make("p1", "  Sam  ")
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

func test_words_are_the_boards_first_then_the_rest_of_the_bank() -> void:
	var p: Profile = _sample()
	p.put_gestalt(Gestalt.from_text("c", "See you | later"))
	p.put_gestalt(Gestalt.from_text("d", "All done"))
	p.boards.push_back(Board.make("more", "More", PackedStringArray(["a", "c"])))
	var ids: PackedStringArray = PackedStringArray()
	for g: Gestalt in p.words_gestalts():
		ids.push_back(g.id)
	assert_eq(ids, PackedStringArray(["b", "a", "c", "d"]), "board order, a repeat dropped, a missing id skipped, the rest of the bank after")

func test_words_hold_the_whole_bank() -> void:
	var p: Profile = _sample()
	p.boards.clear()
	assert_eq(p.words_gestalts().size(), 2, "no boards: the whole bank")
	p.boards.push_back(Board.make("gone", "Gone", PackedStringArray(["missing"])))
	assert_eq(p.words_gestalts().size(), 2, "boards that name nothing held: still the whole bank")
	p.boards.push_back(Board.make("one", "One", PackedStringArray(["b"])))
	assert_eq(p.words_gestalts()[0].id, "b", "a board's phrase comes first")
	assert_eq(p.words_gestalts().size(), 2, "and a room's phrase is never left out")
	assert_true(Profile.make("p2", "Empty").words_gestalts().is_empty(), "an empty bank has no words")

func test_dict_round_trip() -> void:
	var p: Profile = _sample()
	var back: Profile = Profile.from_dict(p.to_dict())
	assert_not_null(back, "parses")
	assert_eq(back.id, "p1", "id")
	assert_eq(back.display_name, "Sam", "name")
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

func test_json_round_trip_keeps_stages_as_ints() -> void:
	# JSON turns every number into a float; from_dict must take that back to a Stage.
	var p: Profile = _sample()
	p.scenes.push_back("home_routines")
	assert_true(p.set_scene_stage("home_routines", NlaStage.Stage.MITIGATION), "staged")
	p.gestalts[0].stage = NlaStage.Stage.ECHOLALIA
	var text: String = JSON.stringify(p.to_dict())
	var parsed: Dictionary = JSON.parse_string(text)
	var back: Profile = Profile.from_dict(parsed)
	assert_eq(back.stage_for_scene("home_routines"), NlaStage.Stage.MITIGATION, "a scene's stage survives JSON")
	assert_eq(back.gestalts[0].stage, NlaStage.Stage.ECHOLALIA, "a gestalt's stage survives JSON")
	assert_eq(back.gestalts[1].stage, NlaStage.Stage.UNKNOWN, "an unstaged gestalt stays unstaged")

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
	assert_eq(back.to_dict()["schema"], Profile.SCHEMA_VERSION, "next save writes the current version")
	assert_true(back.scenes.is_empty(), "a version 1 profile with no starter has no scene")

func test_v2_migration_records_the_starter_as_the_scene() -> void:
	var p: Profile = _sample()
	p.starter_id = "home_routines"
	var old: Dictionary = p.to_dict()
	old["schema"] = 2
	old.erase("scenes")
	var back: Profile = Profile.from_dict(old)
	assert_not_null(back, "version 2 loads")
	assert_eq(back.scenes, PackedStringArray(["home_routines"]), "the starter is its one scene")
	assert_eq(old["schema"], 2, "migration does not mutate its input")
	var blank: Dictionary = p.to_dict()
	blank["schema"] = 2
	blank.erase("scenes")
	blank["starter"] = ""
	assert_true(Profile.from_dict(blank).scenes.is_empty(), "a blank start has no scene")

func test_scenes_round_trip_once_each() -> void:
	var p: Profile = _sample()
	p.scenes = PackedStringArray(["home_routines", "bath_time"])
	var back: Profile = Profile.from_dict(p.to_dict())
	assert_eq(back.scenes, PackedStringArray(["home_routines", "bath_time"]), "scenes survive the trip in order")
	assert_true(back.has_scene("bath_time") and not back.has_scene("garden"), "has_scene reads the list")
	var d: Dictionary = p.to_dict()
	d["scenes"] = ["home_routines", "home_routines", "", " "]
	assert_eq(Profile.from_dict(d).scenes, PackedStringArray(["home_routines"]), "a repeat and a blank are dropped")

func test_v6_migration_gives_every_held_scene_the_profile_wide_stage() -> void:
	var p: Profile = _sample()
	p.scenes.push_back("home_routines")
	var old: Dictionary = p.to_dict()
	old["schema"] = 6
	old["stage"] = 3
	old.erase("scene_stages")
	var back: Profile = Profile.from_dict(old)
	assert_not_null(back, "version 6 loads")
	assert_eq(back.stage_for_scene("home_routines"), NlaStage.Stage.SINGLE_WORDS, "the held scene takes the stage the profile had")
	assert_eq(old["schema"], 6, "migration does not mutate its input")
	assert_false(back.to_dict().has("stage"), "the profile-wide stage is gone")
	assert_eq(back.to_dict()["schema"], Profile.SCHEMA_VERSION, "next save writes the current version")

func test_v7_migration_keeps_a_scenes_own_stage_over_the_profiles() -> void:
	var p: Profile = _sample()
	p.scenes.push_back("home_routines")
	p.scenes.push_back("bath_time")
	var old: Dictionary = p.to_dict()
	old["schema"] = 7
	old["stage"] = 2
	old["scene_stages"] = {"bath_time": 4}
	var back: Profile = Profile.from_dict(old)
	assert_not_null(back, "version 7 loads")
	assert_eq(back.stage_for_scene("bath_time"), NlaStage.Stage.EARLY_GRAMMAR, "a scene with its own stage keeps it")
	assert_eq(back.stage_for_scene("home_routines"), NlaStage.Stage.MITIGATION, "a scene without one takes the profile's")
	var unstaged: Dictionary = p.to_dict()
	unstaged["schema"] = 7
	unstaged["stage"] = 0
	assert_true(Profile.from_dict(unstaged).scene_stages.is_empty(), "a profile that was not staged leaves its scenes unstaged")

func test_scene_stages_round_trip_for_held_scenes_only() -> void:
	var p: Profile = Profile.make("p", "Sam")
	Starter.find("home_routines").seed(p)
	assert_eq(p.stage_for_scene("home_routines"), NlaStage.Stage.ECHOLALIA, "a fresh scene is at stage 1")
	assert_false(p.set_scene_stage("bath_time", NlaStage.Stage.SINGLE_WORDS), "a scene the profile does not hold cannot be staged")
	assert_true(p.set_scene_stage("home_routines", NlaStage.Stage.EARLY_GRAMMAR), "a held scene is staged")
	assert_eq(p.stage_for_scene("home_routines"), NlaStage.Stage.EARLY_GRAMMAR, "and reads it back")
	assert_false(p.set_scene_stage("home_routines", NlaStage.Stage.EARLY_GRAMMAR), "the same stage again changes nothing")
	var d: Dictionary = p.to_dict()
	d["scene_stages"]["ghost"] = 3
	d["scene_stages"]["home_routines"] = 4
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	var back: Profile = Profile.from_dict(parsed)
	assert_eq(back.scene_stages, {"home_routines": 4} as Dictionary[String, int], "a stage on a scene the profile lacks is dropped")
	assert_true(back.set_scene_stage("home_routines", NlaStage.Stage.UNKNOWN), "UNKNOWN drops the entry")
	assert_eq(back.stage_for_scene("home_routines"), NlaStage.Stage.ECHOLALIA, "which reads as stage 1")
	assert_false(back.set_scene_stage("home_routines", NlaStage.Stage.UNKNOWN), "dropping it twice changes nothing")
	assert_true(p.remove_scene("home_routines"), "removed")
	assert_true(p.scene_stages.is_empty(), "removing a scene drops its stage")

func test_says_follows_the_scenes_stage() -> void:
	var p: Profile = Profile.make("p", "Sam")
	Starter.find("home_routines").seed(p)
	assert_true(Starter.find("bath_time").add_to(p), "a second scene joins")
	var r: Room = p.rooms[0]
	var door: Spot = r.spots[0]
	assert_eq(door.id, "door", "the bedroom's first spot is the door")
	assert_eq(p.says(r, door, false).id, "lets_go_outside", "not staged says the base pair")
	assert_eq(p.says(r, door, true).id, "lets_go_inside", "and its alternate when toggled")
	assert_true(p.set_scene_stage("home_routines", NlaStage.Stage.SINGLE_WORDS), "the bedroom is staged 3")
	assert_eq(p.says(r, door, false).text, "Go out", "stage 3 says the stage 3 pair")
	assert_eq(p.says(r, door, true).text, "Come in", "with its alternate")
	var bath: Room = p.rooms[1]
	assert_eq(p.says(bath, bath.spots[0], false).id, "time_for_a_bath", "the other scene stays unstaged")
	assert_true(p.set_scene_stage("home_routines", NlaStage.Stage.COMPLEX_GRAMMAR), "the bedroom is staged 5")
	assert_eq(p.says(r, door, false).text, "Open the door", "stage 5 says the nearest pair below, stage 4")
	assert_true(p.set_scene_stage("home_routines", NlaStage.Stage.ECHOLALIA), "the bedroom is staged 1")
	assert_eq(p.says(r, door, false).id, "lets_go_outside", "stage 1 says the base pair")
	var window: Spot = r.spots[1]
	assert_eq(p.says(r, window, true).id, "look_outside", "a pair with no alternate says its phrase when toggled")
	door.stage_gestalts[1] = "no-such-phrase"
	assert_eq(p.says(r, door, false).id, "lets_go_outside", "a pair naming a phrase the bank lacks falls back to the base pair")

func test_v5_migration_adds_empty_notes() -> void:
	var p: Profile = _sample()
	var old: Dictionary = p.to_dict()
	old["schema"] = 5
	old["stage"] = 0
	old.erase("notes")
	var back: Profile = Profile.from_dict(old)
	assert_not_null(back, "version 5 loads")
	assert_eq(back.notes, "", "no notes yet")
	assert_eq(old["schema"], 5, "migration does not mutate its input")
	assert_eq(back.to_dict()["schema"], Profile.SCHEMA_VERSION, "next save writes the current version")

func test_notes_round_trip_as_written() -> void:
	var p: Profile = _sample()
	p.notes = "Quotes Bluey.\nTry \"Let's go | to the park\" next.  "
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(p.to_dict()))
	var back: Profile = Profile.from_dict(parsed)
	assert_eq(back.notes, p.notes, "line breaks, quotes, bars and trailing spaces survive")
	var bad: Dictionary = p.to_dict()
	bad["notes"] = 7
	assert_eq(Profile.from_dict(bad).notes, "", "a non-text note reads as empty, never fatal")

func test_v4_migration_adds_an_empty_take_map() -> void:
	var p: Profile = _sample()
	p.gestalts[0].recording = "a.wav"
	var old: Dictionary = p.to_dict()
	old["schema"] = 4
	old.erase("chunk_takes")
	var back: Profile = Profile.from_dict(old)
	assert_not_null(back, "version 4 loads")
	assert_true(back.chunk_takes.is_empty(), "no chunk takes yet")
	assert_eq(back.gestalts[0].recording, "a.wav", "whole-phrase recordings preserved")
	assert_eq(old["schema"], 4, "migration does not mutate its input")
	assert_eq(back.to_dict()["schema"], Profile.SCHEMA_VERSION, "next save writes the current version")

func test_chunk_takes_round_trip_by_key_and_skip_bad_rows() -> void:
	var p: Profile = _sample()
	p.chunk_takes["let's go"] = "chunks/let_s_go-1.wav"
	var text: String = JSON.stringify(p.to_dict())
	var parsed: Dictionary = JSON.parse_string(text)
	var back: Profile = Profile.from_dict(parsed)
	assert_eq(back.chunk_takes.get("let's go", ""), "chunks/let_s_go-1.wav", "a take survives JSON")
	var d: Dictionary = JSON.parse_string(text)
	var rows: Dictionary = d["chunk_takes"]
	rows["Outside "] = " chunks/outside-2.wav "
	rows[""] = "chunks/blank.wav"
	rows["nothing"] = ""
	rows["number"] = 3
	rows["list"] = ["chunks/x.wav"]
	rows["up"] = "chunks/../../other/profile.json"
	rows["root"] = "/etc/passwd"
	rows["user"] = "user://profiles/other/media/x.wav"
	back = Profile.from_dict(d)
	assert_eq(back.chunk_takes.size(), 2, "bad rows and paths that leave media/ dropped")
	assert_eq(back.chunk_takes.get("outside", ""), "chunks/outside-2.wav", "a key is normalized and a path trimmed")

func test_gestalt_by_text_ignores_marks_and_casing() -> void:
	var p: Profile = _sample()
	assert_eq(p.gestalt_by_text("Let's go | outside").id, "a", "the authored form")
	assert_eq(p.gestalt_by_text("let's GO outside").id, "a", "the spoken form, any casing")
	assert_null(p.gestalt_by_text("Let's go inside"), "another phrase is not it")

func test_v3_migration_opens_on_the_first_room() -> void:
	var p: Profile = _sample()
	p.scenes = PackedStringArray(["home_routines"])
	var old: Dictionary = p.to_dict()
	old["schema"] = 3
	old.erase("entry")
	var back: Profile = Profile.from_dict(old)
	assert_not_null(back, "version 3 loads")
	assert_eq(back.entry, "", "no entry scene")
	assert_eq(back.explore_room().id, "room", "Explore opens on the first room")
	assert_eq(old["schema"], 3, "migration does not mutate its input")

func test_entry_round_trips_only_for_a_held_scene() -> void:
	var p: Profile = _sample()
	p.scenes = PackedStringArray(["home_routines", "bath_time"])
	p.entry = "bath_time"
	assert_eq(Profile.from_dict(p.to_dict()).entry, "bath_time", "the entry survives the trip")
	var d: Dictionary = p.to_dict()
	d["entry"] = "garden"
	assert_eq(Profile.from_dict(d).entry, "", "an entry the profile does not hold is dropped")

func test_scene_of_reads_the_scope() -> void:
	var p: Profile = _sample()
	p.starter_id = "home_routines"
	p.scenes = PackedStringArray(["home_routines", "bath_time"])
	assert_eq(p.scene_of("bath_time.tub"), "bath_time", "a scoped id is its pack's")
	assert_eq(p.scene_of("tub"), "home_routines", "an unscoped id is the starter's")
	assert_eq(p.scene_of("garden.tub"), "home_routines", "a scope the profile does not hold is the starter's")

func test_set_entry_needs_a_held_scene_with_a_room() -> void:
	var p: Profile = _sample()
	p.starter_id = "home_routines"
	p.scenes = PackedStringArray(["home_routines", "bath_time", "songs"])
	p.rooms.push_back(Room.from_dict({"id": "bath_time.bath", "spots": []}))
	assert_eq(p.explore_room().id, "room", "with no entry, Explore opens on the first room")
	assert_true(p.set_entry("bath_time"), "a held scene with a room")
	assert_eq(p.explore_room().id, "bath_time.bath", "Explore opens on its room")
	assert_false(p.set_entry("songs"), "a scene with no room is refused")
	assert_false(p.set_entry("garden"), "a scene the profile does not hold is refused")
	assert_eq(p.entry, "bath_time", "and neither changes the entry")

func test_v8_migration_preserves_room_placement_and_recordings() -> void:
	var profile: Profile = Profile.make("legacy", "Sam")
	Starter.find("home_routines").seed(profile)
	profile.gestalts[0].recording = "familiar.wav"
	var old: Dictionary = profile.to_dict()
	old["schema"] = 8
	for room: Dictionary in JsonValue.to_dict_rows(old["rooms"]):
		room.erase("width")
		room.erase("depth")
		room.erase("height")
		for spot: Dictionary in JsonValue.to_dict_rows(room["spots"]):
			spot.erase("rotation")
	var migrated: Profile = Profile.from_dict(old)
	assert_eq(RoomSpace.dims(migrated.rooms[0]), Vector3(4, 2.6, 3), "legacy room keeps its box")
	assert_eq(migrated.rooms[0].spots[0].rotation_degrees, 0.0, "legacy furniture keeps its orientation")
	assert_eq(migrated.gestalts[0].recording, "familiar.wav", "voice is preserved")
	assert_eq(old["schema"], 8, "input is unchanged")
	assert_false(JsonValue.to_dict_rows(old["rooms"])[0].has("width"), "migration never edits the input room")

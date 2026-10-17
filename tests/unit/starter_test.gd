extends UnitTest
## The shipped starter packs under res://starters/ parse, and every board names gestalts the pack holds. A
## pack a contributor writes by hand is checked here before a child ever sees it.

func test_every_shipped_pack_parses() -> void:
	var packs: Array[Starter] = Starter.list_all()
	assert_true(packs.size() >= 3, "blank, home_routines and bath_time ship")
	assert_false(Starter.find("blank").is_scene(), "blank is not a scene")
	assert_true(Starter.find("bath_time").is_scene(), "bath_time is a scene")
	for s: Starter in packs:
		assert_false(s.title.is_empty(), "%s has a title" % s.id)
		for b: Board in s.boards:
			for gid: String in b.gestalt_ids:
				assert_true(_holds(s, gid), "%s board '%s' names a gestalt the pack holds: %s" % [s.id, b.id, gid])
		for r: Room in s.rooms:
			for spot: Spot in r.spots:
				assert_true(_holds(s, spot.gestalt_id), "%s room '%s' spot '%s' names a gestalt the pack holds" % [s.id, r.id, spot.id])
				if not spot.alt_gestalt_id.is_empty():
					assert_true(_holds(s, spot.alt_gestalt_id), "%s room '%s' spot '%s' alt names a gestalt the pack holds" % [s.id, r.id, spot.id])

func _holds(s: Starter, gid: String) -> bool:
	for g: Gestalt in s.gestalts:
		if g.id == gid:
			return true
	return false

func test_seed_records_the_starter_as_the_first_scene() -> void:
	var p: Profile = Profile.make("p", "Sam")
	Starter.find("home_routines").seed(p)
	assert_eq(p.scenes, PackedStringArray(["home_routines"]), "the starter is the first scene")
	Starter.find("home_routines").seed(p)
	assert_eq(p.scenes.size(), 1, "seeding again does not list it twice")

func test_add_to_prefixes_ids_and_reuses_the_banks_phrases() -> void:
	var p: Profile = Profile.make("p", "Sam")
	Starter.find("home_routines").seed(p)
	var before: int = p.gestalts.size()
	var bath: Starter = Starter.find("bath_time")
	assert_not_null(bath, "bath_time ships")
	assert_true(bath.add_to(p), "added")
	assert_eq(p.scenes, PackedStringArray(["home_routines", "bath_time"]), "the scene is recorded after the starter")
	assert_eq(p.rooms.size(), 2, "its room joins the profile")
	assert_eq(p.rooms[1].id, "bath_time.bath", "the room id is scoped to the pack")
	assert_not_null(p.gestalt("bath_time.lets_get_in_the_tub"), "a new phrase is copied with a scoped id")
	assert_null(p.gestalt("bath_time.time_for_a_bath"), "a phrase the bank already says is not copied")
	assert_null(p.gestalt("bath_time.lights_on"), "nor is another")
	assert_eq(p.gestalts.size(), before + bath.gestalts.size() - 3, "three phrases were already in the bank")
	var door: Spot = null
	var light: Spot = null
	for s: Spot in p.rooms[1].spots:
		if s.id == "door":
			door = s
		if s.id == "light":
			light = s
	assert_true(door != null and door.gestalt_id == "time_for_a_bath", "a spot saying a bank phrase points at the bank's own")
	assert_true(door != null and door.alt_gestalt_id == "bath_time.all_clean", "its alternate points at the scoped copy")
	assert_true(light != null and light.gestalt_id == "lights_on" and light.alt_gestalt_id == "lights_off", "both of the lamp's phrases are the bank's own")
	assert_eq(p.boards[1].id, "bath_time.bath", "the board id is scoped")
	assert_eq(p.boards[1].gestalt_ids[0], "bath_time.lets_get_in_the_tub", "the board names the scoped copy")
	for r: Room in p.rooms:
		for s: Spot in r.spots:
			assert_not_null(p.gestalt(s.gestalt_id), "%s/%s names a phrase the bank holds" % [r.id, s.id])
	var rooms: int = p.rooms.size()
	var count: int = p.gestalts.size()
	assert_false(bath.add_to(p), "a second add is refused")
	assert_true(p.rooms.size() == rooms and p.gestalts.size() == count and p.scenes.size() == 2, "and changes nothing")

func test_add_to_a_blank_profile_scopes_everything() -> void:
	var p: Profile = Profile.make("p", "Sam")
	Starter.find("blank").seed(p)
	assert_true(Starter.find("home_routines").add_to(p), "added to a blank start")
	assert_eq(p.scenes, PackedStringArray(["blank", "home_routines"]), "both packs are listed")
	assert_eq(p.rooms[0].id, "home_routines.home", "the room is scoped")
	assert_not_null(p.gestalt("home_routines.lets_go_outside"), "every phrase is scoped")
	assert_eq(p.rooms[0].spots[0].gestalt_id, "home_routines.lets_go_outside", "and the spots follow")
	assert_true(p.gestalt("home_routines.lets_go_outside").recording.is_empty(), "a pack carries no recording")

func test_find_by_id() -> void:
	assert_not_null(Starter.find("blank"), "blank is found")
	assert_null(Starter.find("no-such-pack"), "a missing pack is null")

func test_home_routines_has_a_room_to_explore() -> void:
	var s: Starter = Starter.find("home_routines")
	assert_not_null(s, "present")
	assert_eq(s.rooms.size(), 1, "one room")
	assert_eq(s.rooms[0].title, "Explore", "the room is titled for the learner's Explore pill")
	assert_true(s.rooms[0].spots.size() >= 6, "a handful of spots")

func test_home_routines_is_mitigable() -> void:
	var s: Starter = Starter.find("home_routines")
	assert_not_null(s, "present")
	var multi: int = 0
	for g: Gestalt in s.gestalts:
		if g.chunks.size() > 1:
			multi += 1
	assert_true(multi >= s.gestalts.size() / 2, "most of the pack splits into chunks")

func test_remove_scene_undoes_add_to() -> void:
	var p: Profile = Profile.make("p", "Sam")
	Starter.find("home_routines").seed(p)
	var before: Dictionary = p.to_dict()
	assert_true(Starter.find("bath_time").add_to(p), "added")
	assert_true(p.set_entry("bath_time"), "the scene is the entry")
	assert_true(p.remove_scene("bath_time"), "removed")
	assert_eq(p.to_dict(), before, "the profile is as it was before the add")
	assert_false(p.remove_scene("bath_time"), "a second remove is refused")

func test_removing_the_starter_keeps_what_another_scene_says() -> void:
	var p: Profile = Profile.make("p", "Sam")
	Starter.find("home_routines").seed(p)
	assert_true(Starter.find("bath_time").add_to(p), "added")
	assert_true(p.remove_scene("home_routines"), "the starter is removed")
	assert_eq(p.scenes, PackedStringArray(["bath_time"]), "one scene is left")
	assert_eq(p.rooms.size(), 1, "the starter's room is gone")
	assert_eq(p.rooms[0].id, "bath_time.bath", "the added scene's room stays")
	assert_eq(p.boards.size(), 1, "the starter's board is gone")
	assert_null(p.gestalt("lets_go_outside"), "a phrase only the starter said is gone")
	assert_not_null(p.gestalt("time_for_a_bath"), "a phrase the bath says stays")
	for r: Room in p.rooms:
		for s: Spot in r.spots:
			assert_not_null(p.gestalt(s.gestalt_id), "%s names a phrase the bank holds" % s.id)
	for b: Board in p.boards:
		for gid: String in b.gestalt_ids:
			assert_not_null(p.gestalt(gid), "board %s names a phrase the bank holds: %s" % [b.id, gid])

func test_remove_scene_keeps_recordings_for_the_next_add() -> void:
	var p: Profile = Profile.make("p", "Sam")
	Starter.find("blank").seed(p)
	var bath: Starter = Starter.find("bath_time")
	assert_true(bath.add_to(p), "added")
	p.gestalt("bath_time.splash_splash").recording = "bath_time.splash_splash.wav"
	assert_true(p.set_entry("bath_time"), "the entry")
	assert_true(p.remove_scene("bath_time"), "removed")
	assert_true(p.rooms.is_empty() and p.boards.is_empty(), "its room and board are gone")
	assert_eq(p.gestalts.size(), 1, "only the recorded phrase stays")
	assert_eq(p.entry, "", "the entry is cleared")
	assert_null(p.explore_room(), "Explore has no room")
	assert_true(bath.add_to(p), "added again")
	assert_eq(p.gestalt("bath_time.splash_splash").recording, "bath_time.splash_splash.wav", "the recording is found again")
	assert_eq(p.gestalts.size(), bath.gestalts.size(), "the phrase is not copied twice")

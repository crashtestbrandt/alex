extends UnitTest
## The shipped starter packs under res://starters/ parse, and every board names gestalts the pack holds. A
## pack a contributor writes by hand is checked here before a child ever sees it.

func test_every_shipped_pack_parses() -> void:
	var packs: Array[Starter] = Starter.list_all()
	assert_true(packs.size() >= 2, "blank and home_routines ship")
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

func test_find_by_id() -> void:
	assert_not_null(Starter.find("blank"), "blank is found")
	assert_null(Starter.find("no-such-pack"), "a missing pack is null")

func test_home_routines_has_a_room_to_explore() -> void:
	var s: Starter = Starter.find("home_routines")
	assert_not_null(s, "present")
	assert_eq(s.rooms.size(), 1, "one room")
	assert_true(s.rooms[0].spots.size() >= 6, "a handful of spots")

func test_home_routines_is_mitigable() -> void:
	var s: Starter = Starter.find("home_routines")
	assert_not_null(s, "present")
	var multi: int = 0
	for g: Gestalt in s.gestalts:
		if g.chunks.size() > 1:
			multi += 1
	assert_true(multi >= s.gestalts.size() / 2, "most of the pack splits into chunks")

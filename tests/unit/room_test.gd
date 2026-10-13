extends UnitTest
## [Room] and [Spot]: the names a starter file uses, clamping, and the dictionary round-trip.

func test_spot_round_trip() -> void:
	var s: Spot = Spot.from_dict({
		"id": "door", "kind": "door", "reaction": "open", "x": 0.1, "y": 0.5, "size": 0.3,
		"gestalt": "a", "alt_gestalt": "b",
	})
	assert_not_null(s, "parses")
	var back: Spot = Spot.from_dict(s.to_dict())
	assert_eq(back.kind, Spot.Kind.DOOR, "kind")
	assert_eq(back.reaction, Spot.Reaction.OPEN, "reaction")
	assert_almost_eq(back.x, 0.1, 0.0001, "x")
	assert_almost_eq(back.size, 0.3, 0.0001, "size")
	assert_eq(back.gestalt_id, "a", "gestalt")
	assert_eq(back.alt_gestalt_id, "b", "alt gestalt")

func test_unknown_names_fall_back() -> void:
	var s: Spot = Spot.from_dict({"id": "x", "kind": "dragon", "reaction": "explode", "gestalt": "a"})
	assert_eq(s.kind, Spot.Kind.CIRCLE, "an unlisted kind draws a circle")
	assert_eq(s.reaction, Spot.Reaction.BOUNCE, "an unlisted reaction bounces")

func test_position_and_size_are_clamped() -> void:
	var s: Spot = Spot.from_dict({"id": "x", "gestalt": "a", "x": 4, "y": -2, "size": 9})
	assert_almost_eq(s.x, 1.0, 0.0001, "x clamped to 1")
	assert_almost_eq(s.y, 0.0, 0.0001, "y clamped to 0")
	assert_almost_eq(s.size, 0.6, 0.0001, "size clamped to the ceiling")

func test_spot_needs_an_id_and_a_gestalt() -> void:
	assert_null(Spot.from_dict({"gestalt": "a"}), "no id")
	assert_null(Spot.from_dict({"id": "x"}), "no gestalt")

func test_room_round_trip_skips_bad_spots() -> void:
	var r: Room = Room.from_dict({
		"id": "home", "title": "Home",
		"spots": [{"id": "a", "gestalt": "g"}, {"id": "no-gestalt"}, "junk"],
	})
	assert_not_null(r, "parses")
	assert_eq(r.spots.size(), 1, "bad spot rows dropped")
	var back: Room = Room.from_dict(r.to_dict())
	assert_eq(back.title, "Home", "title")
	assert_eq(back.spots[0].id, "a", "spot kept")

func test_every_kind_and_reaction_has_a_name() -> void:
	for k: int in Spot.Kind.values():
		var kind: Spot.Kind = k as Spot.Kind
		assert_eq(Spot.kind_from_name(Spot.kind_name(kind)), kind, "kind %d round-trips" % k)
	for r: int in Spot.Reaction.values():
		var reaction: Spot.Reaction = r as Spot.Reaction
		assert_eq(Spot.reaction_from_name(Spot.reaction_name(reaction)), reaction, "reaction %d round-trips" % r)

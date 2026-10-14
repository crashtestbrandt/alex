extends UnitTest
## [Room] and [Spot]: the names a starter file uses, clamping, and the dictionary round-trip.

func test_spot_round_trip() -> void:
	var s: Spot = Spot.from_dict({
		"id": "door", "kind": "door", "reaction": "open", "x": 0.1, "y": 0.5, "size": 0.3,
		"wall": "back", "height": 0.25, "gestalt": "a", "alt_gestalt": "b",
	})
	assert_not_null(s, "parses")
	var back: Spot = Spot.from_dict(s.to_dict())
	assert_eq(back.kind, Spot.Kind.DOOR, "kind")
	assert_eq(back.reaction, Spot.Reaction.OPEN, "reaction")
	assert_almost_eq(back.x, 0.1, 0.0001, "x")
	assert_almost_eq(back.size, 0.3, 0.0001, "size")
	assert_eq(back.gestalt_id, "a", "gestalt")
	assert_eq(back.alt_gestalt_id, "b", "alt gestalt")
	assert_eq(back.wall, Spot.Wall.BACK, "wall")
	assert_almost_eq(back.height, 0.25, 0.0001, "height")

func test_spot_defaults_to_the_floor() -> void:
	var s: Spot = Spot.from_dict({"id": "x", "gestalt": "a"})
	assert_eq(s.wall, Spot.Wall.NONE, "no wall named, the floor")
	assert_almost_eq(s.height, 0.0, 0.0001, "base height zero")
	assert_eq(Spot.from_dict({"id": "x", "gestalt": "a", "wall": "ceiling"}).wall, Spot.Wall.NONE, "an unlisted wall is the floor")
	assert_almost_eq(Spot.from_dict({"id": "x", "gestalt": "a", "height": 3}).height, 0.9, 0.0001, "height clamped under the ceiling")

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
	assert_eq(back.camera, Room.Camera.VIEWS, "the camera defaults to the fixed views")

func test_room_camera_round_trip() -> void:
	var r: Room = Room.from_dict({"id": "home", "camera": "orbit"})
	assert_eq(r.camera, Room.Camera.ORBIT, "orbit parses")
	assert_eq(Room.from_dict(r.to_dict()).camera, Room.Camera.ORBIT, "orbit round-trips")
	assert_eq(Room.from_dict({"id": "home", "camera": "spin"}).camera, Room.Camera.VIEWS, "an unlisted camera is views")
	for c: int in Room.Camera.values():
		var camera: Room.Camera = c as Room.Camera
		assert_eq(Room.camera_from_name(Room.camera_name(camera)), camera, "camera %d round-trips" % c)

func test_every_kind_and_reaction_has_a_name() -> void:
	for k: int in Spot.Kind.values():
		var kind: Spot.Kind = k as Spot.Kind
		assert_eq(Spot.kind_from_name(Spot.kind_name(kind)), kind, "kind %d round-trips" % k)
	for r: int in Spot.Reaction.values():
		var reaction: Spot.Reaction = r as Spot.Reaction
		assert_eq(Spot.reaction_from_name(Spot.reaction_name(reaction)), reaction, "reaction %d round-trips" % r)
	for w: int in Spot.Wall.values():
		var wall: Spot.Wall = w as Spot.Wall
		assert_eq(Spot.wall_from_name(Spot.wall_name(wall)), wall, "wall %d round-trips" % w)

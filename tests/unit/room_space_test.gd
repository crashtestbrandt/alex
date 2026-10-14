extends UnitTest
## [RoomSpace]: where a spot stands for each wall, which way it faces, and when a wall hides.

func _spot(wall: String, x: float, y: float, height: float) -> Spot:
	return Spot.from_dict({"id": "s", "gestalt": "g", "wall": wall, "x": x, "y": y, "height": height, "size": 0.2})

func test_floor_spot() -> void:
	var xf: Transform3D = RoomSpace.place(_spot("none", 0.5, 0.5, 0.0))
	assert_almost_eq(xf.origin.x, 0.0, 0.0001, "centered across")
	assert_almost_eq(xf.origin.y, 0.0, 0.0001, "on the floor")
	var raised: Transform3D = RoomSpace.place(_spot("none", 0.5, 0.5, 0.25))
	assert_almost_eq(raised.origin.y, RoomSpace.HEIGHT * 0.25, 0.0001, "a floor spot can stand on something")
	assert_almost_eq(xf.origin.z, 0.0, 0.0001, "mid depth")
	assert_almost_eq((xf.basis * Vector3.BACK).z, 1.0, 0.0001, "faces the open front")

func test_back_wall_spot() -> void:
	var xf: Transform3D = RoomSpace.place(_spot("back", 0.0, 0.9, 0.5))
	assert_almost_eq(xf.origin.x, -RoomSpace.WIDTH / 2.0, 0.0001, "left end of the back wall")
	assert_almost_eq(xf.origin.y, RoomSpace.HEIGHT * 0.5, 0.0001, "base at height")
	assert_true(xf.origin.z < -RoomSpace.DEPTH / 2.0 + RoomSpace.WALL, "against the wall")

func test_side_walls_face_in() -> void:
	var left: Transform3D = RoomSpace.place(_spot("left", 0.5, 0.0, 0.0))
	assert_almost_eq((left.basis * Vector3.BACK).x, 1.0, 0.0001, "a left-wall object faces +X")
	var right: Transform3D = RoomSpace.place(_spot("right", 0.5, 0.0, 0.0))
	assert_almost_eq((right.basis * Vector3.BACK).x, -1.0, 0.0001, "a right-wall object faces -X")
	assert_almost_eq(right.origin.x, RoomSpace.WIDTH / 2.0 - RoomSpace.WALL / 2.0, 0.0001, "on the right wall")

func test_wall_hides_when_the_camera_is_outside_it() -> void:
	var from_the_right: Vector3 = Vector3(6.0, 1.0, 0.0)
	assert_true(RoomSpace.wall_hidden(Spot.Wall.RIGHT, from_the_right), "the right wall hides")
	assert_false(RoomSpace.wall_hidden(Spot.Wall.LEFT, from_the_right), "the left wall shows")
	assert_false(RoomSpace.wall_hidden(Spot.Wall.BACK, Vector3(0.0, 1.0, 5.0)), "the back wall shows from the front")
	assert_false(RoomSpace.wall_hidden(Spot.Wall.RIGHT, Vector3(1.0, 1.0, 5.0)), "a wall shows while the camera is inside its plane")

func test_smallest_spot() -> void:
	var r: Room = Room.from_dict({"id": "r", "spots": [
		{"id": "a", "gestalt": "g", "size": 0.5}, {"id": "b", "gestalt": "g", "size": 0.1}]})
	assert_almost_eq(RoomSpace.smallest_spot_m(r), 0.1 * RoomSpace.WIDTH, 0.0001, "the smallest, in meters")
	assert_almost_eq(RoomSpace.smallest_spot_m(Room.new()), 0.0, 0.0001, "an empty room has none")

func test_inside_the_box() -> void:
	assert_true(RoomSpace.inside(Vector3(0.0, 1.4, 0.0)), "the center is inside")
	assert_false(RoomSpace.inside(Vector3(0.0, 1.4, 5.0)), "the open front is outside")
	assert_false(RoomSpace.inside(Vector3(0.0, 4.0, 0.0)), "above the ceiling is outside")
	assert_false(RoomSpace.inside(Vector3(3.0, 1.0, 0.0)), "past a side wall is outside")
	assert_true(RoomSpace.inside(RoomSpace.tilt_origin(null)), "tilt stands inside")

func test_tilt_stands_at_the_center_over_what_is_under_it() -> void:
	var empty: Vector3 = RoomSpace.tilt_origin(Room.new())
	assert_almost_eq(empty.x, 0.0, 0.0001, "centered across")
	assert_almost_eq(empty.z, 0.0, 0.0001, "centered in depth")
	assert_almost_eq(empty.y, RoomSpace.TILT_EYE_HEIGHT, 0.0001, "eye height with nothing under it")
	assert_almost_eq(RoomSpace.tilt_origin(null).y, RoomSpace.TILT_EYE_HEIGHT, 0.0001, "no room, eye height")
	var rug: Room = Room.from_dict({"id": "r", "spots": [{"id": "rug", "gestalt": "g", "x": 0.5, "y": 0.5, "size": 0.4}]})
	assert_almost_eq(RoomSpace.tilt_origin(rug).y, RoomSpace.TILT_EYE_HEIGHT, 0.0001, "a wide low thing at the center leaves eye height")
	var tub: Room = Room.from_dict({"id": "r", "spots": [{"id": "tub", "kind": "tub", "gestalt": "g", "x": 0.65, "y": 0.25, "size": 0.5}]})
	assert_almost_eq(RoomSpace.tilt_origin(tub).y, RoomSpace.TILT_EYE_HEIGHT, 0.0001, "a long tub off center leaves eye height")
	var bed: Room = Room.from_dict({"id": "r", "spots": [{"id": "bed", "kind": "bed", "gestalt": "g", "x": 0.62, "y": 0.2, "size": 0.5}]})
	assert_almost_eq(RoomSpace.tilt_origin(bed).y, RoomSpace.TILT_EYE_HEIGHT, 0.0001, "the bedroom's bed leaves eye height")
	var lamp_height: float = ObjectRecipes.make(Spot.Kind.LIGHT, 0.5 * RoomSpace.WIDTH, StylePreset.new()).aabb().end.y
	var tall: Room = Room.from_dict({"id": "r", "spots": [{"id": "lamp", "kind": "light", "gestalt": "g", "x": 0.5, "y": 0.5, "size": 0.5}]})
	assert_almost_eq(RoomSpace.tilt_origin(tall).y, lamp_height + RoomSpace.TILT_CLEARANCE, 0.0001, "a tall thing at the center raises the camera by its real height")
	var corner: Room = Room.from_dict({"id": "r", "spots": [{"id": "lamp", "kind": "light", "gestalt": "g", "x": 0.05, "y": 0.05, "size": 0.5}]})
	assert_almost_eq(RoomSpace.tilt_origin(corner).y, RoomSpace.TILT_EYE_HEIGHT, 0.0001, "a tall thing in a corner is not under the camera")
	var wall: Room = Room.from_dict({"id": "r", "spots": [{"id": "door", "gestalt": "g", "wall": "back", "x": 0.5, "size": 0.6}]})
	assert_almost_eq(RoomSpace.tilt_origin(wall).y, RoomSpace.TILT_EYE_HEIGHT, 0.0001, "a wall object is never under the camera")
	var huge: Room = Room.from_dict({"id": "r", "spots": [{"id": "bed", "kind": "bed", "gestalt": "g", "x": 0.5, "y": 0.5, "height": 0.7, "size": 0.6}]})
	assert_almost_eq(RoomSpace.tilt_origin(huge).y, RoomSpace.HEIGHT - RoomSpace.TILT_CLEARANCE, 0.0001, "never up to the ceiling")

func test_content_box_stops_at_the_tallest_spot() -> void:
	var r: Room = Room.from_dict({"id": "r", "spots": [
		{"id": "door", "gestalt": "g", "wall": "back", "size": 0.5},
		{"id": "ball", "gestalt": "g", "size": 0.1}]})
	assert_almost_eq(RoomSpace.content_dims(r).y, 2.0, 0.0001, "the door's top, 0.5 of the width")
	var low: Room = Room.from_dict({"id": "r", "spots": [{"id": "ball", "gestalt": "g", "size": 0.1}]})
	assert_almost_eq(RoomSpace.content_dims(low).y, RoomSpace.CONTENT_HEIGHT_MIN, 0.0001, "never under the floor")
	var high: Room = Room.from_dict({"id": "r", "spots": [{"id": "w", "gestalt": "g", "wall": "back", "height": 0.9, "size": 0.6}]})
	assert_almost_eq(RoomSpace.content_dims(high).y, RoomSpace.HEIGHT, 0.0001, "never above the wall")
	assert_almost_eq(RoomSpace.content_dims(null).y, RoomSpace.CONTENT_HEIGHT_MIN, 0.0001, "no room, the floor")

func test_wall_openings_are_empty_and_remaining_slabs_do_not_overlap() -> void:
	for wall: String in ["back", "left", "right"]:
		var room: Room = Room.from_dict({"id": "r", "spots": [
			{"id": "door", "kind": "door", "gestalt": "g", "wall": wall, "x": 0.2, "size": 0.5},
			{"id": "window", "kind": "window", "gestalt": "g", "wall": wall, "x": 0.7, "height": 0.4, "size": 0.3}]})
		var side: Spot.Wall = room.spots[0].wall
		var length: float = RoomSpace.WIDTH if side == Spot.Wall.BACK else RoomSpace.DEPTH
		var sections: Array[Rect2] = RoomSpace.wall_sections(side, room)
		var area: float = 0.0
		for i: int in sections.size():
			var section: Rect2 = sections[i]
			assert_true(section.has_area(), "no degenerate slabs")
			area += section.get_area()
			for j: int in range(i + 1, sections.size()):
				assert_false(section.intersection(sections[j]).has_area(), "slabs never overlap")
			for spot: Spot in room.spots:
				var hole: Rect2 = ObjectRecipes.opening(spot.kind, RoomSpace.spot_size_m(spot))
				hole.position += Vector2(spot.x * length, spot.height * RoomSpace.HEIGHT)
				assert_false(section.intersection(hole).has_area(), "aperture contains no wall")
		var expected: float = (length + (0.0 if side == Spot.Wall.BACK else RoomSpace.APRON)) * (RoomSpace.HEIGHT + RoomSpace.WALL_RISE)
		for spot: Spot in room.spots:
			expected -= ObjectRecipes.opening(spot.kind, RoomSpace.spot_size_m(spot)).get_area()
		assert_almost_eq(area, expected, 0.0001, "wall area minus openings")

func test_overlapping_and_edge_openings_remain_valid() -> void:
	var room: Room = Room.from_dict({"id": "r", "spots": [
		{"id": "a", "kind": "door", "gestalt": "g", "wall": "back", "x": 0.0, "size": 0.5},
		{"id": "b", "kind": "door", "gestalt": "g", "wall": "back", "x": 0.0, "size": 0.5}]})
	var sections: Array[Rect2] = RoomSpace.wall_sections(Spot.Wall.BACK, room)
	var area: float = 0.0
	for section: Rect2 in sections:
		assert_true(section.position.x >= 0.0, "edge cut is clipped")
		area += section.get_area()
	var hole: Rect2 = ObjectRecipes.opening(Spot.Kind.DOOR, 2.0)
	assert_almost_eq(area, RoomSpace.WIDTH * (RoomSpace.HEIGHT + RoomSpace.WALL_RISE) - hole.get_area() / 2.0, 0.0001, "overlapping holes are removed once")

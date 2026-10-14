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

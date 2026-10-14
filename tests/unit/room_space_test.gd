extends UnitTest
## [RoomSpace]: where a spot stands for each wall, which way it faces, and when a wall hides.

func _spot(wall: String, x: float, y: float, height: float) -> Spot:
	return Spot.from_dict({"id": "s", "gestalt": "g", "wall": wall, "x": x, "y": y, "height": height, "size": 0.2})

func test_floor_spot() -> void:
	var xf: Transform3D = RoomSpace.place(_spot("none", 0.5, 0.5, 0.3))
	assert_almost_eq(xf.origin.x, 0.0, 0.0001, "centered across")
	assert_almost_eq(xf.origin.y, 0.0, 0.0001, "on the floor, height ignored")
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

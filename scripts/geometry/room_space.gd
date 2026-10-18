extends RefCounted
class_name RoomSpace
## The room's box and where a [Spot] stands in it, pure (docs/geometry.md "The room"). The open front faces
## +Z, the back wall is at -Z, the floor is y = 0. Every spot's `x`, `y` and `height` are fractions of this
## box, so one starter pack fits every screen.

const WIDTH: float = 4.0
const HEIGHT: float = 2.6
const DEPTH: float = 3.0
const WALL: float = 0.06
## How far the floor and the side walls run past the open front, toward the camera, so the world reaches the
## screen's edges and bottom instead of stopping at the room's box.
const APRON: float = 4.0
## How far the walls rise past the room's height, so their top edge runs off the top of the screen.
const WALL_RISE: float = 1.5

static func dims(room: Room = null) -> Vector3:
	return Vector3(room.width, room.height, room.depth) if room != null else Vector3(WIDTH, HEIGHT, DEPTH)

## The center of the room box.
static func center(room: Room = null) -> Vector3:
	return Vector3(0.0, dims(room).y / 2.0, 0.0)

## The spot's longest extent in meters.
static func spot_size_m(s: Spot, room: Room = null) -> float:
	return s.size * dims(room).x

## Where the spot's object stands: on the floor or against a wall with its back to it, its base at `height`.
static func place(s: Spot, room: Room = null) -> Transform3D:
	var box: Vector3 = dims(room)
	match s.wall:
		Spot.Wall.BACK:
			return Transform3D(Basis.IDENTITY, Vector3(s.x * box.x - box.x / 2.0, s.height * box.y, -box.z / 2.0 + WALL / 2.0))
		Spot.Wall.LEFT:
			return Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-box.x / 2.0 + WALL / 2.0, s.height * box.y, -box.z / 2.0 + s.x * box.z))
		Spot.Wall.RIGHT:
			return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(box.x / 2.0 - WALL / 2.0, s.height * box.y, -box.z / 2.0 + s.x * box.z))
		_:
			return Transform3D(Basis(Vector3.UP, deg_to_rad(s.rotation_degrees)), Vector3(s.x * box.x - box.x / 2.0, s.height * box.y, -box.z / 2.0 + s.y * box.z))

## The center of a wall's inner face.
static func wall_center(w: Spot.Wall, room: Room = null) -> Vector3:
	var box: Vector3 = dims(room)
	match w:
		Spot.Wall.LEFT:
			return Vector3(-box.x / 2.0, box.y / 2.0, 0.0)
		Spot.Wall.RIGHT:
			return Vector3(box.x / 2.0, box.y / 2.0, 0.0)
		_:
			return Vector3(0.0, box.y / 2.0, -box.z / 2.0)

## The direction out of the room through a wall.
static func wall_outward(w: Spot.Wall) -> Vector3:
	match w:
		Spot.Wall.LEFT:
			return Vector3.LEFT
		Spot.Wall.RIGHT:
			return Vector3.RIGHT
		_:
			return Vector3.FORWARD

## A wall is hidden when the camera stands outside it, so a side view looks into the room.
static func wall_hidden(w: Spot.Wall, camera_position: Vector3, room: Room = null) -> bool:
	return (camera_position - wall_center(w, room)).dot(wall_outward(w)) > 0.05

## Whether a point is inside the room's box. The front wall and the ceiling show only from inside, since the
## orbit views look in through them.
static func inside(p: Vector3, room: Room = null) -> bool:
	var box: Vector3 = dims(room)
	return absf(p.x) < box.x / 2.0 and absf(p.z) < box.z / 2.0 and p.y > 0.0 and p.y < box.y

## Eye height for a camera standing in the room, and how far it keeps from anything under or over it.
const TILT_EYE_HEIGHT: float = 1.4
const TILT_CLEARANCE: float = 0.25

## Where a Tilt camera stands: the room's center at eye height, raised over any floor object whose footprint
## reaches the center, by that object's real height, and never up to the ceiling. The footprint and the
## height come from the object's recipe, so a long low tub leaves the camera at eye height. Each recipe is
## built here, so a caller keeps the result for the room rather than asking every frame.
static func tilt_origin(r: Room) -> Vector3:
	var y: float = TILT_EYE_HEIGHT
	if r != null:
		for s: Spot in r.spots:
			if s.wall != Spot.Wall.NONE:
				continue
			var box: AABB = place(s, r) * ObjectRecipes.make(s.kind, spot_size_m(s, r), StylePreset.new()).aabb()
			var footprint: Rect2 = Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(TILT_CLEARANCE)
			if footprint.has_point(Vector2.ZERO):
				y = maxf(y, box.end.y + TILT_CLEARANCE)
	return Vector3(0.0, minf(y, dims(r).y - TILT_CLEARANCE), 0.0)

## The floor of what the camera must keep in frame: at least this much of the walls' height.
const CONTENT_HEIGHT_MIN: float = 1.5

## The box the camera frames: the room's footprint up to the tallest spot, never the whole wall. The walls
## above it may run under the floating controls; the objects and the floor may not.
static func content_dims(r: Room) -> Vector3:
	var top: float = CONTENT_HEIGHT_MIN
	if r != null:
		for s: Spot in r.spots:
			top = maxf(top, s.height * dims(r).y + spot_size_m(s, r))
	return Vector3(dims(r).x, minf(top, dims(r).y), dims(r).z)

## The smallest spot in the room, in meters; zero for an empty room.
static func smallest_spot_m(r: Room) -> float:
	var smallest: float = 0.0
	for s: Spot in r.spots:
		var m: float = spot_size_m(s, r)
		if smallest <= 0.0 or m < smallest:
			smallest = m
	return smallest

## Wall coordinates run left to right on the back wall and back to front on either side.
## Split the solid wall around every aperture. Overlapping or edge-clipped openings remain a union.
static func wall_sections(wall: Spot.Wall, room: Room) -> Array[Rect2]:
	var box: Vector3 = dims(room)
	var length: float = box.x if wall == Spot.Wall.BACK else box.z
	var drawn_length: float = length if wall == Spot.Wall.BACK else length + APRON
	var sections: Array[Rect2] = [Rect2(0.0, 0.0, drawn_length, box.y + WALL_RISE)]
	if room == null:
		return sections
	for spot: Spot in room.spots:
		if spot.wall != wall:
			continue
		var hole: Rect2 = ObjectRecipes.opening(spot.kind, spot_size_m(spot, room))
		if not hole.has_area():
			continue
		hole.position += Vector2(spot.x * length, spot.height * box.y)
		var next: Array[Rect2] = []
		for section: Rect2 in sections:
			var cut: Rect2 = section.intersection(hole)
			if not cut.has_area():
				next.push_back(section)
				continue
			var pieces: Array[Rect2] = [
				Rect2(section.position, Vector2(cut.position.x - section.position.x, section.size.y)),
				Rect2(Vector2(cut.end.x, section.position.y), Vector2(section.end.x - cut.end.x, section.size.y)),
				Rect2(Vector2(cut.position.x, section.position.y), Vector2(cut.size.x, cut.position.y - section.position.y)),
				Rect2(Vector2(cut.position.x, cut.end.y), Vector2(cut.size.x, section.end.y - cut.end.y))]
			for piece: Rect2 in pieces:
				if piece.has_area():
					next.push_back(piece)
		sections = next
	return sections

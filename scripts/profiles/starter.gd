extends RefCounted
class_name Starter
## A starter pack: a scene, its room, its gestalts and its boards. Shipped as JSON under res://starters/ so a
## parent or clinician can write one without touching code (docs/profiles.md). A profile copies the pack at
## creation (`seed`) or adds it later (`add_to`) and never reads it again, so editing a pack changes nothing
## for an existing child.

const DIR: String = "res://starters"
## Joins a pack id to a local id when a pack is added to a profile. A gestalt id names a recording file, so
## the separator is one every file system takes.
const SCOPE_MARK: String = "."

var id: String = ""
var title: String = ""
var description: String = ""
var gestalts: Array[Gestalt] = []
var boards: Array[Board] = []
var rooms: Array[Room] = []

## Every pack under res://starters/, sorted by id. A pack that fails to parse is reported and skipped.
static func list_all() -> Array[Starter]:
	var out: Array[Starter] = []
	var dir: DirAccess = DirAccess.open(DIR)
	if dir == null:
		return out
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file: String in files:
		if not file.ends_with(".json"):
			continue
		var s: Starter = load_file("%s/%s" % [DIR, file])
		if s != null:
			out.push_back(s)
	return out

## The pack with `starter_id`, or null.
static func find(starter_id: String) -> Starter:
	return load_file("%s/%s.json" % [DIR, starter_id])

## A pack from a JSON file. Returns null, with the reason printed, for a file that cannot be read or parsed.
static func load_file(path: String) -> Starter:
	if not FileAccess.file_exists(path):
		return null
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		printerr("Starter: %s is not a JSON object" % path)
		return null
	var s: Starter = from_dict(JsonValue.to_dict(parsed))
	if s == null:
		printerr("Starter: %s has no id" % path)
	return s

static func from_dict(d: Dictionary) -> Starter:
	var starter_id: String = JsonValue.to_text(d.get("id")).strip_edges()
	if starter_id.is_empty():
		return null
	var s: Starter = Starter.new()
	s.id = starter_id
	s.title = JsonValue.to_text(d.get("title"), starter_id)
	s.description = JsonValue.to_text(d.get("description"))
	for row: Dictionary in JsonValue.to_dict_rows(d.get("gestalts")):
		var g: Gestalt = Gestalt.from_dict(row)
		if g != null:
			s.gestalts.push_back(g)
	for row: Dictionary in JsonValue.to_dict_rows(d.get("boards")):
		var b: Board = Board.from_dict(row)
		if b != null:
			s.boards.push_back(b)
	for row: Dictionary in JsonValue.to_dict_rows(d.get("rooms")):
		var r: Room = Room.from_dict(row)
		if r != null:
			s.rooms.push_back(r)
	return s

## Whether this pack is a scene a profile can add: it holds at least one gestalt.
func is_scene() -> bool:
	return not gestalts.is_empty()

## Add this pack to `p` as a scene. Its gestalts, rooms and boards are copied in with ids prefixed by the
## pack's id, so nothing collides with what the profile holds. A phrase the bank already says, by its chunk
## key, is not copied again; the pack's spots and boards point at the bank's own. Returns false, changing
## nothing, when the profile already holds the pack.
func add_to(p: Profile) -> bool:
	if p.has_scene(id):
		return false
	var ids: Dictionary[String, String] = {}
	for g: Gestalt in gestalts:
		var own: Gestalt = p.gestalt_by_text(g.authored_text())
		if own != null:
			ids[g.id] = own.id
			continue
		var copy: Gestalt = Gestalt.from_dict(g.to_dict())
		copy.id = scoped(g.id)
		p.put_gestalt(copy)
		ids[g.id] = copy.id
	for r: Room in rooms:
		var room: Room = Room.from_dict(r.to_dict())
		room.id = scoped(r.id)
		for s: Spot in room.spots:
			s.gestalt_id = _mapped(ids, s.gestalt_id)
			if not s.alt_gestalt_id.is_empty():
				s.alt_gestalt_id = _mapped(ids, s.alt_gestalt_id)
		var existing_room: Room = p.room(room.id)
		if existing_room != null:
			p.rooms.erase(existing_room)
		p.rooms.push_back(room)
	for b: Board in boards:
		var mapped: PackedStringArray = PackedStringArray()
		for gid: String in b.gestalt_ids:
			mapped.push_back(_mapped(ids, gid))
		var board: Board = Board.make(scoped(b.id), b.title, mapped)
		var existing: Board = p.board(board.id)
		if existing != null:
			p.boards.erase(existing)
		p.boards.push_back(board)
	p.scenes.push_back(id)
	return true

## The id a pack-local gestalt id became in the profile, or itself when the map has no entry.
static func _mapped(ids: Dictionary[String, String], local_id: String) -> String:
	if ids.has(local_id):
		return ids[local_id]
	return local_id

## A pack's local id, scoped to the pack: `home_routines.lets_go_outside`.
func scoped(local_id: String) -> String:
	return "%s%s%s" % [id, SCOPE_MARK, local_id]

## Copy this pack's gestalts, rooms and boards into `p` as its first scene. Existing entries with the same
## id are replaced.
func seed(p: Profile) -> void:
	p.starter_id = id
	if not p.has_scene(id):
		p.scenes.push_back(id)
	for g: Gestalt in gestalts:
		p.put_gestalt(Gestalt.from_dict(g.to_dict()))
	for b: Board in boards:
		var existing: Board = p.board(b.id)
		if existing != null:
			p.boards.erase(existing)
		p.boards.push_back(Board.from_dict(b.to_dict()))
	for r: Room in rooms:
		var existing_room: Room = p.room(r.id)
		if existing_room != null:
			p.rooms.erase(existing_room)
		p.rooms.push_back(Room.from_dict(r.to_dict()))

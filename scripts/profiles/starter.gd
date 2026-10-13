extends RefCounted
class_name Starter
## A starter pack: the gestalts and boards a new profile is seeded with. Shipped as JSON under res://starters/
## so a parent or clinician can write one without touching code (docs/profiles.md). A profile copies the
## pack at creation and never reads it again, so editing a pack changes nothing for an existing child.

const DIR: String = "res://starters"

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

## Copy this pack's gestalts, rooms and boards into `p`. Existing entries with the same id are replaced.
func seed(p: Profile) -> void:
	p.starter_id = id
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

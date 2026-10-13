extends RefCounted
class_name Profile
## One child's configuration: who they are to the app, the style they see, their gestalt bank, their rooms
## and their boards. The NLA stage is optional and nothing on the child's screen shows it. Pure data with a dictionary round-trip; ProfileRepo puts it on disk.
##
## A profile is the unit of configurability (docs/profiles.md). Everything a family or clinician tailors
## lives here or in the style preset it names. Nothing about one child is in code.

const SCHEMA_VERSION: int = 1

var id: String = ""
var display_name: String = ""
var stage: NlaStage.Stage = NlaStage.Stage.UNKNOWN
## The id of a StylePreset under res://styles/.
var style_id: String = "calm"
## The starter pack this profile was seeded from, for the record. Empty for a blank start.
var starter_id: String = ""
## Unix time of creation.
var created_at: int = 0
var gestalts: Array[Gestalt] = []
var boards: Array[Board] = []
var rooms: Array[Room] = []

static func make(profile_id: String, name: String) -> Profile:
	var p: Profile = Profile.new()
	p.id = profile_id
	p.display_name = name.strip_edges()
	p.created_at = int(Time.get_unix_time_from_system())
	return p

## The gestalt with `gestalt_id`, or null.
func gestalt(gestalt_id: String) -> Gestalt:
	for g: Gestalt in gestalts:
		if g.id == gestalt_id:
			return g
	return null

## Add or replace a gestalt by id.
func put_gestalt(g: Gestalt) -> void:
	for i: int in gestalts.size():
		if gestalts[i].id == g.id:
			gestalts[i] = g
			return
	gestalts.push_back(g)

## The board with `board_id`, or null.
func board(board_id: String) -> Board:
	for b: Board in boards:
		if b.id == board_id:
			return b
	return null

## The room with `room_id`, or null.
func room(room_id: String) -> Room:
	for r: Room in rooms:
		if r.id == room_id:
			return r
	return null

## The gestalts a board names, in board order, skipping ids the bank does not hold.
func board_gestalts(b: Board) -> Array[Gestalt]:
	var out: Array[Gestalt] = []
	for gid: String in b.gestalt_ids:
		var g: Gestalt = gestalt(gid)
		if g != null:
			out.push_back(g)
	return out

func to_dict() -> Dictionary:
	var gestalt_dicts: Array[Dictionary] = []
	for g: Gestalt in gestalts:
		gestalt_dicts.push_back(g.to_dict())
	var board_dicts: Array[Dictionary] = []
	for b: Board in boards:
		board_dicts.push_back(b.to_dict())
	var room_dicts: Array[Dictionary] = []
	for r: Room in rooms:
		room_dicts.push_back(r.to_dict())
	return {
		"schema": SCHEMA_VERSION,
		"id": id,
		"display_name": display_name,
		"stage": int(stage),
		"style": style_id,
		"starter": starter_id,
		"created_at": created_at,
		"gestalts": gestalt_dicts,
		"boards": board_dicts,
		"rooms": room_dicts,
	}

## A profile from a saved dictionary. Returns null for a missing id or a schema this build does not read.
## A gestalt or board entry that does not parse is skipped, so one bad row never loses a profile.
static func from_dict(d: Dictionary) -> Profile:
	var schema: int = JsonValue.to_int(d.get("schema"), 0)
	if schema != SCHEMA_VERSION:
		return null
	var profile_id: String = JsonValue.to_text(d.get("id")).strip_edges()
	if profile_id.is_empty():
		return null
	var p: Profile = Profile.new()
	p.id = profile_id
	p.display_name = JsonValue.to_text(d.get("display_name")).strip_edges()
	p.stage = NlaStage.from_value(d.get("stage"))
	p.style_id = JsonValue.to_text(d.get("style"), "calm")
	p.starter_id = JsonValue.to_text(d.get("starter"))
	p.created_at = JsonValue.to_int(d.get("created_at"), 0)
	for row: Dictionary in JsonValue.to_dict_rows(d.get("gestalts")):
		var g: Gestalt = Gestalt.from_dict(row)
		if g != null:
			p.gestalts.push_back(g)
	for row: Dictionary in JsonValue.to_dict_rows(d.get("boards")):
		var b: Board = Board.from_dict(row)
		if b != null:
			p.boards.push_back(b)
	for row: Dictionary in JsonValue.to_dict_rows(d.get("rooms")):
		var r: Room = Room.from_dict(row)
		if r != null:
			p.rooms.push_back(r)
	return p

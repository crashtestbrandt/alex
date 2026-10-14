extends RefCounted
class_name Profile
## One child's configuration: who they are to the app, the style they see, their gestalt bank, their rooms
## and their boards. The NLA stage is optional and nothing on the child's screen shows it. Pure data with a dictionary round-trip; ProfileRepo puts it on disk.
##
## A profile is the unit of configurability (docs/profiles.md). Everything a family or clinician tailors
## lives here or in the style preset it names. Nothing about one child is in code.

const SCHEMA_VERSION: int = 3

var id: String = ""
var display_name: String = ""
var name_recording: String = ""
var stage: NlaStage.Stage = NlaStage.Stage.UNKNOWN
## The id of a StylePreset under res://styles/.
var style_id: String = "calm"
## The starter pack this profile was seeded from, for the record. Empty for a blank start.
var starter_id: String = ""
## Every pack this profile holds, the starter first, in the order they were added (`Starter.add_to`). A pack
## is added once.
var scenes: PackedStringArray = PackedStringArray()
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

## The gestalt that says `text`, by the chunk key, or null. Chunk marks and casing do not matter.
func gestalt_by_text(text: String) -> Gestalt:
	var wanted: String = ChunkColors.key(Gestalt.from_text("", text).text)
	for g: Gestalt in gestalts:
		if ChunkColors.key(g.text) == wanted:
			return g
	return null

## Whether this profile holds the pack `scene_id`.
func has_scene(scene_id: String) -> bool:
	return scene_id in scenes

## A separate utterance; its recording uses media/name/ to avoid bank filename collisions.
func name_gestalt() -> Gestalt:
	var g: Gestalt = Gestalt.from_text("name", display_name)
	g.recording = name_recording
	return g

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

## The tiles behind the learner's Words pill, every gestalt in the bank once: the boards' first, in board
## order, then the rest in bank order. A room's phrases are in the bank, so they are in Words too.
func words_gestalts() -> Array[Gestalt]:
	var out: Array[Gestalt] = []
	var seen: Dictionary[String, bool] = {}
	for b: Board in boards:
		for g: Gestalt in board_gestalts(b):
			if not seen.has(g.id):
				seen[g.id] = true
				out.push_back(g)
	for g: Gestalt in gestalts:
		if not seen.has(g.id):
			seen[g.id] = true
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
		"name_recording": name_recording,
		"stage": int(stage),
		"style": style_id,
		"starter": starter_id,
		"scenes": Array(scenes),
		"created_at": created_at,
		"gestalts": gestalt_dicts,
		"boards": board_dicts,
		"rooms": room_dicts,
	}

## A profile from a saved dictionary. Returns null for a missing id or a schema this build does not read.
## A gestalt or board entry that does not parse is skipped, so one bad row never loses a profile.
static func from_dict(d: Dictionary) -> Profile:
	var schema: int = JsonValue.to_int(d.get("schema"), 0)
	if schema == 1:
		return from_dict(migrate_v1(d))
	if schema == 2:
		return from_dict(migrate_v2(d))
	if schema != SCHEMA_VERSION:
		return null
	var profile_id: String = JsonValue.to_text(d.get("id")).strip_edges()
	if profile_id.is_empty():
		return null
	var p: Profile = Profile.new()
	p.id = profile_id
	p.display_name = JsonValue.to_text(d.get("display_name")).strip_edges()
	p.name_recording = JsonValue.to_text(d.get("name_recording"))
	p.stage = NlaStage.from_value(d.get("stage"))
	p.style_id = JsonValue.to_text(d.get("style"), "calm")
	p.starter_id = JsonValue.to_text(d.get("starter"))
	for item: Variant in JsonValue.to_array(d.get("scenes")):
		var scene_id: String = JsonValue.to_text(item).strip_edges()
		if not scene_id.is_empty() and not scene_id in p.scenes:
			p.scenes.push_back(scene_id)
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

## Version 1 had no name recording. Preserve the bank, rooms and media references.
static func migrate_v1(d: Dictionary) -> Dictionary:
	var migrated: Dictionary = d.duplicate(true)
	migrated["schema"] = 2
	migrated["name_recording"] = ""
	return migrated

## Version 2 had no scene list. The starter it was seeded from is its one scene.
static func migrate_v2(d: Dictionary) -> Dictionary:
	var migrated: Dictionary = d.duplicate(true)
	migrated["schema"] = 3
	var starter: String = JsonValue.to_text(d.get("starter")).strip_edges()
	migrated["scenes"] = [starter] if not starter.is_empty() else []
	return migrated

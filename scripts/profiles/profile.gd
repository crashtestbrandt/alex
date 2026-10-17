extends RefCounted
class_name Profile
## One child's configuration: who they are to the app, the style they see, their gestalt bank, their rooms
## and their boards. The NLA stage is optional and nothing on the child's screen shows it. Pure data with a dictionary round-trip; ProfileRepo puts it on disk.
##
## A profile is the unit of configurability (docs/profiles.md). Everything a family or clinician tailors
## lives here or in the style preset it names. Nothing about one child is in code.

const SCHEMA_VERSION: int = 4

var id: String = ""
var display_name: String = ""
var name_recording: String = ""
var stage: NlaStage.Stage = NlaStage.Stage.UNKNOWN
## The id of a StylePreset under res://styles/.
var style_id: String = "calm"
## The starter pack this profile was seeded from, for the record. Empty for a blank start.
var starter_id: String = ""
## Every pack this profile holds, the starter first, in the order they were added (`Starter.add_to`). A pack
## is added once. `remove_scene` takes one out.
var scenes: PackedStringArray = PackedStringArray()
## The scene whose first room Explore opens on (`explore_room`). Empty for the profile's first room.
var entry: String = ""
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

## The scene that brought in the gestalt, room or board `item_id`. An added pack's ids are scoped to it
## (`Starter.scoped`). Any other id came from the starter.
func scene_of(item_id: String) -> String:
	var prefix: String = item_id.get_slice(Starter.SCOPE_MARK, 0)
	if item_id.contains(Starter.SCOPE_MARK) and has_scene(prefix):
		return prefix
	return starter_id

## Whether the scene `scene_id` brought in a room.
func scene_has_room(scene_id: String) -> bool:
	for r: Room in rooms:
		if scene_of(r.id) == scene_id:
			return true
	return false

## The room Explore opens on: the entry scene's first room, else the first room. Null with no room.
func explore_room() -> Room:
	for r: Room in rooms:
		if not entry.is_empty() and scene_of(r.id) == entry:
			return r
	if rooms.is_empty():
		return null
	return rooms[0]

## Make `scene_id` the scene Explore opens on. Returns false, changing nothing, for a scene the profile does
## not hold or one with no room.
func set_entry(scene_id: String) -> bool:
	if not has_scene(scene_id) or not scene_has_room(scene_id):
		return false
	entry = scene_id
	return true

## Remove the scene `scene_id`: its rooms, its boards, and its phrases nothing else names. A phrase with a
## recording stays in the bank, so adding the scene again finds the recording. Returns false, changing
## nothing, for a scene the profile does not hold.
func remove_scene(scene_id: String) -> bool:
	if not has_scene(scene_id):
		return false
	var kept_rooms: Array[Room] = []
	for r: Room in rooms:
		if scene_of(r.id) != scene_id:
			kept_rooms.push_back(r)
	var kept_boards: Array[Board] = []
	for b: Board in boards:
		if scene_of(b.id) != scene_id:
			kept_boards.push_back(b)
	var named: Dictionary[String, bool] = {}
	for r: Room in kept_rooms:
		for s: Spot in r.spots:
			named[s.gestalt_id] = true
			named[s.alt_gestalt_id] = true
	for b: Board in kept_boards:
		for gid: String in b.gestalt_ids:
			named[gid] = true
	var kept_gestalts: Array[Gestalt] = []
	for g: Gestalt in gestalts:
		if scene_of(g.id) != scene_id or named.has(g.id) or not g.recording.is_empty():
			kept_gestalts.push_back(g)
	rooms = kept_rooms
	boards = kept_boards
	gestalts = kept_gestalts
	scenes.remove_at(scenes.find(scene_id))
	if entry == scene_id:
		entry = ""
	return true

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
		"entry": entry,
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
	if schema == 3:
		return from_dict(migrate_v3(d))
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
	var entry_id: String = JsonValue.to_text(d.get("entry")).strip_edges()
	if entry_id in p.scenes:
		p.entry = entry_id
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

## Version 3 had no entry scene. Explore opened on the first room, which an empty entry keeps.
static func migrate_v3(d: Dictionary) -> Dictionary:
	var migrated: Dictionary = d.duplicate(true)
	migrated["schema"] = 4
	migrated["entry"] = ""
	return migrated

extends RefCounted
class_name Spot
## One responsive object in a [Room]: a door, a light, a ball. Tapping it does something visible and says
## its gestalt. A spot with an `alt_gestalt_id` alternates between two phrases as its state toggles, so a
## door says "Let's go outside" and then "Let's go inside".
##
## A spot can carry a phrase pair per stage (docs/design.md "Progression"). `gestalt_at` picks the pair
## written for the nearest stage at or below the one asked for, and `gestalt_id` is the pair below them
## all, what the pack starts with. Nothing here advances on its own; the profile holds the stage.
##
## Positions are fractions of the room box (RoomSpace), so one room fits every screen. A floor spot stands at
## `x` across the width and `y` from the back wall; a wall spot hangs at `x` along its wall. Either has its
## base at `height`, which is how a cup stands on a table. `size` is the object's longest extent as a fraction of the room's width, and the camera is
## framed so that no spot projects smaller than the style's touch floor (CameraFraming).

## What the spot looks like. ObjectRecipes builds each kind from primitives; no art asset is needed.
enum Kind {
	CIRCLE = 0,
	DOOR = 1,
	LIGHT = 2,
	WINDOW = 3,
	BALL = 4,
	BED = 5,
	CUP = 6,
	SHOES = 7,
	TUB = 8,
	STAR = 9,
	TABLE = 10,
	SINK = 11,
	TOWEL = 12,
	SHELF = 13,
	BOOK = 14,
	SOFA = 15,
	BOWL = 16,
	CHAIR = 17,
	PLANT = 18,
	WALL_LIGHT = 19,
}

## How the spot moves when tapped. Every reaction multiplies by `Style.motion_scale()`.
enum Reaction {
	BOUNCE = 0,
	OPEN = 1,
	GLOW = 2,
	SPIN = 3,
	WOBBLE = 4,
	GROW = 5,
}

## Which wall a spot hangs on. NONE stands on the floor.
enum Wall {
	NONE = 0,
	BACK = 1,
	LEFT = 2,
	RIGHT = 3,
}

const _KIND_NAMES: Dictionary[String, int] = {
	"circle": Kind.CIRCLE, "door": Kind.DOOR, "light": Kind.LIGHT, "window": Kind.WINDOW,
	"ball": Kind.BALL, "bed": Kind.BED, "cup": Kind.CUP, "shoes": Kind.SHOES, "tub": Kind.TUB,
	"star": Kind.STAR, "table": Kind.TABLE,
	"sink": Kind.SINK,
	"towel": Kind.TOWEL,
	"shelf": Kind.SHELF,
	"book": Kind.BOOK,
	"sofa": Kind.SOFA,
	"bowl": Kind.BOWL,
	"chair": Kind.CHAIR,
	"plant": Kind.PLANT,
	"wall_light": Kind.WALL_LIGHT,
}
const _REACTION_NAMES: Dictionary[String, int] = {
	"bounce": Reaction.BOUNCE, "open": Reaction.OPEN, "glow": Reaction.GLOW, "spin": Reaction.SPIN,
	"wobble": Reaction.WOBBLE, "grow": Reaction.GROW,
}
const _WALL_NAMES: Dictionary[String, int] = {
	"none": Wall.NONE, "back": Wall.BACK, "left": Wall.LEFT, "right": Wall.RIGHT,
}

var id: String = ""
var kind: Kind = Kind.CIRCLE
var reaction: Reaction = Reaction.BOUNCE
var x: float = 0.5
var y: float = 0.5
var size: float = 0.18
var wall: Wall = Wall.NONE
## The base of the object as a fraction of the room's height: up a wall, or on top of something on the floor.
var height: float = 0.0
var gestalt_id: String = ""
var alt_gestalt_id: String = ""
## The phrase pair written for a stage, 1 to 6, keyed by that stage. A stage with no pair uses the nearest
## pair below it, and `gestalt_id` below them all.
var stage_gestalts: Dictionary[int, String] = {}
var stage_alts: Dictionary[int, String] = {}

## The gestalt the spot says at `stage`: the pair written for the nearest stage at or below it, else
## `gestalt_id`.
func gestalt_at(stage: NlaStage.Stage) -> String:
	var at: int = _stage_at(stage)
	return stage_gestalts[at] if at > 0 else gestalt_id

## The alternate at `stage`, from the same pair `gestalt_at` picks. Empty when that pair has none.
func alt_gestalt_at(stage: NlaStage.Stage) -> String:
	var at: int = _stage_at(stage)
	return stage_alts.get(at, "") if at > 0 else alt_gestalt_id

## Every gestalt id the spot names, at any stage, the base pair first.
func gestalt_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray([gestalt_id])
	if not alt_gestalt_id.is_empty():
		out.push_back(alt_gestalt_id)
	for stage: int in stage_gestalts.keys():
		out.push_back(stage_gestalts[stage])
		if stage_alts.has(stage):
			out.push_back(stage_alts[stage])
	return out

## The highest written stage at or below `stage`, or 0 for none.
func _stage_at(stage: NlaStage.Stage) -> int:
	var best: int = 0
	for written: int in stage_gestalts.keys():
		if written <= int(stage) and written > best:
			best = written
	return best

static func kind_name(k: Kind) -> String:
	return _name_of(_KIND_NAMES, k, "circle")

static func reaction_name(r: Reaction) -> String:
	return _name_of(_REACTION_NAMES, r, "bounce")

static func kind_from_name(name: String) -> Kind:
	var key: String = name.strip_edges().to_lower()
	if not _KIND_NAMES.has(key):
		return Kind.CIRCLE
	var value: int = _KIND_NAMES[key]
	return value as Kind

static func reaction_from_name(name: String) -> Reaction:
	var key: String = name.strip_edges().to_lower()
	if not _REACTION_NAMES.has(key):
		return Reaction.BOUNCE
	var value: int = _REACTION_NAMES[key]
	return value as Reaction

static func wall_name(w: Wall) -> String:
	return _name_of(_WALL_NAMES, w, "none")

static func wall_from_name(name: String) -> Wall:
	var key: String = name.strip_edges().to_lower()
	if not _WALL_NAMES.has(key):
		return Wall.NONE
	var value: int = _WALL_NAMES[key]
	return value as Wall

func to_dict() -> Dictionary:
	var d: Dictionary = {
		"id": id,
		"kind": kind_name(kind),
		"reaction": reaction_name(reaction),
		"x": x,
		"y": y,
		"size": size,
		"wall": wall_name(wall),
		"height": height,
		"gestalt": gestalt_id,
		"alt_gestalt": alt_gestalt_id,
	}
	if not stage_gestalts.is_empty():
		var stages: Dictionary = {}
		var written: Array[int] = []
		for stage: int in stage_gestalts.keys():
			written.push_back(stage)
		written.sort()
		for stage: int in written:
			var pair: Dictionary = {"gestalt": stage_gestalts[stage]}
			if stage_alts.has(stage):
				pair["alt_gestalt"] = stage_alts[stage]
			stages[str(stage)] = pair
		d["stages"] = stages
	return d

## A spot from a saved dictionary. Returns null for a missing id or gestalt. Position and size are clamped
## into range rather than rejected.
static func from_dict(d: Dictionary) -> Spot:
	var spot_id: String = JsonValue.to_text(d.get("id")).strip_edges()
	var gid: String = JsonValue.to_text(d.get("gestalt")).strip_edges()
	if spot_id.is_empty() or gid.is_empty():
		return null
	var s: Spot = Spot.new()
	s.id = spot_id
	s.gestalt_id = gid
	s.alt_gestalt_id = JsonValue.to_text(d.get("alt_gestalt")).strip_edges()
	s.kind = kind_from_name(JsonValue.to_text(d.get("kind"), "circle"))
	s.reaction = reaction_from_name(JsonValue.to_text(d.get("reaction"), "bounce"))
	s.x = clampf(JsonValue.to_float(d.get("x"), 0.5), 0.0, 1.0)
	s.y = clampf(JsonValue.to_float(d.get("y"), 0.5), 0.0, 1.0)
	s.size = clampf(JsonValue.to_float(d.get("size"), 0.18), 0.05, 0.6)
	s.wall = wall_from_name(JsonValue.to_text(d.get("wall"), "none"))
	s.height = clampf(JsonValue.to_float(d.get("height"), 0.0), 0.0, 0.9)
	# A stage pair is keyed by its stage, 1 to 6. A pair with no gestalt, or a key that is not a stage, is
	# skipped.
	var stages: Dictionary = JsonValue.to_dict(d.get("stages"))
	for raw_key: Variant in stages.keys():
		var stage: NlaStage.Stage = NlaStage.from_value(raw_key)
		var pair: Dictionary = JsonValue.to_dict(stages[raw_key])
		var stage_gid: String = JsonValue.to_text(pair.get("gestalt")).strip_edges()
		if stage == NlaStage.Stage.UNKNOWN or stage_gid.is_empty():
			continue
		s.stage_gestalts[int(stage)] = stage_gid
		var stage_alt: String = JsonValue.to_text(pair.get("alt_gestalt")).strip_edges()
		if not stage_alt.is_empty():
			s.stage_alts[int(stage)] = stage_alt
	return s

static func _name_of(names: Dictionary[String, int], value: int, fallback: String) -> String:
	for name: String in names.keys():
		if names[name] == value:
			return name
	return fallback

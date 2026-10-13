extends RefCounted
class_name Spot
## One responsive object in a [Room]: a door, a light, a ball. Tapping it does something visible and says
## its gestalt. A spot with an `alt_gestalt_id` alternates between two phrases as its state toggles, so a
## door says "Let's go outside" and then "Let's go inside".
##
## Positions are fractions of the room, so one room fits every screen. `size` is a fraction of the shorter
## screen edge and is floored at a touch target (RoomView).

## What the spot looks like. SpotView draws each kind from primitives; no art asset is needed.
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

const _KIND_NAMES: Dictionary[String, int] = {
	"circle": Kind.CIRCLE, "door": Kind.DOOR, "light": Kind.LIGHT, "window": Kind.WINDOW,
	"ball": Kind.BALL, "bed": Kind.BED, "cup": Kind.CUP, "shoes": Kind.SHOES, "tub": Kind.TUB,
	"star": Kind.STAR,
}
const _REACTION_NAMES: Dictionary[String, int] = {
	"bounce": Reaction.BOUNCE, "open": Reaction.OPEN, "glow": Reaction.GLOW, "spin": Reaction.SPIN,
	"wobble": Reaction.WOBBLE, "grow": Reaction.GROW,
}

var id: String = ""
var kind: Kind = Kind.CIRCLE
var reaction: Reaction = Reaction.BOUNCE
var x: float = 0.5
var y: float = 0.5
var size: float = 0.18
var gestalt_id: String = ""
var alt_gestalt_id: String = ""

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

func to_dict() -> Dictionary:
	return {
		"id": id,
		"kind": kind_name(kind),
		"reaction": reaction_name(reaction),
		"x": x,
		"y": y,
		"size": size,
		"gestalt": gestalt_id,
		"alt_gestalt": alt_gestalt_id,
	}

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
	return s

static func _name_of(names: Dictionary[String, int], value: int, fallback: String) -> String:
	for name: String in names.keys():
		if names[name] == value:
			return name
	return fallback

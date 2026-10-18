extends RefCounted
class_name Room
## A room is an explorable screen: a handful of [Spot]s the learner finds by touching them. It is the
## child-facing surface the app is built around (docs/design.md "Rooms"). A board is the plainer alternative.
##
## `camera` is the caregiver's knob for how much the learner can move the view (docs/geometry.md "Views").

## How much of the view widget the learner gets. FIXED is the front view only; VIEWS adds the Front and Top
## buttons with a pan and a zoom; TILT adds the Tilt button, a look around from the room's center. `orbit`
## in a saved file is read as TILT, from before Tilt replaced the orbit drag.
enum Camera {
	FIXED = 0,
	VIEWS = 1,
	TILT = 2,
}

const _CAMERA_NAMES: Dictionary[String, int] = {"fixed": Camera.FIXED, "views": Camera.VIEWS, "tilt": Camera.TILT, "orbit": Camera.TILT}

var id: String = ""
var title: String = ""
var camera: Camera = Camera.VIEWS
## Interior dimensions in metres. Legacy rooms keep the original box.
var width: float = 4.0
var depth: float = 3.0
var height: float = 2.6
var spots: Array[Spot] = []

static func camera_name(c: Camera) -> String:
	for name: String in _CAMERA_NAMES.keys():
		if _CAMERA_NAMES[name] == c:
			return name
	return "views"

static func camera_from_name(name: String) -> Camera:
	var key: String = name.strip_edges().to_lower()
	if not _CAMERA_NAMES.has(key):
		return Camera.VIEWS
	var value: int = _CAMERA_NAMES[key]
	return value as Camera

func to_dict() -> Dictionary:
	var spot_dicts: Array[Dictionary] = []
	for s: Spot in spots:
		spot_dicts.push_back(s.to_dict())
	return {"id": id, "title": title, "camera": camera_name(camera), "spots": spot_dicts, "width": width, "depth": depth, "height": height}

## A room from a saved dictionary. Returns null for a missing id. A spot that does not parse is skipped.
static func from_dict(d: Dictionary) -> Room:
	var room_id: String = JsonValue.to_text(d.get("id")).strip_edges()
	if room_id.is_empty():
		return null
	var r: Room = Room.new()
	r.id = room_id
	r.title = JsonValue.to_text(d.get("title"), room_id)
	r.width = _dimension(d.get("width"), 4.0, 2.4, 8.0)
	r.depth = _dimension(d.get("depth"), 3.0, 2.4, 8.0)
	r.height = _dimension(d.get("height"), 2.6, 2.2, 4.0)
	r.camera = camera_from_name(JsonValue.to_text(d.get("camera"), "views"))
	for row: Dictionary in JsonValue.to_dict_rows(d.get("spots")):
		var s: Spot = Spot.from_dict(row)
		if s != null:
			r.spots.push_back(s)
	return r

static func _dimension(value: Variant, fallback: float, low: float, high: float) -> float:
	var number: float = JsonValue.to_float(value, fallback)
	return clampf(number, low, high) if is_finite(number) else fallback

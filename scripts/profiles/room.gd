extends RefCounted
class_name Room
## A room is an explorable screen: a handful of [Spot]s the learner finds by touching them. It is the
## child-facing surface the app is built around (docs/design.md "Rooms"). A board is the plainer alternative.

var id: String = ""
var title: String = ""
var spots: Array[Spot] = []

func to_dict() -> Dictionary:
	var spot_dicts: Array[Dictionary] = []
	for s: Spot in spots:
		spot_dicts.push_back(s.to_dict())
	return {"id": id, "title": title, "spots": spot_dicts}

## A room from a saved dictionary. Returns null for a missing id. A spot that does not parse is skipped.
static func from_dict(d: Dictionary) -> Room:
	var room_id: String = JsonValue.to_text(d.get("id")).strip_edges()
	if room_id.is_empty():
		return null
	var r: Room = Room.new()
	r.id = room_id
	r.title = JsonValue.to_text(d.get("title"), room_id)
	for row: Dictionary in JsonValue.to_dict_rows(d.get("spots")):
		var s: Spot = Spot.from_dict(row)
		if s != null:
			r.spots.push_back(s)
	return r

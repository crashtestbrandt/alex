extends RefCounted
class_name Board
## A board is one child-facing screen of gestalt tiles: a room, a routine, a set of favorite lines. It names
## gestalts by id and owns nothing else, so one gestalt can sit on several boards.

var id: String = ""
var title: String = ""
var gestalt_ids: PackedStringArray = PackedStringArray()

static func make(board_id: String, board_title: String, ids: PackedStringArray) -> Board:
	var b: Board = Board.new()
	b.id = board_id
	b.title = board_title
	b.gestalt_ids = ids
	return b

func to_dict() -> Dictionary:
	return {"id": id, "title": title, "gestalts": Array(gestalt_ids)}

## A board from a saved dictionary. Returns null when there is no id.
static func from_dict(d: Dictionary) -> Board:
	var board_id: String = JsonValue.to_text(d.get("id")).strip_edges()
	if board_id.is_empty():
		return null
	var ids: PackedStringArray = PackedStringArray()
	for item: Variant in JsonValue.to_array(d.get("gestalts")):
		var gid: String = JsonValue.to_text(item).strip_edges()
		if not gid.is_empty():
			ids.push_back(gid)
	return make(board_id, JsonValue.to_text(d.get("title"), board_id), ids)

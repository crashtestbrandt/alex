extends RefCounted
class_name JsonValue
## Typed reads from a parsed JSON value. JSON hands every number back as a float and every missing key as
## null, and the project's warnings reject casting a Variant, so every reader here names its fallback and
## assigns through a typed var. Callers never cast.

static func to_int(v: Variant, fallback: int = 0) -> int:
	if v is int:
		var i: int = v
		return i
	if v is float:
		var f: float = v
		return int(f)
	if v is String:
		var s: String = v
		if s.is_valid_int():
			return s.to_int()
	return fallback

static func to_float(v: Variant, fallback: float = 0.0) -> float:
	if v is float:
		var f: float = v
		return f
	if v is int:
		var i: int = v
		return float(i)
	if v is String:
		var s: String = v
		if s.is_valid_float():
			return s.to_float()
	return fallback

static func to_text(v: Variant, fallback: String = "") -> String:
	if v is String:
		var s: String = v
		return s
	if v == null:
		return fallback
	return str(v)

## `v` as an Array, or an empty one for anything else.
static func to_array(v: Variant) -> Array:
	if v is Array:
		var a: Array = v
		return a
	return []

## `v` as a Dictionary, or an empty one for anything else.
static func to_dict(v: Variant) -> Dictionary:
	if v is Dictionary:
		var d: Dictionary = v
		return d
	return {}

## The dictionaries among `v`'s elements, for a list of rows. Anything that is not a dictionary is skipped.
static func to_dict_rows(v: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Variant in to_array(v):
		if item is Dictionary:
			var d: Dictionary = item
			out.push_back(d)
	return out

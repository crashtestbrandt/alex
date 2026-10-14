extends RefCounted
class_name ChunkBank
## What a bank offers Build, pure (docs/ui.md "Words"): its beginnings, the first chunk of every gestalt, and
## its endings, every later chunk, each once by the same key its color uses. And which gestalt an assembled
## strip is, so a familiar recording plays when the learner builds a phrase the bank holds.

## The id of the transient gestalt that voices a strip no bank gestalt matches.
const BUILD_ID: String = "build"

## The first chunk of every gestalt, in bank order, each once. The first spelling seen is kept.
static func beginnings(gestalts: Array[Gestalt]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var seen: Dictionary[String, bool] = {}
	for g: Gestalt in gestalts:
		if g.chunks.is_empty():
			continue
		_add_once(g.chunks[0], out, seen)
	return out

## Every chunk after the first, in bank order, each once. The first spelling seen is kept.
static func endings(gestalts: Array[Gestalt]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var seen: Dictionary[String, bool] = {}
	for g: Gestalt in gestalts:
		for i: int in range(1, g.chunks.size()):
			_add_once(g.chunks[i], out, seen)
	return out

## The gestalt whose text is `chunks` said in order, by the chunk key, or null. The first match in bank order
## wins, so a recorded phrase speaks in the voice the caregiver gave it.
static func find(gestalts: Array[Gestalt], chunks: PackedStringArray) -> Gestalt:
	if chunks.is_empty():
		return null
	var wanted: String = ChunkColors.key(" ".join(chunks))
	for g: Gestalt in gestalts:
		if ChunkColors.key(g.text) == wanted:
			return g
	return null

## A gestalt that says `chunks`, for a strip no bank gestalt matches. Its chunks are the strip's, so the
## caption and the strip pace the same seams.
static func phrase(chunks: PackedStringArray) -> Gestalt:
	return Gestalt.from_text(BUILD_ID, " | ".join(chunks))

## The gestalt that voices `chunks`: the bank's own when it has one, a transient one otherwise.
static func voice(gestalts: Array[Gestalt], chunks: PackedStringArray) -> Gestalt:
	var own: Gestalt = find(gestalts, chunks)
	return own if own != null else phrase(chunks)

static func _add_once(chunk: String, out: PackedStringArray, seen: Dictionary[String, bool]) -> void:
	var key: String = ChunkColors.key(chunk)
	if key.is_empty() or seen.has(key):
		return
	seen[key] = true
	out.push_back(chunk)

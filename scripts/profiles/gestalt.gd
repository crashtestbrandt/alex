extends RefCounted
class_name Gestalt
## One gestalt: a chunk of language the child uses or the adults model, with its mitigable chunks, where it
## came from, what it does for the child, and the recording that voices it.
##
## Authoring text marks chunk boundaries with `|`: "Let's go | to the park" is two chunks. The chunks are
## what the remix board recombines and what the tile animation pulls apart (docs/design.md). Text with no
## bar is one chunk, which is right for a Stage 1 gestalt that should stay whole.

## What the gestalt does for the child, in the adults' words.
enum Function {
	UNKNOWN = 0,
	REQUEST = 1,      ## asking for something
	PROTEST = 2,      ## refusing or stopping something
	COMMENT = 3,      ## noticing, sharing attention
	REGULATION = 4,   ## calming or steadying themselves
	GREETING = 5,     ## hello, goodbye, social routines
	ROUTINE = 6,      ## narrating a daily routine
}

const CHUNK_MARK: String = "|"

const _FUNCTION_NAMES: Dictionary[String, int] = {
	"unknown": Function.UNKNOWN,
	"request": Function.REQUEST,
	"protest": Function.PROTEST,
	"comment": Function.COMMENT,
	"regulation": Function.REGULATION,
	"greeting": Function.GREETING,
	"routine": Function.ROUTINE,
}

var id: String = ""
## The sentence as spoken, chunk marks removed.
var text: String = ""
## The mitigable chunks, in order. Never empty for a gestalt with text.
var chunks: PackedStringArray = PackedStringArray()
## Where it came from: a show, a song, a person. Free text.
var source: String = ""
var function: Function = Function.UNKNOWN
var stage: NlaStage.Stage = NlaStage.Stage.UNKNOWN
## A recording that voices it, as a path relative to the profile's media directory. Empty for none.
var recording: String = ""

## A gestalt from authoring text, chunked on `|`. Surrounding whitespace is trimmed from every chunk, and an
## empty chunk (two bars together, a trailing bar) is dropped.
static func from_text(gestalt_id: String, authored: String) -> Gestalt:
	var g: Gestalt = Gestalt.new()
	g.id = gestalt_id
	g.set_text(authored)
	return g

## Replace the text and re-derive the chunks from its `|` marks.
func set_text(authored: String) -> void:
	chunks = PackedStringArray()
	for raw: String in authored.split(CHUNK_MARK):
		var chunk: String = raw.strip_edges()
		if not chunk.is_empty():
			chunks.push_back(chunk)
	text = " ".join(chunks)

## The authoring form, chunks joined by ` | `, so an editor can round-trip it.
func authored_text() -> String:
	return " | ".join(chunks)

## The function name as it appears in a starter file or a saved profile.
static func function_name(f: Function) -> String:
	for name: String in _FUNCTION_NAMES.keys():
		if _FUNCTION_NAMES[name] == f:
			return name
	return "unknown"

## The Function for `name`, or UNKNOWN for a name the enum does not carry.
static func function_from_name(name: String) -> Function:
	var key: String = name.strip_edges().to_lower()
	if not _FUNCTION_NAMES.has(key):
		return Function.UNKNOWN
	var value: int = _FUNCTION_NAMES[key]
	return value as Function

func to_dict() -> Dictionary:
	return {
		"id": id,
		"text": authored_text(),
		"source": source,
		"function": function_name(function),
		"stage": int(stage),
		"recording": recording,
	}

## A gestalt from a saved dictionary. Returns null when there is no usable id or text.
static func from_dict(d: Dictionary) -> Gestalt:
	var gestalt_id: String = JsonValue.to_text(d.get("id")).strip_edges()
	var authored: String = JsonValue.to_text(d.get("text"))
	if gestalt_id.is_empty():
		return null
	var g: Gestalt = from_text(gestalt_id, authored)
	if g.chunks.is_empty():
		return null
	g.source = JsonValue.to_text(d.get("source"))
	g.function = function_from_name(JsonValue.to_text(d.get("function"), "unknown"))
	g.stage = NlaStage.from_value(d.get("stage"))
	g.recording = JsonValue.to_text(d.get("recording"))
	return g

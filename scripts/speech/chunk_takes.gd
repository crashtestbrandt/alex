extends RefCounted
class_name ChunkTakes
## A chunk's take: a recording keyed by the chunk's text, the same key as its color (`ChunkColors.key`), so
## one take serves every phrase the chunk appears in and every phrase Build assembles. A profile carries the
## map from key to a file under `media/chunks/` (`Profile.chunk_takes`). The playback choice for a gestalt
## is here too, pure, so `Speaker` only plays what [method plan] hands it and a unit suite covers the choice.

## The directory under `media/` that holds every chunk take.
const DIR: String = "chunks"
## The quiet between two chunk takes, in seconds.
const GAP_SECONDS: float = 0.15
## What a chunk said by the OS voice takes, in seconds. Rough; it paces the caption.
const TTS_CHUNK_SECONDS: float = 0.6
## How much of the key the file name keeps before the hash.
const SLUG_MAX: int = 32

## One stretch of an utterance: `text`, said from the file at `path` under the media directory, or by the
## OS voice when `path` is empty.
class Segment extends RefCounted:
	var text: String = ""
	var path: String = ""

	func _init(segment_text: String, take_path: String) -> void:
		text = segment_text
		path = take_path

	func is_recorded() -> bool:
		return not path.is_empty()

## What a take is keyed by: the chunk's color key, lowercased and trimmed.
static func key(chunk: String) -> String:
	return ChunkColors.key(chunk)

## The file a chunk's take is saved as: the key's ASCII letters and digits, then the key's hash, so two keys
## that differ only in punctuation or in a character a file system folds still get their own file.
static func file_name(chunk: String) -> String:
	var k: String = key(chunk)
	var slug: String = ""
	var last_was_gap: bool = true
	for ch: String in k:
		var code: int = ch.unicode_at(0)
		var alnum: bool = (code >= 97 and code <= 122) or (code >= 48 and code <= 57)
		if alnum:
			slug += ch
			last_was_gap = false
		elif not last_was_gap:
			slug += "_"
			last_was_gap = true
		if slug.length() >= SLUG_MAX:
			break
	slug = slug.trim_suffix("_")
	if slug.is_empty():
		slug = "chunk"
	return "%s-%08x.wav" % [slug, ChunkColors.hash_text(k)]

## Where a chunk's take lives, relative to the profile's media directory.
static func relative_path(chunk: String) -> String:
	return "%s/%s" % [DIR, file_name(chunk)]

## The take `takes` holds for `chunk`, relative to the media directory, or empty for none.
static func take_for(chunk: String, takes: Dictionary[String, String]) -> String:
	return takes.get(key(chunk), "")

## Whether `takes` holds a take for `chunk`.
static func has_take(chunk: String, takes: Dictionary[String, String]) -> bool:
	return not take_for(chunk, takes).is_empty()

## What voices `g`. The whole-phrase take when `g` has one. Otherwise one segment per chunk, each from its
## take or from the OS voice. A gestalt with no take at all is one OS segment of the whole text, so the OS
## voice keeps its own pacing.
static func plan(g: Gestalt, takes: Dictionary[String, String]) -> Array[Segment]:
	var out: Array[Segment] = []
	if not g.recording.is_empty():
		out.push_back(Segment.new(g.text, g.recording))
		return out
	var any_take: bool = false
	for chunk: String in g.chunks:
		var path: String = take_for(chunk, takes)
		any_take = any_take or not path.is_empty()
		out.push_back(Segment.new(chunk, path))
	if not any_take:
		out.clear()
		out.push_back(Segment.new(g.text, ""))
	return out

## Save `stream` as the take for `chunk` under `media_dir`, keeping the previous take beside it, and record it
## in `takes`. Returns the error, OK on success.
static func save(stream: AudioStreamWAV, chunk: String, media_dir: String, takes: Dictionary[String, String]) -> Error:
	var relative: String = relative_path(chunk)
	var err: Error = Recorder.save_at(stream, media_dir, relative)
	if err != OK:
		return err
	takes[key(chunk)] = relative
	return OK

## Remove the take for `chunk` and its previous take, and forget it in `takes`. Removing a chunk with no
## take is OK.
static func clear(chunk: String, media_dir: String, takes: Dictionary[String, String]) -> Error:
	var relative: String = take_for(chunk, takes)
	if relative.is_empty():
		return OK
	var err: Error = Recorder.remove_at(media_dir, relative)
	if err != OK:
		return err
	takes.erase(key(chunk))
	return OK

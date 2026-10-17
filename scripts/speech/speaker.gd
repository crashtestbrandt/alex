extends Node
class_name Speaker
## Voices a gestalt. The whole-phrase recording from the profile's media directory when there is one, else
## each chunk's take in order with a short gap between them, and the OS text-to-speech voice for a chunk with
## no take (`ChunkTakes.plan`). Recordings are the point of the app (docs/design.md); the synthetic voice is a
## placeholder so a freshly seeded profile still speaks.
##
## `started` carries the expected length in seconds so a tile or room can pace the chunks; `finished`
## follows when playback ends.

signal started(gestalt: Gestalt, seconds: float)
signal finished(gestalt: Gestalt)

var _player: AudioStreamPlayer = AudioStreamPlayer.new()
var _current: Gestalt = null
var _tts_voice: String = ""
## What is left to play of the current utterance, in order, each a stream or empty for the OS voice.
var _queue: Array[AudioStream] = []
var _queue_text: PackedStringArray = PackedStringArray()
## Bumped by every `say` and `stop`, so a gap timer from an earlier utterance plays nothing.
var _serial: int = 0
## The id the OS utterance playing now was spoken with (the serial at that time), or -1. A callback for any
## other id is stale: the cancel from `stop()` can arrive after the next `say()` has queued its segments.
var _tts_utterance: int = -1

func _ready() -> void:
	add_child(_player)
	_player.finished.connect(_on_player_finished)
	_tts_voice = _pick_tts_voice()

## Say `g`, stopping anything already playing. `media_dir` is the profile's recording directory and
## `chunk_takes` its per-chunk takes (`Profile.chunk_takes`).
func say(g: Gestalt, media_dir: String, chunk_takes: Dictionary[String, String] = {}) -> void:
	stop()
	_current = g
	var estimate: float = 0.0
	var segments: Array[ChunkTakes.Segment] = ChunkTakes.plan(g, chunk_takes)
	for segment: ChunkTakes.Segment in segments:
		var stream: AudioStream = null
		if segment.is_recorded():
			stream = _load_recording("%s/%s" % [media_dir, segment.path])
		if stream != null:
			estimate += stream.get_length()
		else:
			# A rough synthetic length: about 0.6 s per chunk reads naturally for an OS voice. One segment
			# for the whole phrase covers every chunk; otherwise a segment is one chunk.
			var covered: int = g.chunks.size() if segments.size() == 1 else 1
			estimate += ChunkTakes.TTS_CHUNK_SECONDS * maxi(covered, 1)
		_queue.push_back(stream)
		_queue_text.push_back(segment.text)
	estimate += ChunkTakes.GAP_SECONDS * maxi(_queue.size() - 1, 0)
	started.emit(g, estimate)
	_play_next()

func stop() -> void:
	_serial += 1
	_queue.clear()
	_queue_text.clear()
	if _player.playing:
		_player.stop()
	# Forget the utterance before cancelling it, so its cancel callback is stale whenever it arrives.
	_tts_utterance = -1
	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	_current = null

func is_speaking() -> bool:
	return _current != null

## Play the next segment of the queue, or finish when it is empty.
func _play_next() -> void:
	if _queue.is_empty():
		_finish()
		return
	var stream: AudioStream = _queue.pop_front()
	var text: String = _queue_text[0]
	_queue_text.remove_at(0)
	if stream != null:
		_player.stream = stream
		_player.play()
		return
	if _tts_voice.is_empty():
		# Nothing to play and nothing to synthesize. Move on so the picture still responds.
		_after_gap()
		return
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_tts_ended)
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_tts_ended)
	_tts_utterance = _serial
	DisplayServer.tts_speak(text, _tts_voice, 50, 1.0, 1.0, _tts_utterance, true)

## A short quiet between two segments, then the next one. Nothing between the last and the end.
func _after_gap() -> void:
	if _queue.is_empty():
		_play_next()
		return
	var serial: int = _serial
	get_tree().create_timer(ChunkTakes.GAP_SECONDS).timeout.connect(func() -> void:
		if serial == _serial:
			_play_next())

func _finish() -> void:
	var done: Gestalt = _current
	_current = null
	if done != null:
		finished.emit(done)

func _on_player_finished() -> void:
	_after_gap()

## The OS finished or cancelled an utterance. Only the one playing now moves the queue on.
func _on_tts_ended(utterance_id: int) -> void:
	if utterance_id != _tts_utterance or _current == null:
		return
	_tts_utterance = -1
	_after_gap()

## A recording by extension. Returns null, with the reason printed, for a file that cannot be loaded.
static func _load_recording(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		printerr("Speaker: recording missing at %s" % path)
		return null
	match path.get_extension().to_lower():
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		_:
			printerr("Speaker: unsupported recording format at %s (wav, ogg or mp3)" % path)
			return null

## The first OS voice for the device's language, or empty when the platform has none (a headless run).
static func _pick_tts_voice() -> String:
	var enabled: bool = ProjectSettings.get_setting("audio/general/text_to_speech", false)
	if not enabled:
		return ""
	var voices: PackedStringArray = DisplayServer.tts_get_voices_for_language(OS.get_locale_language())
	if voices.is_empty():
		return ""
	return voices[0]

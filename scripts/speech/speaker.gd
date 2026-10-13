extends Node
class_name Speaker
## Voices a gestalt. A recording from the profile's media directory when there is one, the OS text-to-speech
## voice when there is not. Recordings are the point of the app (docs/design.md); the synthetic voice is a
## placeholder so a freshly seeded profile still speaks.
##
## `started` carries the expected length in seconds so a tile or room can pace the chunks; `finished`
## follows when playback ends.

signal started(gestalt: Gestalt, seconds: float)
signal finished(gestalt: Gestalt)

var _player: AudioStreamPlayer = AudioStreamPlayer.new()
var _current: Gestalt = null
var _tts_voice: String = ""

func _ready() -> void:
	add_child(_player)
	_player.finished.connect(_on_player_finished)
	_tts_voice = _pick_tts_voice()

## Say `g`, stopping anything already playing. `media_dir` is the profile's recording directory.
func say(g: Gestalt, media_dir: String) -> void:
	stop()
	_current = g
	if not g.recording.is_empty():
		var stream: AudioStream = _load_recording("%s/%s" % [media_dir, g.recording])
		if stream != null:
			_player.stream = stream
			started.emit(g, stream.get_length())
			_player.play()
			return
	# A rough synthetic length: about 0.6 s per chunk reads naturally for an OS voice.
	var estimate: float = 0.6 * g.chunks.size()
	if _tts_voice.is_empty():
		# Nothing to play and nothing to synthesize. Report the estimate so the picture still responds.
		started.emit(g, estimate)
		_finish()
		return
	started.emit(g, estimate)
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_tts_ended)
	DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_tts_ended)
	DisplayServer.tts_speak(g.text, _tts_voice, 50, 1.0, 1.0, 0, true)

func stop() -> void:
	if _player.playing:
		_player.stop()
	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	_current = null

func is_speaking() -> bool:
	return _current != null

func _finish() -> void:
	var done: Gestalt = _current
	_current = null
	if done != null:
		finished.emit(done)

func _on_player_finished() -> void:
	_finish()

func _on_tts_ended(_utterance_id: int) -> void:
	_finish()

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

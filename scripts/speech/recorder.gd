extends Node
class_name Recorder
## Records the device microphone into an [AudioStreamWAV]. A `Record` bus with an [AudioEffectRecord] is
## created at runtime and muted, so the microphone never plays back through the speakers while recording.
##
## Needs `audio/driver/enable_input` on in project.godot, and on iOS and Android a microphone permission in
## the export preset (docs/profiles.md "Recordings").

const BUS_NAME: String = "Record"

var _effect: AudioEffectRecord = null
var _mic: AudioStreamPlayer = null

func _ready() -> void:
	var enabled: bool = ProjectSettings.get_setting("audio/driver/enable_input", false)
	if not enabled:
		return
	var index: int = AudioServer.get_bus_index(BUS_NAME)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, BUS_NAME)
		AudioServer.set_bus_mute(index, true)
	_effect = AudioEffectRecord.new()
	_effect.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(index, _effect)
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = BUS_NAME
	add_child(_mic)

## Whether a microphone can be recorded on this device and build.
func is_available() -> bool:
	return _effect != null

func is_recording() -> bool:
	return _effect != null and _effect.is_recording_active()

func start() -> void:
	if _effect == null:
		return
	_mic.play()
	_effect.set_recording_active(true)

## Stop and return what was recorded, or null when nothing was.
func stop() -> AudioStreamWAV:
	if _effect == null or not _effect.is_recording_active():
		return null
	_effect.set_recording_active(false)
	_mic.stop()
	return _effect.get_recording()

## The file name a gestalt's recording takes under the profile's media directory.
static func file_name(gestalt_id: String) -> String:
	return "%s.wav" % gestalt_id

## Save `stream` as the recording for `g`, keeping the previous take beside it as `<id>.prev.wav`. Updates
## `g.recording` on success. Returns the error, OK on success.
static func save(stream: AudioStreamWAV, g: Gestalt, media_dir: String) -> Error:
	var err: Error = DirAccess.make_dir_recursive_absolute(media_dir)
	if err != OK:
		return err
	var name: String = file_name(g.id)
	var path: String = "%s/%s" % [media_dir, name]
	if FileAccess.file_exists(path):
		var previous: String = "%s/%s.prev.wav" % [media_dir, g.id]
		if FileAccess.file_exists(previous):
			DirAccess.remove_absolute(previous)
		err = DirAccess.rename_absolute(path, previous)
		if err != OK:
			return err
	err = stream.save_to_wav(path)
	if err != OK:
		return err
	g.recording = name
	return OK

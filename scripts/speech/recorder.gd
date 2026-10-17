extends Node
class_name Recorder
## Records the device microphone into an [AudioStreamWAV]. A `Record` bus with an [AudioEffectRecord] is
## created at runtime and muted, so the microphone never plays back through the speakers while recording.
##
## Needs `audio/driver/enable_input` on in project.godot, and on iOS and Android a microphone permission in
## the export preset (docs/profiles.md "Recordings").

## Emitted with Android's answer to [method ensure_permission].
signal permission_answered(granted: bool)

const BUS_NAME: String = "Record"
## Android asks for this at run time. iOS and macOS ask by themselves the first time the microphone opens.
const ANDROID_MIC_PERMISSION: String = "android.permission.RECORD_AUDIO"

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

## Whether the microphone may be recorded now. On Android a missing permission is requested, the system
## dialog shows, and [signal permission_answered] carries the answer.
func ensure_permission() -> bool:
	if OS.get_name() != "Android":
		return true
	var tree: SceneTree = get_tree()
	if not tree.on_request_permissions_result.is_connected(_on_permission_result):
		tree.on_request_permissions_result.connect(_on_permission_result)
	return OS.request_permission(ANDROID_MIC_PERMISSION)

func _on_permission_result(permission: String, granted: bool) -> void:
	if permission == ANDROID_MIC_PERMISSION:
		permission_answered.emit(granted)

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

## The name the previous take keeps beside `name`: `<stem>.prev.<extension>`.
static func previous_name(name: String) -> String:
	return "%s.prev.%s" % [name.get_basename(), name.get_extension()]

## Save `stream` as the recording for `g`, keeping the previous take beside it as `<id>.prev.wav`. Updates
## `g.recording` on success. Returns the error, OK on success.
static func save(stream: AudioStreamWAV, g: Gestalt, media_dir: String) -> Error:
	var name: String = file_name(g.id)
	var err: Error = save_at(stream, media_dir, name)
	if err != OK:
		return err
	g.recording = name
	return OK

## Save `stream` at `relative` under `media_dir`, creating the directory and keeping a take already there as
## the previous take ([method previous_name]). Returns the error, OK on success.
static func save_at(stream: AudioStreamWAV, media_dir: String, relative: String) -> Error:
	var path: String = media_dir.path_join(relative)
	var err: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	if FileAccess.file_exists(path):
		var previous: String = media_dir.path_join(previous_name(relative))
		if FileAccess.file_exists(previous):
			DirAccess.remove_absolute(previous)
		err = DirAccess.rename_absolute(path, previous)
		if err != OK:
			return err
	return stream.save_to_wav(path)

## Remove the take at `relative` under `media_dir` and its previous take. A take already gone is OK.
static func remove_at(media_dir: String, relative: String) -> Error:
	for name: String in [relative, previous_name(relative)]:
		var path: String = media_dir.path_join(name)
		if not FileAccess.file_exists(path):
			continue
		var err: Error = DirAccess.remove_absolute(path)
		if err != OK:
			return err
	return OK

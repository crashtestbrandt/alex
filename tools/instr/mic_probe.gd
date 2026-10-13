extends Node
## Microphone probe: record a second and a half of ambient sound through [Recorder], check that a stream of
## about that length comes back, save it under user://, and remove it. Needs a real audio device, so it runs
## windowed (`just mic-probe`) and stays out of `just check`. Prints MIC-PROBE PASS or FAIL and exits with
## the matching code. On macOS the first run triggers the microphone permission prompt; a denied prompt
## shows up here as a stream of silence rather than a failure, so listen to the level it prints.

const _SECONDS: float = 1.5

var _failures: PackedStringArray = PackedStringArray()

func _ready() -> void:
	_run()

func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures.push_back(label)
		print("  FAIL %s" % label)

func _run() -> void:
	var recorder: Recorder = Recorder.new()
	add_child(recorder)
	await get_tree().process_frame
	_check(recorder.is_available(), "a Record bus with an AudioEffectRecord exists")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Recorder.BUS_NAME)), "the Record bus is muted")
	if not recorder.is_available():
		_finish()
		return
	recorder.start()
	_check(recorder.is_recording(), "recording started")
	await get_tree().create_timer(_SECONDS).timeout
	var take: AudioStreamWAV = recorder.stop()
	_check(take != null, "a stream came back")
	if take == null:
		_finish()
		return
	var length: float = take.get_length()
	print("  took %.2f s, %d bytes, mix rate %d, stereo %s" % [length, take.data.size(), take.mix_rate, take.stereo])
	_check(length >= _SECONDS * 0.8 and length <= _SECONDS * 1.5, "the take is about %.1f s long (got %.2f)" % [_SECONDS, length])
	_check(take.data.size() > 0, "the take holds samples")
	print("  peak level %.4f (0 means silence: the mic may be denied or muted)" % _peak(take))

	var g: Gestalt = Gestalt.from_text("mic_probe", "mic | probe")
	var dir: String = "user://mic-probe-%08x" % (randi() % 0x7fffffff)
	var err: Error = Recorder.save(take, g, dir)
	_check(err == OK, "save returns OK (%s)" % error_string(err))
	var path: String = "%s/%s" % [dir, g.recording]
	_check(FileAccess.file_exists(path), "the wav exists at %s" % path)
	var reloaded: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
	_check(reloaded != null and absf(reloaded.get_length() - length) < 0.05, "the wav reloads at the same length")
	err = Recorder.save(take, g, dir)
	_check(err == OK and FileAccess.file_exists("%s/mic_probe.prev.wav" % dir), "a second save keeps the previous take")
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute("%s/%s" % [dir, file])
	DirAccess.remove_absolute(dir)
	_finish()

static func _peak(take: AudioStreamWAV) -> float:
	var data: PackedByteArray = take.data
	var peak: int = 0
	var i: int = 0
	while i + 1 < data.size():
		var sample: int = data.decode_s16(i)
		peak = maxi(peak, absi(sample))
		i += 2
	return float(peak) / 32768.0

func _finish() -> void:
	if _failures.is_empty():
		print("MIC-PROBE PASS")
		get_tree().quit(0)
	else:
		print("MIC-PROBE FAIL (%d)" % _failures.size())
		get_tree().quit(1)

extends UnitTest
## Synthetic PCM only; no microphone, personal recordings, or imported audio.

func _take(amplitude: float, noise: float = 0.0, stereo: bool = false, rate: int = 16000) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = stereo
	var channels: int = 2 if stereo else 1
	var data: PackedByteArray = PackedByteArray()
	data.resize(rate * 2 * 2 * channels)
	for i: int in rate * 2:
		var t: float = float(i) / rate
		var speech: bool = (t >= 0.4 and t < 0.9) or (t >= 1.2 and t < 1.6)
		var value: float = noise * sin(TAU * 200.0 * t)
		if speech:
			value += amplitude * sin(TAU * 700.0 * t)
		var pcm: int = int(value * 32767.0)
		data.encode_s16(i * 2 * channels, pcm)
		if stereo:
			data.encode_s16(i * 4 + 2, -pcm)
	wav.data = data
	return wav

func _rms(wav: AudioStreamWAV) -> float:
	var samples: PackedFloat32Array = RecordingCleanup._decode(wav)
	var energy: float = 0.0
	for sample: float in samples:
		energy += sample * sample
	return sqrt(energy / maxi(samples.size(), 1))

func test_silence_and_empty_take_are_rejected() -> void:
	assert_null(RecordingCleanup.process(_take(0.0)), "silence does not become loud hiss")
	var empty: AudioStreamWAV = _take(0.0)
	empty.data = PackedByteArray()
	assert_null(RecordingCleanup.process(empty), "empty PCM")
	assert_null(RecordingCleanup.process(null), "no stream")

func test_trims_ends_but_preserves_internal_pause() -> void:
	var raw: AudioStreamWAV = _take(0.2)
	var cleaned: AudioStreamWAV = RecordingCleanup.process(raw)
	assert_not_null(cleaned, "speech kept")
	assert_true(cleaned.get_length() > 1.35 and cleaned.get_length() < 1.5, "speech and pause plus padded ends")
	assert_eq(raw.get_length(), 2.0, "input remains available")
	var samples: PackedFloat32Array = RecordingCleanup._decode(cleaned)
	var quiet: int = 0
	for i: int in range(10000, 13000):
		if absf(samples[i]) < 0.001:
			quiet += 1
	assert_true(quiet > 2000, "pause inside the phrase stays quiet")

func test_balances_loud_and_quiet_speech_without_clipping() -> void:
	var quiet: AudioStreamWAV = RecordingCleanup.process(_take(0.08))
	var loud: AudioStreamWAV = RecordingCleanup.process(_take(0.8))
	assert_almost_eq(_rms(quiet), _rms(loud), 0.01, "takes reach a similar speech level")
	for value: float in RecordingCleanup._decode(loud):
		if absf(value) > RecordingCleanup.PEAK_LIMIT + 0.001:
			assert_true(false, "peak headroom")
			return
	assert_true(true, "all samples stay below peak limit")

func test_inverted_stereo_does_not_cancel_the_voice() -> void:
	var cleaned: AudioStreamWAV = RecordingCleanup.process(_take(0.2, 0.0, true, 48000))
	assert_not_null(cleaned, "inverted stereo still speaks")
	assert_false(cleaned.stereo, "balanced mono output")
	assert_eq(cleaned.mix_rate, 48000, "sample rate preserved")
	assert_true(_rms(cleaned) > 0.1, "voice preserved")

func test_reduces_stationary_noise_during_speech() -> void:
	var raw: AudioStreamWAV = _take(0.2, 0.02)
	var samples: PackedFloat32Array = RecordingCleanup._decode(raw)
	var levels: PackedFloat32Array = RecordingCleanup._levels(samples)
	var cleaned: PackedFloat32Array = RecordingCleanup._denoise(samples, levels, 0.0142)
	var before: float = _tone(samples, 200.0)
	var after: float = _tone(cleaned, 200.0)
	assert_true(after < before * 0.4, "background tone reduced during speech")
	assert_true(_tone(cleaned, 700.0) > _tone(samples, 700.0) * 0.85, "speech tone preserved")

func _tone(samples: PackedFloat32Array, hz: float) -> float:
	var real: float = 0.0
	var imaginary: float = 0.0
	for i: int in range(8000, 12800):
		var angle: float = TAU * hz * i / 16000.0
		real += samples[i] * cos(angle)
		imaginary += samples[i] * sin(angle)
	return Vector2(real, imaginary).length() / 2400.0

func test_continuous_speech_and_short_buffers_are_safe() -> void:
	var raw: AudioStreamWAV = _take(0.2)
	raw.data = raw.data.slice(14000, 26000)
	var cleaned: AudioStreamWAV = RecordingCleanup.process(raw)
	assert_not_null(cleaned, "continuous speech kept without learning it as noise")
	assert_almost_eq(cleaned.get_length(), raw.get_length(), 0.01, "no forced trimming")
	raw.data = raw.data.slice(0, 40)
	assert_not_null(RecordingCleanup.process(raw), "partial FFT window is safe")

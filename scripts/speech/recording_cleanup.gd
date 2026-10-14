extends RefCounted
class_name RecordingCleanup
## Local PCM cleanup before preview: remove rumble, reduce steady background noise, trim only the ends,
## and balance speech level with peak headroom. No model, network, or external dependency.

const FFT_SIZE: int = 512
const HOP: int = FFT_SIZE / 2
const QUIET_RMS: float = 0.002
const TARGET_RMS: float = 0.16
const PEAK_LIMIT: float = 0.89
const MAX_GAIN: float = 4.0

## The recorder produces signed 16-bit PCM. Unsupported input is left untouched.
static func process(stream: AudioStreamWAV) -> AudioStreamWAV:
	if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.mix_rate <= 0:
		return stream
	var samples: PackedFloat32Array = _decode(stream)
	if samples.is_empty():
		return null
	_high_pass(samples, stream.mix_rate)
	var levels: PackedFloat32Array = _levels(samples)
	var peak_level: float = _maximum(levels)
	if peak_level < QUIET_RMS:
		return null
	var ordered: PackedFloat32Array = levels.duplicate()
	ordered.sort()
	var noise_level: float = ordered[int(ordered.size() * 0.1)]
	# Only learn noise from a pause quieter than speech. Continuous speech gets no spectral subtraction.
	if noise_level < peak_level * 0.25 and noise_level > 0.00001:
		samples = _denoise(samples, levels, noise_level)
		levels = _levels(samples)
	var threshold: float = maxf(QUIET_RMS, peak_level * 0.06)
	var first: int = 0
	var last: int = levels.size() - 1
	while first <= last and levels[first] < threshold:
		first += 1
	while last >= first and levels[last] < threshold:
		last -= 1
	if first > last:
		return null
	# Leave 100 ms around speech and preserve all pauses inside it.
	var padding: int = int(stream.mix_rate * 0.1)
	var begin: int = maxi(0, first * HOP - padding)
	var end: int = mini(samples.size(), last * HOP + FFT_SIZE + padding)
	var peak: float = 0.0
	var energy: float = 0.0
	var voiced: int = 0
	for i: int in range(begin, end):
		peak = maxf(peak, absf(samples[i]))
		if levels[mini(i / HOP, levels.size() - 1)] >= threshold:
			energy += samples[i] * samples[i]
			voiced += 1
	var rms: float = sqrt(energy / maxi(voiced, 1))
	var gain: float = minf(MAX_GAIN, minf(TARGET_RMS / maxf(rms, 0.00001), PEAK_LIMIT / maxf(peak, 0.00001)))
	var data: PackedByteArray = PackedByteArray()
	data.resize((end - begin) * 2)
	var fade: int = maxi(1, int(stream.mix_rate * 0.005))
	for i: int in range(begin, end):
		var envelope: float = minf(1.0, float(mini(i - begin, end - 1 - i)) / fade)
		var value: int = int(roundf(clampf(samples[i] * gain * envelope, -PEAK_LIMIT, PEAK_LIMIT) * 32767.0))
		data.encode_s16((i - begin) * 2, value)
	var cleaned: AudioStreamWAV = AudioStreamWAV.new()
	cleaned.format = AudioStreamWAV.FORMAT_16_BITS
	cleaned.mix_rate = stream.mix_rate
	cleaned.stereo = false
	cleaned.data = data
	return cleaned

## Pick the stronger microphone channel; averaging can erase speech in inverted stereo captures.
static func _decode(stream: AudioStreamWAV) -> PackedFloat32Array:
	var data: PackedByteArray = stream.data
	var channels: int = 2 if stream.stereo else 1
	var count: int = data.size() / (2 * channels)
	var channel: int = 0
	if channels == 2:
		var left: float = 0.0
		var right: float = 0.0
		for i: int in count:
			left += pow(float(data.decode_s16(i * 4)), 2)
			right += pow(float(data.decode_s16(i * 4 + 2)), 2)
		channel = 1 if right > left else 0
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		samples[i] = data.decode_s16((i * channels + channel) * 2) / 32768.0
	return samples

static func _high_pass(samples: PackedFloat32Array, rate: int) -> void:
	var alpha: float = exp(-TAU * 70.0 / rate)
	var previous: float = 0.0
	var filtered: float = 0.0
	for i: int in samples.size():
		var current: float = samples[i]
		filtered = alpha * (filtered + current - previous)
		previous = current
		samples[i] = filtered

static func _levels(samples: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for start: int in range(0, samples.size(), HOP):
		var energy: float = 0.0
		var end: int = mini(start + FFT_SIZE, samples.size())
		for i: int in range(start, end):
			energy += samples[i] * samples[i]
		out.push_back(sqrt(energy / (end - start)))
	return out

static func _maximum(values: PackedFloat32Array) -> float:
	var highest: float = 0.0
	for value: float in values:
		highest = maxf(highest, value)
	return highest

static func _spectrum(samples: PackedFloat32Array, start: int) -> PackedVector2Array:
	var bins: PackedVector2Array = PackedVector2Array()
	bins.resize(FFT_SIZE)
	for i: int in FFT_SIZE:
		var index: int = start + i
		if index >= 0 and index < samples.size():
			bins[i] = Vector2(samples[index] * _window(i), 0.0)
	return _fft(bins, false)

static func _window(i: int) -> float:
	return 0.5 - 0.5 * cos(TAU * i / FFT_SIZE)

static func _denoise(samples: PackedFloat32Array, levels: PackedFloat32Array, noise_level: float) -> PackedFloat32Array:
	var noise: PackedFloat32Array = PackedFloat32Array()
	noise.resize(FFT_SIZE)
	var frames: int = 0
	for frame: int in levels.size():
		if levels[frame] > noise_level * 1.2 or frame * HOP + FFT_SIZE > samples.size():
			continue
		var bins: PackedVector2Array = _spectrum(samples, frame * HOP)
		for i: int in FFT_SIZE:
			noise[i] += bins[i].length_squared()
		frames += 1
	if frames == 0:
		return samples
	for i: int in FFT_SIZE:
		noise[i] /= frames
	var out: PackedFloat32Array = PackedFloat32Array()
	var weight: PackedFloat32Array = PackedFloat32Array()
	out.resize(samples.size())
	weight.resize(samples.size())
	for start: int in range(-HOP, samples.size(), HOP):
		var bins: PackedVector2Array = _spectrum(samples, start)
		for i: int in FFT_SIZE:
			var power: float = bins[i].length_squared()
			# A gain floor avoids hard gating and musical-noise artifacts.
			var gain: float = sqrt(maxf(0.015, 1.0 - 1.5 * noise[i] / maxf(power, 0.00000001)))
			bins[i] *= gain
		var wave: PackedVector2Array = _fft(bins, true)
		for i: int in FFT_SIZE:
			var index: int = start + i
			if index >= 0 and index < samples.size():
				var window: float = _window(i)
				out[index] += wave[i].x * window
				weight[index] += window * window
	for i: int in samples.size():
		out[i] /= maxf(weight[i], 0.00001)
	return out

## Radix-2 transform, with inverse normalization.
static func _fft(bins: PackedVector2Array, inverse: bool) -> PackedVector2Array:
	var count: int = bins.size()
	var j: int = 0
	for i: int in range(1, count):
		var bit: int = count >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j ^= bit
		if i < j:
			var swap: Vector2 = bins[i]
			bins[i] = bins[j]
			bins[j] = swap
	var length: int = 2
	while length <= count:
		var angle: float = (TAU if inverse else -TAU) / length
		var step: Vector2 = Vector2(cos(angle), sin(angle))
		for start: int in range(0, count, length):
			var factor: Vector2 = Vector2(1.0, 0.0)
			for k: int in length / 2:
				var even: Vector2 = bins[start + k]
				var odd: Vector2 = bins[start + k + length / 2]
				var product: Vector2 = Vector2(odd.x * factor.x - odd.y * factor.y, odd.x * factor.y + odd.y * factor.x)
				bins[start + k] = even + product
				bins[start + k + length / 2] = even - product
				factor = Vector2(factor.x * step.x - factor.y * step.y, factor.x * step.y + factor.y * step.x)
		length *= 2
	if inverse:
		for i: int in count:
			bins[i] /= count
	return bins

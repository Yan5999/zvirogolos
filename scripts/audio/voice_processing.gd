class_name VoiceProcessing
extends RefCounted
## Постобработка записи: моно, удаление DC-смещения, обрезка тишины в начале и
## конце, ограничение длины, нормализация пика, короткие фейды. Работает напрямую
## с PackedByteArray данных AudioStreamWAV (PCM 8/16 бит).

const MAX_SECONDS: float = 5.0
## Сколько секунд максимум декодировать из пользовательского файла.
const MAX_DECODE_SECONDS: float = 30.0
const TARGET_PEAK_DB: float = -1.0
const MAX_GAIN_DB: float = 30.0
## Пик ниже этого (≈ -50 dBFS) считаем тишиной — вероятно, нет доступа к микрофону.
const SILENCE_PEAK: float = 0.003
const PRE_ROLL: float = 0.03
const POST_ROLL: float = 0.08
const FADE: float = 0.008


class Result:
	extends RefCounted
	var ok: bool = false
	var silent: bool = false
	var stream: AudioStreamWAV
	var duration: float = 0.0
	var message: String = ""


static func process(wav: AudioStreamWAV, max_seconds: float = MAX_SECONDS) -> Result:
	var r: Result = Result.new()
	if wav == null or wav.data.is_empty():
		r.silent = true
		r.message = "Запис порожній."
		return r
	var rate: int = wav.mix_rate
	var s: PackedFloat32Array = decode_mono(wav, int(MAX_DECODE_SECONDS * rate))
	if s.is_empty():
		r.message = "Формат не підтримується: потрібен нестиснений WAV (PCM 8 або 16 біт)."
		return r
	var n: int = s.size()

	var mean: float = 0.0
	for i: int in n:
		mean += s[i]
	mean /= float(n)
	var pk: float = 0.0
	for i: int in n:
		var v: float = s[i] - mean
		s[i] = v
		pk = maxf(pk, absf(v))
	if pk < SILENCE_PEAK:
		r.silent = true
		r.message = "У записі тиша."
		return r

	var thr: float = maxf(pk * 0.08, 0.006)
	var first: int = 0
	while first < n and absf(s[first]) < thr:
		first += 1
	var last: int = n - 1
	while last > first and absf(s[last]) < thr:
		last -= 1
	first = maxi(0, first - int(PRE_ROLL * rate))
	last = mini(n - 1, last + int(POST_ROLL * rate))
	var length: int = mini(last - first + 1, int(max_seconds * rate))

	var gain: float = minf(db_to_linear(TARGET_PEAK_DB) / pk, db_to_linear(MAX_GAIN_DB))
	var fade: int = maxi(1, int(FADE * rate))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(length)
	for i: int in length:
		var v: float = s[first + i] * gain
		if i < fade:
			v *= float(i) / float(fade)
		elif i > length - fade:
			v *= float(length - i) / float(fade)
		out[i] = v

	r.stream = encode_wav(out, rate)
	r.duration = float(length) / float(rate)
	r.ok = true
	return r


## Декодирует PCM в моно float [-1..1]. Пустой массив — формат не поддержан.
static func decode_mono(wav: AudioStreamWAV, max_frames: int = -1) -> PackedFloat32Array:
	var data: PackedByteArray = wav.data
	var channels: int = 2 if wav.stereo else 1
	var out: PackedFloat32Array = PackedFloat32Array()
	match wav.format:
		AudioStreamWAV.FORMAT_16_BITS:
			var frames: int = data.size() / (2 * channels)
			if max_frames > 0:
				frames = mini(frames, max_frames)
			out.resize(frames)
			for f: int in frames:
				var o: int = f * 2 * channels
				var v: float = float(data.decode_s16(o))
				if channels == 2:
					v = (v + float(data.decode_s16(o + 2))) * 0.5
				out[f] = v / 32768.0
		AudioStreamWAV.FORMAT_8_BITS:
			var frames8: int = data.size() / channels
			if max_frames > 0:
				frames8 = mini(frames8, max_frames)
			out.resize(frames8)
			for f: int in frames8:
				var o8: int = f * channels
				var v8: float = float(data.decode_s8(o8))
				if channels == 2:
					v8 = (v8 + float(data.decode_s8(o8 + 1))) * 0.5
				out[f] = v8 / 128.0
		_:
			pass
	return out


static func encode_wav(samples: PackedFloat32Array, mix_rate: int) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = bytes
	return wav


static func duration_of(wav: AudioStreamWAV) -> float:
	if wav == null:
		return 0.0
	return wav.get_length()

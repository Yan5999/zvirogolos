class_name Synth
extends RefCounted
## Процедурний синтез: музика за біомами й порою доби, фонові звуки, кроки та голоси довкілля.
## Усе детерміноване й оригінальне (жодних зовнішніх ассетів). Чисті статичні функції без вузлів,
## тому безпечні для виклику з WorkerThreadPool.

const RATE: int = 16000
const LOOP_SECONDS: float = 16.0
const MENU_KEY: int = 8

const MAJOR: Array[int] = [0, 2, 4, 5, 7, 9, 11]
const DORIAN: Array[int] = [0, 2, 3, 5, 7, 9, 10]
const AEOLIAN: Array[int] = [0, 2, 3, 5, 7, 8, 10]
const LYDIAN: Array[int] = [0, 2, 4, 6, 7, 9, 11]
const PHRYGIAN_DOMINANT: Array[int] = [0, 1, 4, 5, 7, 8, 10]

enum Timbre { PLUCK, MARIMBA, REED, BELL }


## Ключ доріжки: біом (0..3) + 4 уночі; MENU_KEY — тема меню.
static func track_key(biome: int, night: bool) -> int:
	return clampi(biome, 0, 3) + (4 if night else 0)


static func _config(key: int) -> Dictionary:
	if key == MENU_KEY:
		return {"root": 196.0, "mode": MAJOR, "prog": [0, 5, 3, 4], "timbre": Timbre.PLUCK, "density": 0.55, "seed": 77, "pad": 1.0, "bass": 0.9}
	var night: bool = key >= 4
	match key % 4:
		0:  # Ліс: тепла пентатонічна пастораль / нічний доричний
			if night:
				return {"root": 146.83, "mode": DORIAN, "prog": [0, 3, 0, 4], "timbre": Timbre.BELL, "density": 0.28, "seed": 11, "pad": 1.25, "bass": 1.0}
			return {"root": 146.83, "mode": MAJOR, "prog": [0, 4, 5, 3], "timbre": Timbre.PLUCK, "density": 0.55, "seed": 12, "pad": 1.0, "bass": 0.8}
		1:  # Пустеля: фрігійський домінантний, тягучі «очеретяні» ноти
			if night:
				return {"root": 164.81, "mode": PHRYGIAN_DOMINANT, "prog": [0, 0, 1, 0], "timbre": Timbre.REED, "density": 0.2, "seed": 21, "pad": 1.3, "bass": 1.1}
			return {"root": 164.81, "mode": PHRYGIAN_DOMINANT, "prog": [0, 1, 0, 4], "timbre": Timbre.REED, "density": 0.38, "seed": 22, "pad": 1.0, "bass": 0.9}
		2:  # Озеро: ліддійський, марімба-краплі
			if night:
				return {"root": 174.61, "mode": AEOLIAN, "prog": [0, 5, 2, 6], "timbre": Timbre.MARIMBA, "density": 0.3, "seed": 31, "pad": 1.2, "bass": 0.9}
			return {"root": 174.61, "mode": LYDIAN, "prog": [0, 1, 5, 4], "timbre": Timbre.MARIMBA, "density": 0.5, "seed": 32, "pad": 1.0, "bass": 0.8}
		_:  # Сніги: еолійський мінор, рідкі дзвіночки
			if night:
				return {"root": 110.0, "mode": AEOLIAN, "prog": [0, 5, 3, 6], "timbre": Timbre.BELL, "density": 0.2, "seed": 41, "pad": 1.4, "bass": 1.0}
			return {"root": 220.0, "mode": AEOLIAN, "prog": [0, 5, 2, 6], "timbre": Timbre.BELL, "density": 0.32, "seed": 42, "pad": 1.0, "bass": 0.6}


static func _degree_freq(root: float, mode: Array[int], degree: int) -> float:
	var oct: int = floori(float(degree) / 7.0)
	var semis: int = mode[posmod(degree, 7)] + 12 * oct
	return root * pow(2.0, float(semis) / 12.0)


## Зациклений трек ~16 с: педи-акорди + бас + розріджена мелодія. Може викликатись з потоку.
static func build_track(key: int) -> AudioStreamWAV:
	var cfg: Dictionary = _config(key)
	var root: float = cfg["root"]
	var mode: Array[int] = cfg["mode"]
	var prog: Array = cfg["prog"]
	var timbre: int = cfg["timbre"]
	var n: int = int(LOOP_SECONDS * RATE)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	var chord_len: float = LOOP_SECONDS / 4.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(cfg["seed"])
	var pad_amp: float = 0.085 * float(cfg["pad"])
	for c: int in 4:
		var d: int = int(prog[c])
		var centre: float = (float(c) + 0.5) * chord_len
		var seg: float = chord_len * 1.35
		var start: int = int((centre - seg * 0.5) * RATE)
		for tone: int in 3:
			var f: float = _degree_freq(root, mode, d + tone * 2)
			_add_pad(buf, start, seg, f, pad_amp)
		_add_pad(buf, start, seg, _degree_freq(root, mode, d) * 0.5, 0.17 * float(cfg["bass"]))
	# Мелодія: 32 півсекундні слоти, нота з імовірністю density, тони акорду й сусідні щаблі.
	var last_degree: int = -99
	for slot: int in 32:
		if rng.randf() > float(cfg["density"]):
			continue
		var c: int = slot / 8
		var d: int = int(prog[c])
		var options: Array[int] = [d + 7, d + 9, d + 11, d + 8, d + 10, d + 14]
		var pick: int = options[rng.randi() % options.size()]
		if pick == last_degree:
			pick = options[(rng.randi() % (options.size() - 1) + 1) % options.size()]
		last_degree = pick
		var f: float = _degree_freq(root, mode, pick)
		_add_note(buf, int(slot * 0.5 * RATE), f, 0.2 + rng.randf() * 0.08, timbre)
	_normalize(buf, 0.62)
	return make_wav(buf, RATE, true)


static func _add_pad(buf: PackedFloat32Array, start: int, seconds: float, freq: float, amp: float) -> void:
	var n: int = buf.size()
	var len_s: int = int(seconds * RATE)
	var w1: float = TAU * freq / RATE
	var w2: float = w1 * 1.004
	for i: int in len_s:
		var x: float = float(i) / len_s
		var s: float = sin(PI * x)
		var v: float = (sin(w1 * i) * 0.6 + sin(w2 * i + 1.0) * 0.4) * s * s * amp
		var idx: int = posmod(start + i, n)
		buf[idx] += v


static func _add_note(buf: PackedFloat32Array, start: int, freq: float, amp: float, timbre: int) -> void:
	var n: int = buf.size()
	var decay: float = 3.0
	var dur: float = 1.8
	match timbre:
		Timbre.MARIMBA:
			decay = 4.2
			dur = 1.4
		Timbre.REED:
			decay = 1.1
			dur = 3.0
		Timbre.BELL:
			decay = 1.0
			dur = 3.5
	var len_s: int = int(dur * RATE)
	var w: float = TAU * freq / RATE
	for i: int in len_s:
		var t: float = float(i) / RATE
		var env: float = minf(1.0, t / 0.01) * exp(-t * decay)
		if env < 0.004:
			break
		var v: float
		match timbre:
			Timbre.MARIMBA:
				v = sin(w * i) + 0.5 * sin(w * i * 4.0) * exp(-t * 14.0)
			Timbre.REED:
				env *= minf(1.0, t / 0.09)
				var ph: float = w * i + 0.03 * sin(TAU * 5.2 * t) * freq / 100.0
				v = sin(ph) + 0.5 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph)
			Timbre.BELL:
				v = sin(w * i) + 0.5 * sin(w * i * 2.76) * exp(-t * 3.0)
			_:
				v = sin(w * i) + 0.35 * sin(w * i * 2.0)
		buf[posmod(start + i, n)] += v * env * amp


# --- Фонові шари (зациклені) ------------------------------------------------------

const AMBIENT_KINDS: Array[StringName] = [&"wind", &"water", &"leaves", &"crickets", &"rain"]
const AMB_SECONDS: float = 5.0


static func build_ambient(kind: StringName) -> AudioStreamWAV:
	var n: int = int(AMB_SECONDS * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	if kind == &"crickets":
		_fill_crickets(out)
	else:
		_fill_noise(out, kind)
	_normalize(out, 0.8)
	return make_wav(out, RATE, true)


static func _fill_noise(out: PackedFloat32Array, kind: StringName) -> void:
	var n: int = out.size()
	var fade: int = int(0.4 * RATE)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(kind))
	var alpha: float = 0.03 if kind == &"wind" else (0.15 if kind == &"water" else 0.3)
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(n + fade)
	var lp: float = 0.0
	for i: int in raw.size():
		var x: float = rng.randf() * 2.0 - 1.0
		lp += (x - lp) * alpha
		if kind == &"rain":
			raw[i] = x * 0.55 + (x - lp) * 0.45
		else:
			raw[i] = (x - lp) if kind == &"leaves" else lp
	for i: int in n:
		var v: float = raw[i]
		if i < fade:
			var k: float = float(i) / fade
			v = raw[i] * k + raw[n + i] * (1.0 - k)
		var t: float = float(i) / RATE
		var m: float = 1.0
		match kind:
			&"wind":
				m = 0.55 + 0.45 * sin(TAU * 0.2 * t + 1.0) * (0.7 + 0.3 * sin(TAU * 0.6 * t))
			&"water":
				m = 0.6 + 0.4 * sin(TAU * 1.8 * t) * sin(TAU * 3.4 * t)
			&"leaves":
				var g: float = maxf(0.0, sin(TAU * 0.4 * t))
				m = 0.25 + 0.75 * g * g
			&"rain":
				m = 0.85 + 0.15 * sin(TAU * 1.4 * t)
		out[i] = v * m


static func _fill_crickets(out: PackedFloat32Array) -> void:
	for i: int in out.size():
		var t: float = float(i) / RATE
		out[i] = _cricket(t, 4300.0, 0.5, 0.0) * 0.5 + _cricket(t, 4900.0, 0.625, 0.17) * 0.4


static func _cricket(t: float, freq: float, period: float, offset: float) -> float:
	var ph: float = fposmod(t + offset, period)
	if ph > 0.12:
		return 0.0
	var k: float = fposmod(ph, 0.03) / 0.018
	if k >= 1.0:
		return 0.0
	var s: float = sin(PI * k)
	return sin(TAU * freq * t) * s * s


# --- Короткі події довкілля -------------------------------------------------------

static func build_event(kind: StringName, variant: int = 0) -> AudioStreamWAV:
	var buf: PackedFloat32Array = PackedFloat32Array()
	match kind:
		&"chirp":
			buf.resize(int(0.6 * RATE))
			var base: float = 3000.0 + 450.0 * variant
			for note: int in 3:
				var start: float = 0.02 + note * 0.13
				for i: int in int(0.08 * RATE):
					var t: float = float(i) / RATE
					var idx: int = int(start * RATE) + i
					if idx >= buf.size():
						break
					var s: float = sin(PI * t / 0.08)
					buf[idx] += sin(TAU * (base + 9000.0 * t) * t) * s * s * 0.5
		&"croak":
			buf.resize(int(0.4 * RATE))
			for p: int in 2:
				for i: int in int(0.09 * RATE):
					var t: float = float(i) / RATE
					var idx: int = int((0.03 + p * 0.14) * RATE) + i
					var s: float = sin(PI * t / 0.09)
					buf[idx] += (sin(TAU * 150.0 * t) * (0.55 + 0.45 * sin(TAU * 48.0 * t)) + 0.3 * sin(TAU * 420.0 * t)) * s * 0.5
		&"thunder":
			buf.resize(int(3.6 * RATE))
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = 909
			var lp: float = 0.0
			for i: int in buf.size():
				var t: float = float(i) / RATE
				lp += (rng.randf() * 2.0 - 1.0 - lp) * 0.025
				var env: float = minf(1.0, t / 0.15) * exp(-t * 1.0) * (0.75 + 0.25 * sin(TAU * 3.3 * t))
				buf[i] = lp * env * 9.0
		_:  # hoot — сова
			buf.resize(int(1.3 * RATE))
			var notes: Array[Vector3] = [Vector3(0.05, 0.35, 330.0), Vector3(0.55, 0.6, 296.0)]
			for nt: Vector3 in notes:
				for i: int in int(nt.y * RATE):
					var t: float = float(i) / RATE
					var s: float = pow(sin(PI * t / nt.y), 0.8)
					buf[int(nt.x * RATE) + i] += (sin(TAU * nt.z * t) + 0.2 * sin(TAU * nt.z * 2.0 * t)) * s * 0.45
	_normalize(buf, 0.7)
	return make_wav(buf, RATE, false)


## Крок: biome 0 трава, 1 пісок, 2 берег, 3 сніг (хрускіт).
static func build_step(biome: int, variant: int) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1000 + biome * 10 + variant
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(int(0.18 * RATE))
	var alpha: float = 0.35
	var rate_k: float = 45.0
	match biome:
		1:
			alpha = 0.2
			rate_k = 28.0
		2:
			alpha = 0.1
			rate_k = 22.0
		3:
			alpha = 0.75
			rate_k = 60.0
	var lp: float = 0.0
	var bursts: Array[float] = [0.0]
	if biome == 3:
		bursts = [0.0, 0.018, 0.04]
	for b: float in bursts:
		var start: int = int(b * RATE)
		for i: int in buf.size() - start:
			var t: float = float(i) / RATE
			var x: float = rng.randf() * 2.0 - 1.0
			lp += (x - lp) * alpha
			buf[start + i] += lp * exp(-t * rate_k) * (0.9 if b == 0.0 else 0.6)
	if biome == 2:
		for i: int in buf.size():
			var t: float = float(i) / RATE
			buf[i] += sin(TAU * (300.0 + 900.0 * t) * t) * exp(-t * 30.0) * 0.25
	else:
		for i: int in buf.size():
			var t: float = float(i) / RATE
			buf[i] += sin(TAU * 90.0 * t) * exp(-t * 40.0) * 0.35
	_normalize(buf, 0.8)
	return make_wav(buf, RATE, false)


# --- Допоміжне ---------------------------------------------------------------------

static func _normalize(buf: PackedFloat32Array, peak_target: float) -> void:
	var pk: float = 0.0
	for v: float in buf:
		pk = maxf(pk, absf(v))
	if pk < 0.0001:
		return
	var k: float = peak_target / pk
	for i: int in buf.size():
		buf[i] *= k


static func make_wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

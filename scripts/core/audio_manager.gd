extends Node
## Alle Klänge werden beim Start prozedural erzeugt (keine Audiodateien im Projekt).
## Busse: Music, SFX, Ambience – Lautstärken kommen aus Settings.

const RATE := 22050

var _sfx_players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _cache := {}


func _ready() -> void:
	for bus in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)
	apply_volumes()


func apply_volumes() -> void:
	_set_bus("Master", Settings.master_volume)
	_set_bus("Music", Settings.music_volume)
	_set_bus("SFX", Settings.sfx_volume)
	_set_bus("Ambience", Settings.sfx_volume * 0.6)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


## Musik und Stadtatmosphäre starten (einmalig erzeugt, ca. 1 s Rechenzeit).
func start_world_audio() -> void:
	if _music.stream == null:
		_music.stream = _make_music()
	if _ambience.stream == null:
		_ambience.stream = _make_noise(4.0, 0.05, true)
	if not _music.playing:
		_music.play()
	if not _ambience.playing:
		_ambience.play()


func stop_world_audio() -> void:
	_music.stop()
	_ambience.stop()


# ── Effekte ──────────────────────────────────────────────
func play(effect: StringName, pitch := 1.0) -> void:
	var stream: AudioStream = _effect(effect)
	if stream == null:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.play()
			return


func _effect(effect: StringName) -> AudioStream:
	if _cache.has(effect):
		return _cache[effect]
	var s: AudioStream
	match effect:
		&"click": s = _make_tone([880.0], 0.05, 0.25, true)
		&"hover": s = _make_tone([1320.0], 0.03, 0.12, false)
		&"open": s = _make_tone([523.0, 784.0], 0.06, 0.25, false)
		&"close": s = _make_tone([784.0, 523.0], 0.06, 0.25, false)
		&"trick_start": s = _make_sweep(300.0, 900.0, 0.25)
		&"land_good": s = _make_tone([659.0, 784.0, 1046.0], 0.07, 0.35, false)
		&"land_perfect": s = _make_tone([784.0, 988.0, 1175.0, 1568.0], 0.07, 0.4, false)
		&"fail": s = _make_tone([311.0, 233.0], 0.15, 0.3, true)
		&"combo": s = _make_tone([1046.0, 1318.0], 0.05, 0.3, true)
		&"reward": s = _make_tone([523.0, 659.0, 784.0, 1046.0, 1318.0], 0.08, 0.35, false)
		&"purchase": s = _make_tone([392.0, 523.0, 659.0, 1046.0], 0.06, 0.4, false)
		&"denied": s = _make_tone([220.0, 196.0], 0.12, 0.3, true)
		&"pickup": s = _make_sweep(600.0, 1800.0, 0.18)
		&"teleport": s = _make_sweep(200.0, 2400.0, 0.6)
		&"rank_up": s = _make_tone([392.0, 523.0, 659.0, 784.0, 1046.0, 1318.0, 1568.0], 0.09, 0.45, false)
		&"puff": s = _make_noise(0.6, 0.35, false)
		&"step": s = _make_noise(0.06, 0.15, false)
		_: return null
	_cache[effect] = s
	return s


# ── Synthese ─────────────────────────────────────────────
func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _make_tone(freqs: Array, step: float, vol: float, square: bool) -> AudioStreamWAV:
	var per := int(step * RATE)
	var tail := int(step * 1.5 * RATE)
	var out := PackedFloat32Array()
	out.resize(per * freqs.size() + tail)
	for n in freqs.size():
		var f: float = freqs[n]
		for i in per + tail:
			var idx := n * per + i
			if idx >= out.size():
				break
			var ph := TAU * f * i / RATE
			var v := sin(ph)
			if square:
				v = signf(v) * 0.5
			var env := minf(1.0, i / 150.0) * exp(-3.5 * float(i) / (per + tail))
			out[idx] += v * env * vol
	return _wav(out)


func _make_sweep(f0: float, f1: float, seconds: float) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var ph := 0.0
	for i in count:
		var t := float(i) / count
		ph += TAU * lerpf(f0, f1, t) / RATE
		out[i] = sin(ph) * 0.3 * minf(1.0, i / 200.0) * (1.0 - t)
	return _wav(out)


func _make_noise(seconds: float, vol: float, loop: bool) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var last := 0.0
	for i in count:
		last = clampf(last + randf_range(-1.0, 1.0) * 0.06, -1.0, 1.0) * 0.996
		var env := 1.0 if loop else minf(1.0, i / 300.0) * pow(1.0 - float(i) / count, 1.6)
		out[i] = last * vol * env * 3.0
	if loop: # Übergang glätten
		for i in 400:
			var k := float(i) / 400.0
			out[count - 400 + i] = lerpf(out[count - 400 + i], out[i], k)
	return _wav(out, loop)


## Ruhiger Synthwave-Loop: Bass, Akkorde, Hi-Hat. 8 Takte à 2 s.
func _make_music() -> AudioStreamWAV:
	var bar := 2.0
	var chords := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]] # Am F C G
	var count := int(bar * 8 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for b in 8:
		var chord: Array = chords[b % 4]
		var start := int(b * bar * RATE)
		var len_bar := int(bar * RATE)
		for i in len_bar:
			var t := float(i) / RATE
			var v := 0.0
			for note in chord:
				var f := 440.0 * pow(2.0, (float(note) - 69.0) / 12.0)
				v += sin(TAU * f * t) * 0.045 + sin(TAU * f * 2.0 * t) * 0.01
			var bass_f := 440.0 * pow(2.0, (float(chord[0]) - 12.0 - 69.0) / 12.0)
			var beat := fmod(t, 0.5)
			v += sin(TAU * bass_f * t) * 0.12 * exp(-beat * 4.0)
			out[start + i] = v * minf(1.0, i / 800.0)
	# Hi-Hat auf den Achteln
	for k in int(8 * bar / 0.25):
		var s0 := int(k * 0.25 * RATE)
		for i in 900:
			if s0 + i < count:
				out[s0 + i] += randf_range(-1.0, 1.0) * 0.03 * exp(-i / 120.0)
	return _wav(out, true)

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
	Events.district_entered.connect(set_theme)


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
		_music.volume_db = 0.0
		_music.play()
		_theme = &"spawn"
	if not _ambience.playing:
		_ambience.play()


func stop_world_audio() -> void:
	_music.stop()
	if _music_b:
		_music_b.stop()
	_music.volume_db = 0.0
	_theme = &""
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


## Musik-Themen pro Distrikt: Akkorde (MIDI), Taktlänge (s), Arpeggio, Kick-Drum.
const THEMES := {
	&"spawn": {"chords": [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]], "bar": 2.0, "arp": false, "kick": false},
	&"skate": {"chords": [[52, 59, 64], [55, 62, 67], [57, 64, 69], [48, 55, 60]], "bar": 1.6, "arp": false, "kick": true},
	&"neon": {"chords": [[53, 56, 60], [49, 53, 56], [56, 60, 63], [51, 55, 58]], "bar": 2.0, "arp": true, "kick": true},
	&"luxury": {"chords": [[48, 52, 55, 59], [45, 48, 52, 55], [50, 53, 57, 60], [43, 47, 50, 53]], "bar": 2.4, "arp": false, "kick": false},
	&"harbor": {"chords": [[50, 53, 57], [46, 50, 53], [53, 57, 60], [48, 52, 55]], "bar": 2.2, "arp": false, "kick": false},
	&"beach": {"chords": [[48, 52, 55], [55, 59, 62], [57, 60, 64], [53, 57, 60]], "bar": 1.8, "arp": true, "kick": false},
	&"industrial": {"chords": [[52, 55, 59], [52, 55, 59], [48, 52, 55], [50, 54, 57]], "bar": 1.7, "arp": false, "kick": true},
	&"downtown": {"chords": [[46, 50, 53, 57], [43, 46, 50, 53], [51, 55, 58, 62], [53, 57, 60, 64]], "bar": 2.0, "arp": true, "kick": true},
	&"secret": {"chords": [[48, 51, 55], [44, 48, 51], [48, 51, 55], [46, 50, 53]], "bar": 3.0, "arp": false, "kick": false},
}


## Loop aus 8 Takten: Pad-Akkorde, Bass, Hi-Hat, optional Arpeggio und Kick.
## Reine Berechnung (läuft im Hintergrund-Thread, keine Szenen-Zugriffe).
static func make_music_samples(theme: Dictionary) -> PackedFloat32Array:
	var bar: float = theme["bar"]
	var chords: Array = theme["chords"]
	var count := int(bar * 8 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for b in 8:
		var chord: Array = chords[b % chords.size()]
		var start := int(b * bar * RATE)
		var len_bar := int(bar * RATE)
		var bass_f := 440.0 * pow(2.0, (float(chord[0]) - 12.0 - 69.0) / 12.0)
		for i in len_bar:
			var t := float(i) / RATE
			var v := 0.0
			for note in chord:
				var f := 440.0 * pow(2.0, (float(note) - 69.0) / 12.0)
				v += sin(TAU * f * t) * 0.04 + sin(TAU * f * 2.0 * t) * 0.008
			var beat := fmod(t, bar / 4.0)
			v += sin(TAU * bass_f * t) * 0.12 * exp(-beat * 4.0)
			if theme["arp"]:
				var step := int(t / (bar / 8.0))
				var note2: float = chord[step % chord.size()] + 12.0
				var af := 440.0 * pow(2.0, (note2 - 69.0) / 12.0)
				var at := fmod(t, bar / 8.0)
				v += signf(sin(TAU * af * t)) * 0.018 * exp(-at * 10.0)
			if theme["kick"]:
				var kt := fmod(t, bar / 4.0)
				v += sin(TAU * (50.0 + 90.0 * exp(-kt * 30.0)) * kt) * 0.22 * exp(-kt * 9.0)
			out[start + i] = v * minf(1.0, i / 800.0)
	for k in int(8 * bar / (bar / 8.0)):
		var s0 := int(k * (bar / 8.0) * RATE)
		for i in 900:
			if s0 + i < count:
				out[s0 + i] += rng.randf_range(-1.0, 1.0) * 0.028 * exp(-i / 120.0)
	return out


var _music_b: AudioStreamPlayer
var _theme := &""
var _music_cache := {}
var _pending := {}
var _tasks: Array[int] = []


func _make_music() -> AudioStreamWAV:
	return _wav(make_music_samples(THEMES[&"spawn"]), true)


## Distrikt-Musik wechseln: im Hintergrund erzeugen, dann weich überblenden.
func set_theme(theme: StringName) -> void:
	if not THEMES.has(theme) or theme == _theme:
		return
	_theme = theme
	if _music_cache.has(theme):
		_crossfade(_music_cache[theme])
		return
	if _pending.has(theme):
		return
	_pending[theme] = true
	var spec: Dictionary = THEMES[theme]
	_tasks.append(WorkerThreadPool.add_task(func(): _theme_ready.call_deferred(theme, make_music_samples(spec))))


## Beim Beenden auf laufende Musik-Threads warten (sonst Absturz beim Herunterfahren).
func _exit_tree() -> void:
	for t in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_tasks.clear()


func _theme_ready(theme: StringName, samples: PackedFloat32Array) -> void:
	_pending.erase(theme)
	_music_cache[theme] = _wav(samples, true)
	if theme == _theme:
		_crossfade(_music_cache[theme])


func _crossfade(stream: AudioStream) -> void:
	if _music_b == null:
		_music_b = AudioStreamPlayer.new()
		_music_b.bus = "Music"
		add_child(_music_b)
	if not _music.playing and not _music_b.playing:
		return
	var old := _music if _music.playing else _music_b
	var new := _music_b if old == _music else _music
	new.stream = stream
	new.volume_db = -40.0
	new.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(new, "volume_db", 0.0, 2.5)
	tw.tween_property(old, "volume_db", -40.0, 2.5)
	tw.chain().tween_callback(old.stop)

class_name Weather
extends Node3D
## Wetter (rein kosmetisch, lokal): ab und zu ein Regenschauer.
## Dichtere Wolken, gedämpftes Licht, Regen rund um die Kamera, Regenrauschen.

var day_night: DayNight
var raining := false
var intensity := 0.0 # 0..1, weich überblendet
var _timer := 0.0
var _rain: CPUParticles3D
var _sound: AudioStreamPlayer


func _ready() -> void:
	_timer = randf_range(240.0, 600.0)
	_rain = CPUParticles3D.new()
	_rain.amount = 400
	_rain.lifetime = 1.1
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(22, 0.5, 22)
	_rain.direction = Vector3(0.15, -1, 0)
	_rain.spread = 3.0
	_rain.initial_velocity_min = 22.0
	_rain.initial_velocity_max = 26.0
	_rain.gravity = Vector3.ZERO
	var streak := QuadMesh.new()
	streak.size = Vector2(0.025, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = Color(0.75, 0.82, 0.95, 0.35)
	m.disable_receive_shadows = true
	streak.material = m
	_rain.mesh = streak
	_rain.emitting = false
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)
	_sound = AudioStreamPlayer.new()
	_sound.bus = "Ambience"
	_sound.volume_db = -40.0
	add_child(_sound)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		raining = not raining
		_timer = randf_range(120.0, 240.0) if raining else randf_range(420.0, 900.0)
		if raining:
			Events.toast.emit("Es fängt an zu regnen …", Color("93c5fd"))
	intensity = move_toward(intensity, 1.0 if raining else 0.0, delta / 12.0)
	var cam := get_viewport().get_camera_3d()
	if cam:
		_rain.global_position = cam.global_position + Vector3(0, 14, 0)
	var want := intensity > 0.05
	if want and not _rain.emitting:
		_rain.amount = int(400 * FX.quality()) + 40
	_rain.emitting = want
	if want and not _sound.playing:
		if _sound.stream == null:
			_sound.stream = _rain_noise()
		_sound.play()
	_sound.volume_db = lerpf(-40.0, -6.0, intensity)
	if not want and _sound.playing and intensity <= 0.0:
		_sound.stop()
	if day_night:
		day_night.weather = intensity


static func _rain_noise() -> AudioStreamWAV:
	var count := 22050 * 3
	var data := PackedByteArray()
	data.resize(count * 2)
	var last := 0.0
	for i in count:
		last = last * 0.6 + randf_range(-1.0, 1.0) * 0.4 # Rauschen, leicht gefiltert
		var v := last * 0.35
		if i > count - 300: # Loop-Übergang weich
			v *= float(count - i) / 300.0
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = count
	return w

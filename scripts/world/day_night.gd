class_name DayNight
extends Node
## Tag-/Nachtzyklus: Sonne, Himmels-Shader, Umgebungslicht, Nebel, Straßenlaternen.
## Ein Tag = DAY_LENGTH Sekunden. Farbverläufe über Keyframes (Nacht → Morgen → Mittag → Abend).

const DAY_LENGTH := 600.0
## time_of_day: [Himmel oben, Horizont, Sonnenfarbe, Sonnenenergie, Umgebungslicht, Nebel]
const KEYS := [
	[0.0, Color("070814"), Color("1b1840"), Color("8ea2ff"), 0.08, Color("2a2f63"), Color("101233")],
	[0.22, Color("0d1030"), Color("3b2a5a"), Color("ff9a6b"), 0.1, Color("3a3466"), Color("2a2244")],
	[0.28, Color("4b6fb5"), Color("f4a582"), Color("ffb380"), 0.75, Color("8a7fa8"), Color("e3a98d")],
	[0.36, Color("3d7fd9"), Color("b9d7f2"), Color("fff1dc"), 1.35, Color("9fb6d6"), Color("b9cde4")],
	[0.5, Color("2f74d6"), Color("a9cdef"), Color("fff8ec"), 1.5, Color("a6bcdb"), Color("b3c9e2")],
	[0.66, Color("3c76c9"), Color("c3d5ea"), Color("ffe9cc"), 1.3, Color("9fb0cf"), Color("c0cde0")],
	[0.73, Color("35508f"), Color("ff9e6e"), Color("ff8f57"), 0.7, Color("98789a"), Color("e09a7f")],
	[0.78, Color("161a45"), Color("5a2f5c"), Color("ff7a59"), 0.12, Color("40336a"), Color("3a2a52")],
	[1.0, Color("070814"), Color("1b1840"), Color("8ea2ff"), 0.08, Color("2a2f63"), Color("101233")],
]

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ShaderMaterial
## 0 = Mitternacht, 0.5 = Mittag
var time_of_day := 0.35
var _lights_on := false
var _cloud := Vector2.ZERO
## Regen-Intensität 0..1 (Weather)
var weather := 0.0
var _window_glow := -1.0


var _apply_timer := 0.0


func _process(delta: float) -> void:
	if Settings.day_night_cycle:
		time_of_day = fmod(time_of_day + delta / DAY_LENGTH, 1.0)
	_cloud += Vector2(0.004, 0.0015) * delta
	# Himmel/Licht nur 4× pro Sekunde aktualisieren (jede Himmels-Änderung kostet)
	_apply_timer -= delta
	if _apply_timer <= 0.0:
		_apply_timer = 0.25
		apply()


func daylight() -> float:
	return clampf(sin((time_of_day - 0.25) * TAU) * 0.5 + 0.5, 0.0, 1.0)


func _sample() -> Array:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if time_of_day >= a[0] and time_of_day <= b[0]:
			var t := (time_of_day - float(a[0])) / (float(b[0]) - float(a[0]))
			var out := []
			for k in range(1, a.size()):
				out.append(lerp(a[k], b[k], t))
			return out
	return KEYS[0].slice(1)


func apply() -> void:
	var s := _sample()
	var d := daylight()
	var angle := (time_of_day - 0.25) * TAU
	# Sonne (nachts der Mond: flacher, bläulich)
	var elev := sin(angle)
	sun.rotation = Vector3(-absf(elev) * 1.1 - 0.12, 0.6 + time_of_day * 0.6, 0)
	sun.light_color = s[2]
	sun.light_energy = s[3] * lerpf(1.0, 0.45, weather)
	var sunset := clampf(1.0 - absf(elev) * 3.0, 0.0, 1.0) * (1.0 if d > 0.15 else 0.4)
	sky_material.set_shader_parameter("sky_top", s[0])
	sky_material.set_shader_parameter("sky_horizon", s[1])
	sky_material.set_shader_parameter("sun_color", s[2])
	sky_material.set_shader_parameter("night", clampf(1.0 - d * 2.2, 0.0, 1.0))
	sky_material.set_shader_parameter("sunset", sunset)
	sky_material.set_shader_parameter("cloud_offset", _cloud)
	sky_material.set_shader_parameter("cloud_cover", lerpf(0.45, 0.9, weather))
	if weather > 0.0:
		sky_material.set_shader_parameter("sky_top", (s[0] as Color).lerp(Color("4b5563"), weather * 0.7))
		sky_material.set_shader_parameter("sky_horizon", (s[1] as Color).lerp(Color("9ca3af"), weather * 0.6))
	sky_material.set_shader_parameter("sun_dir", sun.global_transform.basis.z if sun.is_inside_tree() else Vector3(0, 0.5, 0.8))
	environment.ambient_light_color = s[4]
	environment.ambient_light_energy = lerpf(0.32, 0.7, d)
	# Fenster leuchten ab der Dämmerung
	var glow := clampf((0.45 - d) / 0.35, 0.0, 1.0) * 1.6
	if absf(glow - _window_glow) > 0.02:
		_window_glow = glow
		WorldKit.set_window_glow(glow)
	environment.fog_light_color = s[5]
	var want_lights := d < 0.35
	if want_lights != _lights_on:
		_lights_on = want_lights
		for l in get_tree().get_nodes_in_group(&"street_lights"):
			(l as OmniLight3D).visible = want_lights


func clock_text() -> String:
	var minutes := int(time_of_day * 24.0 * 60.0)
	return "%02d:%02d" % [minutes / 60, minutes % 60]

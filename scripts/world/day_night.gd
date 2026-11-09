class_name DayNight
extends Node
## Tag-/Nachtzyklus: Sonne, Himmel, Umgebungslicht, Straßenlaternen. Ein Tag = DAY_LENGTH Sekunden.

const DAY_LENGTH := 600.0

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
## 0 = Mitternacht, 0.5 = Mittag
var time_of_day := 0.35
var _lights_on := false


func _process(delta: float) -> void:
	if Settings.day_night_cycle:
		time_of_day = fmod(time_of_day + delta / DAY_LENGTH, 1.0)
	apply()


func daylight() -> float:
	# 0 nachts, 1 mittags (Sinus über den Tag)
	return clampf(sin((time_of_day - 0.25) * TAU) * 0.5 + 0.5, 0.0, 1.0)


func apply() -> void:
	var d := daylight()
	var angle := (time_of_day - 0.25) * TAU
	sun.rotation = Vector3(-maxf(0.15, sin(angle)) * 1.2 - 0.2, 0.6, 0)
	sun.light_energy = lerpf(0.06, 0.95, d)
	sun.light_color = Color("fca5a5").lerp(Color("fff7e6"), d)
	sky_material.sky_top_color = Color("0b0a1f").lerp(Color("3b82f6"), d)
	sky_material.sky_horizon_color = Color("312e81").lerp(Color("bfdbfe"), d)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.sky_energy_multiplier = lerpf(0.4, 1.0, d)
	environment.ambient_light_color = Color("4c1d95").lerp(Color("a5b4fc"), d)
	environment.ambient_light_energy = lerpf(0.55, 0.45, d)
	environment.fog_light_color = Color("1e1b4b").lerp(Color("c7d2fe"), d)
	var want_lights := d < 0.35
	if want_lights != _lights_on:
		_lights_on = want_lights
		for l in get_tree().get_nodes_in_group(&"street_lights"):
			(l as OmniLight3D).light_energy = 1.6 if want_lights else 0.0


func clock_text() -> String:
	var minutes := int(time_of_day * 24.0 * 60.0)
	return "%02d:%02d" % [minutes / 60, minutes % 60]

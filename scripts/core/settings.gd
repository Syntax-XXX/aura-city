extends Node
## Spieler-Einstellungen. Werden über den SaveSystem-Autoload mitgespeichert.

var master_volume := 0.8
var music_volume := 0.5
var sfx_volume := 0.8
var mouse_sensitivity := 1.0
var invert_y := false
var fov := 75.0
var fullscreen := false
var show_fps := false
var day_night_cycle := true


func to_dict() -> Dictionary:
	return {
		"master_volume": master_volume, "music_volume": music_volume, "sfx_volume": sfx_volume,
		"mouse_sensitivity": mouse_sensitivity, "invert_y": invert_y, "fov": fov,
		"fullscreen": fullscreen, "show_fps": show_fps, "day_night_cycle": day_night_cycle,
	}


func from_dict(d: Dictionary) -> void:
	master_volume = clampf(float(d.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(d.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(d.get("mouse_sensitivity", mouse_sensitivity)), 0.1, 3.0)
	invert_y = bool(d.get("invert_y", invert_y))
	fov = clampf(float(d.get("fov", fov)), 60.0, 100.0)
	fullscreen = bool(d.get("fullscreen", fullscreen))
	show_fps = bool(d.get("show_fps", show_fps))
	day_night_cycle = bool(d.get("day_night_cycle", day_night_cycle))
	apply()


func apply() -> void:
	Audio.apply_volumes()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	Events.settings_changed.emit()

extends Node
## Geräte-Einstellungen in eigener Datei (gelten für Online- und Offline-Profil).

var path := "user://settings.json"
var tutorial_done := false

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
		"tutorial_done": tutorial_done,
	}


func from_dict(d: Dictionary, apply_now := true) -> void:
	master_volume = clampf(float(d.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(d.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(d.get("mouse_sensitivity", mouse_sensitivity)), 0.1, 3.0)
	invert_y = bool(d.get("invert_y", invert_y))
	fov = clampf(float(d.get("fov", fov)), 60.0, 100.0)
	fullscreen = bool(d.get("fullscreen", fullscreen))
	show_fps = bool(d.get("show_fps", show_fps))
	day_night_cycle = bool(d.get("day_night_cycle", day_night_cycle))
	tutorial_done = bool(d.get("tutorial_done", tutorial_done))
	if apply_now:
		apply()


func has_file() -> bool:
	return FileAccess.file_exists(path)


## Laden ohne apply() – Audio ist beim Start noch nicht bereit (SaveSystem ruft apply()).
func load_file() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if has_file() else null
	if parsed is Dictionary:
		from_dict(parsed, false)


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict(), "\t"))


func apply() -> void:
	Audio.apply_volumes()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	save()
	Events.settings_changed.emit()

extends Node
## Speichern/Laden des kompletten Spielstands als JSON unter user://.
## - versioniert (SAVE_VERSION + Migration)
## - atomar: erst .tmp schreiben und prüfen, dann umbenennen; alter Stand wird .bak
## - beschädigte Datei → Backup → Standardwerte (Spiel startet immer)
## - Autosave alle 30 s und beim Beenden

const SAVE_VERSION := 1
const AUTOSAVE_SECONDS := 30.0

var save_path := "user://aura_city_save.json"
var tutorial_done := false
## Einmalige Geheimnisse (geheime Splitter), die nie wieder erscheinen
var found_secrets: Dictionary = {}
var last_load_status := "" # "ok", "backup", "new", "corrupt"
var _autosave_left := AUTOSAVE_SECONDS
var autosave_enabled := true


func _ready() -> void:
	get_tree().auto_accept_quit = false
	load_game()
	# Wichtige Momente sofort sichern
	Events.item_purchased.connect(func(_id): save_game())
	Events.achievement_unlocked.connect(func(_id): save_game())
	Events.rank_changed.connect(func(_r): save_game())


func _process(delta: float) -> void:
	if not autosave_enabled:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = AUTOSAVE_SECONDS
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


func snapshot() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"identity": Identity.to_dict(),
		"economy": Economy.to_dict(),
		"inventory": Inventory.to_dict(),
		"tricks": TrickDB.to_dict(),
		"quests": Quests.to_dict(),
		"achievements": Achievements.to_dict(),
		"settings": Settings.to_dict(),
		"tutorial_done": tutorial_done,
		"found_secrets": found_secrets.keys().map(func(k): return String(k)),
	}


func save_game() -> bool:
	var text := JSON.stringify(snapshot(), "\t")
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.close()
	# Prüfen, ob die Datei vollständig und lesbar ist, bevor sie den alten Stand ersetzt
	if not (JSON.parse_string(FileAccess.get_file_as_string(tmp)) is Dictionary):
		push_error("Speichern: Prüfung fehlgeschlagen, alter Stand bleibt erhalten")
		return false
	var dir := DirAccess.open(save_path.get_base_dir())
	var name := save_path.get_file()
	if dir.file_exists(name):
		dir.remove(name + ".bak")
		dir.rename(name, name + ".bak")
	dir.rename(name + ".tmp", name)
	Events.game_saved.emit()
	return true


func load_game() -> void:
	var data := _read(save_path)
	last_load_status = "ok"
	if data.is_empty() and FileAccess.file_exists(save_path):
		push_warning("Spielstand beschädigt – versuche Backup")
		data = _read(save_path + ".bak")
		last_load_status = "backup" if not data.is_empty() else "corrupt"
	elif data.is_empty():
		data = _read(save_path + ".bak")
		last_load_status = "backup" if not data.is_empty() else "new"
	apply(data)


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Daten anwenden; fehlende Teile bekommen Standardwerte.
func apply(data: Dictionary) -> void:
	data = migrate(data)
	Identity.from_dict(_section(data, "identity"))
	Economy.from_dict(_section(data, "economy"))
	TrickDB.from_dict(_section(data, "tricks"))
	TrickDB.check_unlocks(Economy.lifetime)
	Inventory.from_dict(_section(data, "inventory"))
	Quests.from_dict(_section(data, "quests"))
	Achievements.from_dict(_section(data, "achievements"))
	Settings.from_dict(_section(data, "settings"))
	tutorial_done = bool(data.get("tutorial_done", false))
	found_secrets.clear()
	var fs = data.get("found_secrets", [])
	if fs is Array:
		for k in fs:
			found_secrets[StringName(str(k))] = true
	Achievements.recheck_all()


func _section(data: Dictionary, key: String) -> Dictionary:
	var v = data.get(key, {})
	return v if v is Dictionary else {}


## Ältere Spielstände auf das aktuelle Format bringen.
func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", SAVE_VERSION))
	if v > SAVE_VERSION:
		push_warning("Spielstand stammt aus einer neueren Version (%d)" % v)
	# Version 0 (Entwicklungsstände) hatte Aura auf oberster Ebene
	if v == 0 and data.has("aura"):
		data["economy"] = {"aura": data["aura"], "lifetime": data.get("lifetime", data["aura"])}
	data["version"] = SAVE_VERSION
	return data


## Alles zurücksetzen (Einstellungen → „Spielstand löschen“).
func reset_all() -> void:
	apply({})
	tutorial_done = false
	save_game()

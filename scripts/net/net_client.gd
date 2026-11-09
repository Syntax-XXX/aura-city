extends Node
## Verbindung zum Aura-City-Server (Online-Modus).
## Online ist der Server die einzige Wahrheit: Der Client meldet nur Ereignisse (Trick gelandet,
## Splitter, Kauf …) mit Zeitstempel, der Server rechnet die Aura aus und schickt das Profil zurück.
## Lokal geänderte Werte (z. B. per Cheat Engine) werden beim nächsten Abgleich überschrieben.

signal status_changed(text: String, color: Color)

const CONFIG_PATH := "user://net.json"
const DEFAULT_URL := "http://auracity.local"
const MAX_BATCH := 64

var online := false
var server_url := DEFAULT_URL
var flagged := false
var status_text := "Offline"
var _tokens: Dictionary = {} # Server-URL -> Token
var _queue: Array[Dictionary] = []
var _busy := false
var _time_offset := 0.0 # Serverzeit − lokale Zeit (Sekunden)


func _ready() -> void:
	_load_config()
	Events.trick_landed.connect(_on_trick_landed)
	Events.trick_failed.connect(_on_trick_failed)
	Events.collectible_found.connect(_on_collectible)
	Events.district_entered.connect(_on_district)
	Events.challenge_started.connect(_on_challenge_started)
	Events.challenge_completed.connect(_on_challenge_completed)


## Unix-Zeit in Sekunden – online mit Serverzeit abgeglichen (für den Aura-Rush-Zeitplan).
func now() -> float:
	return Time.get_unix_time_from_system() + (_time_offset if online else 0.0)


# ── Verbindung ─────────────────────────────────────────────
## Mit dem Server verbinden: vorhandenes Profil fortsetzen oder ein frisches anlegen.
## Liefert "" bei Erfolg, sonst eine Fehlermeldung.
func connect_profile(url: String, display_name: String) -> String:
	server_url = url.strip_edges().trim_suffix("/")
	if not server_url.begins_with("http"):
		server_url = "http://" + server_url
	_set_status("Verbinde …", Color("facc15"))
	var token: String = _tokens.get(server_url, "")
	var res: Dictionary
	if token != "":
		res = await _http("/api/session", {}, token)
		if res.get("_code", 0) == 401:
			token = "" # Profil existiert auf diesem Server nicht (mehr) → neues anlegen
	if token == "":
		res = await _http("/api/register", {"name": display_name})
		if res.get("ok", false):
			token = str(res["token"])
			_tokens[server_url] = token
	if not res.get("ok", false):
		_set_status("Offline", Color("9ca3af"))
		return str(res.get("error", "Server nicht erreichbar (%s)" % server_url))
	_save_config()
	online = true
	_queue.clear()
	_sync_time(res)
	apply_profile(res["profile"], true)
	if str(res["profile"].get("name", "")) != display_name and display_name != "":
		send({"type": "name", "name": display_name})
	_set_status("Online", Color("4ade80"))
	return ""


## Vor dem Verlassen: noch ausstehende Ereignisse senden (max. `max_seconds`).
func wait_flushed(max_seconds := 3.0) -> void:
	var left := max_seconds
	while online and (_busy or not _queue.is_empty()) and left > 0.0:
		await get_tree().create_timer(0.1).timeout
		left -= 0.1


func disconnect_profile() -> void:
	online = false
	_queue.clear()
	flagged = false
	_set_status("Offline", Color("9ca3af"))


# ── Ereignisse ─────────────────────────────────────────────
func send(event: Dictionary) -> void:
	if not online:
		return
	event["t"] = Time.get_ticks_msec()
	_queue.append(event)
	_flush()


func pending() -> int:
	return _queue.size()


func _flush() -> void:
	if _busy or _queue.is_empty() or not online:
		return
	_busy = true
	var batch := _queue.slice(0, MAX_BATCH)
	var res := await _http("/api/events", {"events": batch}, _tokens.get(server_url, ""))
	_busy = false
	if not online:
		return
	var code: int = res.get("_code", 0)
	if code == 401:
		disconnect_profile()
		Events.toast.emit("Server kennt dein Profil nicht mehr – bitte neu verbinden", Color("fca5a5"))
		return
	if not res.get("ok", false):
		# Netzfehler/Überlast: Ereignisse bleiben in der Schlange, später erneut senden
		_set_status("Verbindung unterbrochen …", Color("fca5a5"))
		await get_tree().create_timer(2.0 if code != 429 else 1.0).timeout
		_flush()
		return
	_queue = _queue.slice(batch.size())
	_set_status("Online", Color("4ade80"))
	_sync_time(res)
	var results: Array = res.get("results", [])
	for i in mini(results.size(), batch.size()):
		var r: Dictionary = results[i]
		if not r.get("ok", false) and batch[i]["type"] in ["buy", "daily", "equip", "name", "drink"]:
			Audio.play(&"denied")
			Events.toast.emit("Server: " + str(r.get("error", "abgelehnt")), Color("fca5a5"))
	apply_profile(res["profile"], _queue.is_empty())
	_flush()


## Serverprofil übernehmen. Aura immer; der Rest nur, wenn keine eigenen Änderungen mehr unterwegs sind.
func apply_profile(p: Dictionary, full: bool) -> void:
	flagged = bool(p.get("flagged", false))
	Economy.apply_server(p.get("economy", {}))
	if not full:
		return
	Identity.player_id = str(p.get("id", Identity.player_id))
	Identity.display_name = str(p.get("name", Identity.display_name))
	TrickDB.from_dict(p.get("tricks", {}))
	TrickDB.check_unlocks(Economy.lifetime)
	Inventory.from_dict(p.get("inventory", {}))
	Quests.from_dict(p.get("quests", {}))
	Achievements.from_dict(p.get("achievements", {}))
	SaveSystem.found_secrets.clear()
	for k in p.get("found_secrets", []):
		SaveSystem.found_secrets[StringName(str(k))] = true
	Events.item_equipped.emit(&"", &"") # Figur neu einkleiden


func fetch_leaderboard() -> Array:
	var res := await _http("/api/leaderboard", {}, "", HTTPClient.METHOD_GET)
	return res.get("entries", []) if res.get("ok", false) else []


# ── Spiel-Ereignisse → Server ──────────────────────────────
func _on_trick_landed(id: StringName, quality: StringName, _aura: float, _combo: int) -> void:
	send({"type": "trick", "id": String(id), "quality": String(quality)})


func _on_trick_failed(id: StringName) -> void:
	send({"type": "trick", "id": String(id), "quality": "fail"})


func _on_collectible(id: StringName) -> void:
	send({"type": "collectible", "id": String(id)})


func _on_district(id: StringName) -> void:
	send({"type": "district", "id": String(id)})


func _on_challenge_started(challenge_name: String) -> void:
	send({"type": "challenge_start", "id": challenge_name})


func _on_challenge_completed(challenge_name: String, _reward: float) -> void:
	send({"type": "challenge_done", "id": challenge_name})


# ── HTTP ───────────────────────────────────────────────────
func _http(path: String, body: Dictionary, token := "", method := HTTPClient.METHOD_POST) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var err := req.request(server_url + path, headers, method, JSON.stringify(body) if method == HTTPClient.METHOD_POST else "")
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": "Anfrage fehlgeschlagen (%s)" % error_string(err)}
	var r: Array = await req.request_completed
	req.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "Server nicht erreichbar (%s)" % server_url}
	var parsed = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	var out: Dictionary = parsed if parsed is Dictionary else {"ok": false, "error": "Ungültige Serverantwort"}
	out["_code"] = r[1]
	return out


func _sync_time(res: Dictionary) -> void:
	if res.has("time"):
		_time_offset = float(res["time"]) / 1000.0 - Time.get_unix_time_from_system()


func _set_status(text: String, color: Color) -> void:
	status_text = text
	status_changed.emit(text, color)


func _load_config() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH)) if FileAccess.file_exists(CONFIG_PATH) else null
	if parsed is Dictionary:
		server_url = str(parsed.get("url", DEFAULT_URL))
		var t = parsed.get("tokens", {})
		_tokens = t if t is Dictionary else {}


func _save_config() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"url": server_url, "tokens": _tokens}))

extends Node
## Tägliche und wöchentliche Quests. Zählt über Events mit, setzt sich nach Datum/Woche zurück.

var defs: Dictionary = {} # StringName -> QuestDef
var progress: Dictionary = {} # StringName -> int
var completed: Dictionary = {} # StringName -> true
var daily_key := ""
var weekly_key := ""
var _visited_today: Dictionary = {}
var _visited_week: Dictionary = {}


func _ready() -> void:
	for r in ResourceDir.load_all("res://resources/quests"):
		var q := r as QuestDef
		if q and q.id != &"":
			defs[q.id] = q
	Events.trick_landed.connect(func(_id, _q, _a, _c): add(&"trick", 1))
	Events.combo_changed.connect(_on_combo_changed)
	Events.district_entered.connect(_on_district)
	Events.collectible_found.connect(func(_id): add(&"collectible", 1))
	Events.aura_changed.connect(_on_aura_changed)
	Events.challenge_completed.connect(func(_n, _r): add(&"challenge", 1))
	Events.item_unlocked.connect(func(_id): add(&"unlock", 1))
	check_reset()


func _on_combo_changed(combo: int, _multiplier: float) -> void:
	if combo == 3:
		add(&"combo", 1)


func _on_aura_changed(_current: float, delta: float) -> void:
	if delta > 0:
		add(&"aura", int(delta))


func current_day_key() -> String:
	return Time.get_date_string_from_system()


func current_week_key() -> String:
	# Montag der aktuellen Woche als Schlüssel
	var now := Time.get_unix_time_from_system()
	var weekday: int = Time.get_datetime_dict_from_system()["weekday"] # 0 = Sonntag
	var days_since_monday := (weekday + 6) % 7
	return Time.get_date_string_from_unix_time(int(now) - days_since_monday * 86400)


## Abgelaufene Quests zurücksetzen.
func check_reset() -> void:
	var dk := current_day_key()
	var wk := current_week_key()
	if dk != daily_key:
		daily_key = dk
		_visited_today.clear()
		_reset_period(QuestDef.Period.DAILY)
	if wk != weekly_key:
		weekly_key = wk
		_visited_week.clear()
		_reset_period(QuestDef.Period.WEEKLY)


func _reset_period(period: int) -> void:
	for q in defs.values():
		if q.period == period:
			progress[q.id] = 0
			completed.erase(q.id)


func _on_district(district_id: StringName) -> void:
	if not _visited_today.has(district_id):
		_visited_today[district_id] = true
		add(&"district", 1, QuestDef.Period.DAILY)
	if not _visited_week.has(district_id):
		_visited_week[district_id] = true
		add(&"district", 1, QuestDef.Period.WEEKLY)


## Fortschritt für alle Quests mit diesem Zähler erhöhen. period = -1: alle Zeiträume.
func add(stat: StringName, amount: int, period := -1) -> void:
	check_reset()
	for q in defs.values():
		if q.stat != stat or completed.has(q.id) or (period >= 0 and q.period != period):
			continue
		progress[q.id] = mini(q.goal, int(progress.get(q.id, 0)) + amount)
		Events.quest_progressed.emit(q.id, progress[q.id], q.goal)
		if progress[q.id] >= q.goal:
			completed[q.id] = true
			Events.quest_completed.emit(q.id)
			Events.toast.emit("Quest erledigt: %s (+%d Aura)" % [q.display_name, q.reward_aura], Color("4ade80"))
			Audio.play(&"reward")
			Economy.earn(q.reward_aura, "Quest")


func list(period: int) -> Array[QuestDef]:
	var out: Array[QuestDef] = []
	for q in defs.values():
		if q.period == period:
			out.append(q)
	out.sort_custom(func(a: QuestDef, b: QuestDef) -> bool: return String(a.id) < String(b.id))
	return out


func get_progress(id: StringName) -> int:
	return int(progress.get(id, 0))


func is_completed(id: StringName) -> bool:
	return completed.has(id)


func to_dict() -> Dictionary:
	var p := {}
	for k in progress:
		p[String(k)] = progress[k]
	return {"daily_key": daily_key, "weekly_key": weekly_key, "progress": p, "completed": completed.keys().map(func(k): return String(k)),
		"visited_today": _visited_today.keys().map(func(k): return String(k)), "visited_week": _visited_week.keys().map(func(k): return String(k))}


func from_dict(d: Dictionary) -> void:
	progress.clear()
	completed.clear()
	daily_key = str(d.get("daily_key", ""))
	weekly_key = str(d.get("weekly_key", ""))
	var p = d.get("progress", {})
	if p is Dictionary:
		for k in p:
			if defs.has(StringName(str(k))):
				progress[StringName(str(k))] = maxi(0, int(p[k]))
	for k in d.get("completed", []):
		if defs.has(StringName(str(k))):
			completed[StringName(str(k))] = true
	_visited_today.clear()
	_visited_week.clear()
	for k in d.get("visited_today", []):
		_visited_today[StringName(str(k))] = true
	for k in d.get("visited_week", []):
		_visited_week[StringName(str(k))] = true
	check_reset()

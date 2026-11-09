extends Node
## Achievements: zählt Statistiken über Events und schaltet frei, sobald ein Ziel erreicht ist.

var defs: Dictionary = {} # StringName -> AchievementDef
var unlocked: Dictionary = {} # StringName -> Unix-Zeit
var stats: Dictionary = {} # StringName -> int
var _districts: Dictionary = {}


func _ready() -> void:
	for r in ResourceDir.load_all("res://resources/achievements"):
		var a := r as AchievementDef
		if a and a.id != &"":
			defs[a.id] = a
	Events.trick_landed.connect(_on_trick)
	Events.combo_changed.connect(func(combo: int, _m: float): _set_max(&"best_combo", combo))
	Events.aura_changed.connect(func(_c, _d): _set_max(&"lifetime_aura", int(Economy.lifetime)))
	Events.rank_changed.connect(func(r: int): _set_max(&"rank", r))
	Events.item_unlocked.connect(func(_id): _set_max(&"legendary_items", Inventory.count_at_least(ItemDef.Rarity.LEGENDARY)))
	Events.collectible_found.connect(_on_collectible)
	Events.challenge_completed.connect(_on_challenge)
	Events.drink_used.connect(func(_id): _inc(&"drinks"))
	Events.district_entered.connect(_on_district)
	Events.secret_found.connect(func(_id): _set_max(&"secret_found", maxi(1, stat(&"secret_found"))))


func _on_trick(_id: StringName, quality: StringName, _aura: float, _combo: int) -> void:
	_inc(&"tricks")
	if quality == &"perfect":
		_inc(&"perfects")


func _on_challenge(challenge_name: String, _reward: float) -> void:
	_inc(&"challenges")
	if challenge_name.begins_with("Battle:"):
		_inc(&"battles")


func _on_collectible(id: StringName) -> void:
	_inc(&"collectibles")
	if String(id).begins_with("secret"):
		_inc(&"secret_found")


func _on_district(id: StringName) -> void:
	if not _districts.has(id):
		_districts[id] = true
		_set_max(&"districts", _districts.size())
		if id == &"secret":
			_set_max(&"secret_found", maxi(1, stat(&"secret_found")))


func stat(name: StringName) -> int:
	return int(stats.get(name, 0))


func _inc(name: StringName, amount := 1) -> void:
	stats[name] = stat(name) + amount
	_check(name)


func _set_max(name: StringName, value: int) -> void:
	if value > stat(name):
		stats[name] = value
		_check(name)


func _check(name: StringName) -> void:
	for a in defs.values():
		if a.stat == name and not unlocked.has(a.id) and stat(name) >= a.goal:
			unlock(a.id)


func unlock(id: StringName) -> void:
	var a: AchievementDef = defs.get(id)
	if a == null or unlocked.has(id):
		return
	unlocked[id] = int(Time.get_unix_time_from_system())
	Events.achievement_unlocked.emit(id)
	Events.toast.emit("Erfolg: %s %s" % [a.icon_glyph, a.display_name], Color("facc15"))
	Audio.play(&"reward")
	if a.reward_aura > 0:
		Economy.earn(a.reward_aura, "Erfolg")


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


func get_def(id: StringName) -> AchievementDef:
	return defs.get(id)


func all() -> Array[AchievementDef]:
	var out: Array[AchievementDef] = []
	for a in defs.values():
		out.append(a)
	out.sort_custom(func(a: AchievementDef, b: AchievementDef) -> bool: return a.goal < b.goal if a.stat == b.stat else String(a.stat) < String(b.stat))
	return out


## Nach dem Laden: Ziele prüfen, die schon erreicht sind (z. B. Rang aus Spielstand).
func recheck_all() -> void:
	_set_max(&"lifetime_aura", int(Economy.lifetime))
	_set_max(&"rank", Economy.rank_index)
	_set_max(&"legendary_items", Inventory.count_at_least(ItemDef.Rarity.LEGENDARY))


func to_dict() -> Dictionary:
	var u := {}
	for k in unlocked:
		u[String(k)] = unlocked[k]
	var s := {}
	for k in stats:
		s[String(k)] = stats[k]
	return {"unlocked": u, "stats": s, "districts": _districts.keys().map(func(k): return String(k))}


func from_dict(d: Dictionary) -> void:
	unlocked.clear()
	stats.clear()
	_districts.clear()
	var u = d.get("unlocked", {})
	if u is Dictionary:
		for k in u:
			if defs.has(StringName(str(k))):
				unlocked[StringName(str(k))] = int(u[k])
	var s = d.get("stats", {})
	if s is Dictionary:
		for k in s:
			stats[StringName(str(k))] = maxi(0, int(s[k]))
	for k in d.get("districts", []):
		_districts[StringName(str(k))] = true

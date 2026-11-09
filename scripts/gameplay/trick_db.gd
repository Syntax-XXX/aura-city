extends Node
## Alle Trick-Definitionen, benannte Ketten und der Trick-Fortschritt des Spielers
## (freigeschaltet, Meisterschaft, Belegung der Tasten 1–4).

## Benannte Trick-Ketten: genau diese Reihenfolge innerhalb einer Combo gibt einen Bonus.
const CHAINS := [
	{"name": "Spin Cycle", "sequence": [&"basic_spin", &"double_spin", &"ultra_spin"], "bonus": 1500},
	{"name": "Model Walk", "sequence": [&"mini_pose", &"air_pose", &"cosmic_pose"], "bonus": 2000},
	{"name": "Street Starter", "sequence": [&"finger_flip", &"side_twist", &"basic_spin"], "bonus": 250},
	{"name": "Night Shift", "sequence": [&"shadow_move", &"neon_flip", &"phantom_combo"], "bonus": 3000},
]
## Treffer pro Meisterschaftsstufe (Stufe 1..5)
const MASTERY_STEPS := [5, 15, 40, 100, 250]

var tricks: Dictionary = {} # StringName -> TrickDef
var unlocked: Dictionary = {} # StringName -> true
var mastery_hits: Dictionary = {} # StringName -> int
var loadout: Array[StringName] = [&"basic_spin", &"finger_flip", &"mini_pose", &"side_twist"]


func _ready() -> void:
	for r in ResourceDir.load_all("res://resources/tricks"):
		var t := r as TrickDef
		if t and t.id != &"":
			tricks[t.id] = t
	reset_progress()


func reset_progress() -> void:
	unlocked.clear()
	mastery_hits.clear()
	for t in tricks.values():
		if t.unlock_lifetime_aura <= 0:
			unlocked[t.id] = true
	loadout = [&"basic_spin", &"finger_flip", &"mini_pose", &"side_twist"]


func get_trick(id: StringName) -> TrickDef:
	return tricks.get(id)


func all() -> Array[TrickDef]:
	var out: Array[TrickDef] = []
	for t in tricks.values():
		out.append(t)
	out.sort_custom(func(a: TrickDef, b: TrickDef) -> bool: return a.unlock_lifetime_aura < b.unlock_lifetime_aura if a.tier == b.tier else a.tier < b.tier)
	return out


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


## Neue Tricks freischalten, sobald genug Lifetime-Aura gesammelt wurde.
func check_unlocks(lifetime_aura: float) -> void:
	for t in tricks.values():
		if not unlocked.has(t.id) and lifetime_aura >= t.unlock_lifetime_aura:
			unlocked[t.id] = true
			Events.trick_unlocked.emit(t.id)
			Events.toast.emit("Neuer Trick freigeschaltet: %s" % t.display_name, t.effect_color)


func mastery_level(id: StringName) -> int:
	var hits: int = mastery_hits.get(id, 0)
	var level := 0
	for step in MASTERY_STEPS:
		if hits >= step:
			level += 1
	return level


func mastery_progress(id: StringName) -> Vector2i:
	var hits: int = mastery_hits.get(id, 0)
	var level := mastery_level(id)
	if level >= MASTERY_STEPS.size():
		return Vector2i(hits, hits)
	return Vector2i(hits, MASTERY_STEPS[level])


func add_mastery_hit(id: StringName) -> void:
	var before := mastery_level(id)
	mastery_hits[id] = int(mastery_hits.get(id, 0)) + 1
	var after := mastery_level(id)
	if after > before:
		Events.mastery_up.emit(id, after)


func set_loadout_slot(slot_index: int, id: StringName) -> bool:
	if slot_index < 0 or slot_index >= 4 or not is_unlocked(id):
		return false
	# Trick, der schon in einem anderen Slot liegt, tauschen
	var existing := loadout.find(id)
	if existing >= 0:
		loadout[existing] = loadout[slot_index]
	loadout[slot_index] = id
	return true


func to_dict() -> Dictionary:
	return {"unlocked": unlocked.keys().map(func(k): return String(k)), "mastery": _str_keys(mastery_hits), "loadout": loadout.map(func(k): return String(k))}


func from_dict(d: Dictionary) -> void:
	reset_progress()
	for k in d.get("unlocked", []):
		if tricks.has(StringName(str(k))):
			unlocked[StringName(str(k))] = true
	var m = d.get("mastery", {})
	if m is Dictionary:
		for k in m:
			if tricks.has(StringName(str(k))):
				mastery_hits[StringName(str(k))] = maxi(0, int(m[k]))
	var lo = d.get("loadout", [])
	if lo is Array and lo.size() == 4:
		for i in 4:
			var id := StringName(str(lo[i]))
			if is_unlocked(id):
				loadout[i] = id


func _str_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = d[k]
	return out

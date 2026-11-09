extends Node
## Besitz und Ausrüstung kosmetischer Items. Käufe werden über Economy (und deren Authority) geprüft.

const SLOTS: Array[StringName] = [&"skin", &"hair", &"outfit", &"shoes", &"accessory", &"gadget", &"trail", &"particle", &"title", &"emote", &"animation", &"board"]

var owned: Dictionary = {} # StringName -> true
var equipped: Dictionary = {} # Slot -> StringName


func _ready() -> void:
	reset()


func reset() -> void:
	owned.clear()
	equipped.clear()
	for item in ItemDB.all():
		if item.starter:
			owned[item.id] = true
			if not equipped.has(item.slot()):
				equipped[item.slot()] = item.id


func owns(id: StringName) -> bool:
	return owned.has(id)


## Erfüllt der Spieler die Freischalt-Bedingungen?
func requirements_met(item: ItemDef) -> bool:
	return unlock_reason(item) == ""


## Leerer String = freigeschaltet, sonst was noch fehlt.
func unlock_reason(item: ItemDef) -> String:
	if Economy.rank_index < item.required_rank:
		return "Benötigt Rang %s" % Economy.rank_name(item.required_rank)
	if Economy.lifetime < item.required_lifetime_aura:
		return "Benötigt %d Lifetime-Aura" % item.required_lifetime_aura
	if item.required_achievement != &"" and not Achievements.is_unlocked(item.required_achievement):
		var a: AchievementDef = Achievements.get_def(item.required_achievement)
		return "Benötigt Erfolg: %s" % (a.display_name if a else String(item.required_achievement))
	return ""


## Kauf ausführen. Leerer String = Erfolg, sonst Fehlertext (für die UI).
func purchase(id: StringName) -> String:
	var item := ItemDB.get_item(id)
	var err := ""
	if item == null:
		err = "Unbekanntes Item"
	elif owns(id):
		err = "Schon im Besitz"
	elif not requirements_met(item):
		err = unlock_reason(item)
	else:
		err = Economy.authority.approve_purchase(item, Economy.aura)
	if err == "" and not Economy.spend(item.price):
		err = "Nicht genug Aura"
	if err != "":
		Events.purchase_failed.emit(id, err)
		return err
	owned[id] = true
	Net.send({"type": "buy", "id": String(id)})
	Events.item_purchased.emit(id)
	Events.item_unlocked.emit(id)
	return ""


## Ohne Bezahlung geben (Belohnungen, Geheimnisse).
func grant(id: StringName) -> void:
	if ItemDB.get_item(id) and not owns(id):
		owned[id] = true
		Events.item_unlocked.emit(id)


func equip(id: StringName) -> bool:
	var item := ItemDB.get_item(id)
	if item == null or not owns(id):
		return false
	equipped[item.slot()] = id
	Net.send({"type": "equip", "slot": String(item.slot()), "id": String(id)})
	Events.item_equipped.emit(item.slot(), id)
	return true


func unequip(slot: StringName) -> void:
	if slot == &"skin":
		return # Haut kann nicht leer sein
	equipped.erase(slot)
	Net.send({"type": "equip", "slot": String(slot), "id": ""})
	Events.item_equipped.emit(slot, &"")


func equipped_item(slot: StringName) -> ItemDef:
	return ItemDB.get_item(equipped.get(slot, &""))


func is_equipped(id: StringName) -> bool:
	return equipped.values().has(id)


func equipped_ids() -> Dictionary:
	var out := {}
	for s in equipped:
		out[String(s)] = String(equipped[s])
	return out


func count_at_least(rarity: int) -> int:
	var n := 0
	for id in owned:
		var item := ItemDB.get_item(id)
		if item and item.rarity >= rarity:
			n += 1
	return n


func to_dict() -> Dictionary:
	return {"owned": owned.keys().map(func(k): return String(k)), "equipped": equipped_ids()}


func from_dict(d: Dictionary) -> void:
	reset()
	for k in d.get("owned", []):
		var id := StringName(str(k))
		if ItemDB.get_item(id):
			owned[id] = true
	var eq = d.get("equipped", {})
	if eq is Dictionary:
		for slot in eq:
			var id := StringName(str(eq[slot]))
			var item := ItemDB.get_item(id)
			if item and owns(id) and item.slot() == StringName(str(slot)):
				equipped[item.slot()] = id

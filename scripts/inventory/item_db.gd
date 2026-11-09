extends Node
## Alle Item-Definitionen (aus res://resources/items/).

var items: Dictionary = {} # StringName -> ItemDef


func _ready() -> void:
	for r in ResourceDir.load_all("res://resources/items"):
		var item := r as ItemDef
		if item and item.id != &"":
			if items.has(item.id):
				push_error("Doppelte Item-ID: %s" % item.id)
			items[item.id] = item


func get_item(id: StringName) -> ItemDef:
	return items.get(id)


func all() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for item in items.values():
		out.append(item)
	out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.rarity < b.rarity if a.rarity != b.rarity else a.price < b.price)
	return out


func by_category(category: StringName) -> Array[ItemDef]:
	return all().filter(func(i: ItemDef) -> bool: return i.category == category)


func categories() -> Array[StringName]:
	var out: Array[StringName] = []
	for c in ItemDef.CATEGORY_NAMES.keys():
		out.append(c)
	return out

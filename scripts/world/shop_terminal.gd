class_name ShopTerminal
extends Interactable
## Öffnet den Shop. Jeder Distrikt-Shop führt nur bestimmte Raritäten.

@export var shop_name := "Starter Shop"
@export var min_rarity := 0
@export var max_rarity := 2
## Leer = alle Kategorien, sonst direkt gefiltert (z. B. &"gadget" für den Vape-Shop)
@export var category: StringName = &""


func _ready() -> void:
	super._ready()
	if prompt == "" or prompt == "Interagieren":
		prompt = shop_name + " öffnen"


func interact(_player: Node3D) -> void:
	Audio.play(&"open")
	ShopScreen.next_category = category
	Events.shop_requested.emit(shop_name, min_rarity, max_rarity)

class_name ShopTerminal
extends Interactable
## Öffnet den Shop. Jeder Distrikt-Shop führt nur bestimmte Raritäten.

@export var shop_name := "Starter Shop"
@export var min_rarity := 0
@export var max_rarity := 2


func _ready() -> void:
	super._ready()
	prompt = shop_name + " öffnen"


func interact(_player: Node3D) -> void:
	Audio.play(&"open")
	Events.shop_requested.emit(shop_name, min_rarity, max_rarity)

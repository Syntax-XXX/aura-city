class_name Interactable
extends Area3D
## Basis für alles, womit der Spieler per [E] interagiert. Unterklassen überschreiben interact().
## Multiplayer-Grenze: interact() löst nur lokale Aktionen/UI aus; Wirtschaftsänderungen laufen über Economy/Inventory.

@export var prompt := "Interagieren"


func _ready() -> void:
	add_to_group(&"interactables")
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false


func prompt_text() -> String:
	return "[%s] %s" % [Controls.key_label("interact"), prompt]


func is_available() -> bool:
	return true


func interact(_player: Node3D) -> void:
	pass

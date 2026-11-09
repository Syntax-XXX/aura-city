class_name InfoSign
extends Interactable
## Schild oder Gesprächspartner: zeigt Dialogzeilen.

@export var speaker := "Schild"
@export var lines: PackedStringArray = []


func interact(_player: Node3D) -> void:
	Audio.play(&"click")
	Events.dialogue_requested.emit(speaker, lines)

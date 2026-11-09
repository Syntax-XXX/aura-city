class_name DistrictArea
extends Area3D
## Meldet, wenn der Spieler einen Distrikt betritt.

const NAMES := {&"spawn": "Spawn City", &"skate": "Skate Park", &"neon": "Neon District", &"luxury": "Luxury District", &"secret": "Secret Dimension"}

@export var district_id: StringName = &"spawn"

static var current: StringName = &""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Spieler
	body_entered.connect(_on_body)


func _on_body(body: Node3D) -> void:
	if not body.is_in_group(&"player") or current == district_id:
		return
	current = district_id
	Events.district_entered.emit(district_id)
	Events.toast.emit(NAMES.get(district_id, String(district_id)), Color("c084fc"))

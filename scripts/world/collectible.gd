class_name Collectible
extends Node3D
## Aura-Splitter. Wird beim Darüberlaufen eingesammelt.
## Normale Splitter erscheinen nach RESPAWN_SECONDS wieder, geheime nur einmal pro Spielstand.

const RESPAWN_SECONDS := 180.0
const PICKUP_RADIUS := 1.5

@export var collectible_id: StringName = &"shard"
@export var secret := false
@export var reward := 40

var _mesh: MeshInstance3D
var _hidden_left := 0.0
var _time := randf() * 10.0


func _ready() -> void:
	var m := PrismMesh.new()
	m.size = Vector3(0.45, 0.7, 0.45)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = m
	var color := Color("22d3ee") if secret else Color("c084fc")
	_mesh.material_override = CharacterVisual.make_material(color, 0.2, 0.3, 2.2)
	add_child(_mesh)
	if secret and SaveSystem.found_secrets.has(collectible_id):
		queue_free()


func _process(delta: float) -> void:
	_time += delta
	if _hidden_left > 0.0:
		_hidden_left -= delta
		_mesh.visible = _hidden_left <= 0.0
		return
	_mesh.position.y = 0.9 + sin(_time * 2.0) * 0.15
	_mesh.rotation.y += delta * 2.0
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player and player.global_position.distance_to(global_position) < PICKUP_RADIUS:
		_collect(player)


func _collect(player: Node3D) -> void:
	Audio.play(&"pickup", 1.4 if secret else 1.0)
	FX.sparkles(get_parent(), global_position + Vector3.UP, _mesh.material_override.albedo_color, 30)
	Economy.earn(reward * (10 if secret else 1), "Aura-Splitter", global_position + Vector3.UP * 1.5)
	Events.collectible_found.emit(collectible_id)
	if secret:
		SaveSystem.found_secrets[collectible_id] = true
		Events.toast.emit("Geheimer Splitter gefunden!", Color("22d3ee"))
		queue_free()
	else:
		_hidden_left = RESPAWN_SECONDS
		_mesh.visible = false

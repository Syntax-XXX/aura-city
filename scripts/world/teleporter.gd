class_name Teleporter
extends Interactable
## Teleport zu einem Ziel. Optional nur ab einem Rang nutzbar.

@export var target := Vector3.ZERO
@export var destination_name := ""
@export var required_rank := 0
@export var secret := false


func _ready() -> void:
	super._ready()
	prompt = "Teleport: " + destination_name


func prompt_text() -> String:
	if Economy.rank_index < required_rank:
		return "%s – benötigt Rang %s" % [destination_name, Economy.rank_name(required_rank)]
	return super.prompt_text()


func interact(player: Node3D) -> void:
	if Economy.rank_index < required_rank:
		Audio.play(&"denied")
		Events.toast.emit("Benötigt Rang %s" % Economy.rank_name(required_rank), Color("fca5a5"))
		return
	FX.sparkles(player.get_parent(), player.global_position + Vector3.UP, Color("22d3ee"), 40, 1.5)
	Audio.play(&"teleport")
	if secret:
		Events.secret_found.emit(&"secret_portal")
	(player as PlayerController).teleport(target)
	FX.sparkles(player.get_parent(), target + Vector3.UP, Color("c084fc"), 40, 1.5)

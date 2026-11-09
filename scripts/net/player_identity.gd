extends Node
## Spieler-Identität und die Grenze des replizierten Zustands.
## Für späteren Multiplayer: Nur was replicated_state() liefert, verlässt den Client.
## UI-Zustand (offene Menüs, Vorschauen) bleibt bewusst lokal.

var player_id := ""
var display_name := "Player"


func _ready() -> void:
	if player_id == "":
		player_id = _new_id()


func _new_id() -> String:
	var bytes := PackedByteArray()
	for i in 12:
		bytes.append(randi() % 256)
	return bytes.hex_encode()


## Öffentlicher Spielerzustand (Position, Blickrichtung, Rang, Kosmetik). Keine Wirtschaftswerte
## als Wahrheit – die kämen vom Server.
func replicated_state(position: Vector3, yaw: float) -> Dictionary:
	return {
		"id": player_id, "name": display_name, "p": [position.x, position.y, position.z], "yaw": yaw,
		"rank": Economy.rank_index, "equipped": Inventory.equipped_ids(),
	}


func to_dict() -> Dictionary:
	return {"player_id": player_id, "display_name": display_name}


func from_dict(d: Dictionary) -> void:
	var pid := str(d.get("player_id", ""))
	player_id = pid if pid.length() == 24 else _new_id()
	var n := str(d.get("display_name", "Player")).strip_edges().substr(0, 16)
	display_name = n if n != "" else "Player"

extends Node
## Registriert alle Eingabe-Aktionen beim Start (Tastatur + Maus).

const BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"interact": [KEY_E],
	"trick_1": [KEY_1],
	"trick_2": [KEY_2],
	"trick_3": [KEY_3],
	"trick_4": [KEY_4],
	"trick_land": [KEY_F, "mouse_left"],
	"emote": [KEY_G],
	"pause": [KEY_ESCAPE],
	"open_shop": [KEY_B],
	"open_inventory": [KEY_I],
	"open_customize": [KEY_C],
	"open_trickbook": [KEY_K],
	"open_quests": [KEY_J],
	"open_achievements": [KEY_O],
	"open_leaderboard": [KEY_L],
}


func _ready() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in BINDINGS[action]:
			if key is String and key == "mouse_left":
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_LEFT
				InputMap.action_add_event(action, mb)
			else:
				var ev := InputEventKey.new()
				ev.physical_keycode = key
				InputMap.action_add_event(action, ev)


## Tastenname für Hinweise in der UI (z. B. "E").
func key_label(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k:
			return OS.get_keycode_string(k.physical_keycode)
	return "?"

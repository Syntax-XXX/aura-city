extends Node
## Registriert alle Eingabe-Aktionen beim Start (Tastatur + Maus).

const BINDINGS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"sprint": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"interact": [KEY_E],
	"vape": [KEY_F, "mouse_right"],
	"combo_up": [KEY_UP],
	"combo_down": [KEY_DOWN],
	"combo_left": [KEY_LEFT],
	"combo_right": [KEY_RIGHT],
	"mouse_capture": ["mouse_left"],
	"toggle_view": [KEY_V],
	"emote": [KEY_G],
	"pause": [KEY_ESCAPE],
	"open_shop": [KEY_B],
	"open_inventory": [KEY_I],
	"open_customize": [KEY_C],
	"open_trickbook": [KEY_K],
	"open_quests": [KEY_J],
	"open_achievements": [KEY_O],
	"open_leaderboard": [KEY_L],
	"hoverboard": [KEY_Q],
	"photo_mode": [KEY_P],
}


func _ready() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in BINDINGS[action]:
			if key is String:
				if TouchControls.wanted():
					continue # auf Touch-Geräten gibt es eigene Buttons (ZIEHEN), nicht jedes Tippen
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_LEFT if key == "mouse_left" else MOUSE_BUTTON_RIGHT
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

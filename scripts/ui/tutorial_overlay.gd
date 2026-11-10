class_name TutorialOverlay
extends PanelContainer
## Geführtes Tutorial: jeder Schritt wird durch echte Spieleraktion abgeschlossen.

const STEPS := [
	["Willkommen in Aura City!", "Laufe mit WASD, Shift = sprinten, Maus = Kamera."],
	["Springen", "Drück die Leertaste."],
	["Dein erster Trick", "Drück 1 und dann F (oder Linksklick), wenn die Nadel im leuchtenden Bereich ist."],
	["Combo!", "Lande zwei Tricks kurz hintereinander – das ergibt einen Aura-Multiplikator."],
	["Shopping", "Öffne den Shop mit B. Neue Items gibt es auch in den Bezirks-Shops."],
	["Hoverboard", "Drück Q: Mit dem Board bist du auf der riesigen Map viel schneller. Shift = Boost, 1–4 = Board-Tricks."],
]

## Varianten für Touch-Geräte
const STEPS_TOUCH := [
	["Willkommen in Aura City!", "Zieh links auf dem Bildschirm, um zu laufen. Wisch rechts, um die Kamera zu drehen."],
	["Springen", "Tippe auf ⤒."],
	["Dein erster Trick", "Tippe 1 und dann LANDEN, wenn die Nadel im leuchtenden Bereich ist."],
	["Combo!", "Lande zwei Tricks kurz hintereinander – das ergibt einen Aura-Multiplikator."],
	["Shopping", "Tippe oben auf SHOP. Neue Items gibt es auch in den Bezirks-Shops."],
	["Hoverboard", "Tippe BOARD: Damit bist du auf der riesigen Map viel schneller. Tricks gehen auch auf dem Board."],
]

var player: PlayerController
var _step := 0
var _start := Vector3.ZERO
var _head: Label
var _body: Label
var _count: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.box(Color(0.07, 0.05, 0.14, 0.92), 16, UITheme.CYAN, 2, 16))
	custom_minimum_size = Vector2(360, 0)
	UIKit.pin(self, Control.PRESET_CENTER_LEFT, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(self, 6)
	_count = UIKit.label("", 12, UITheme.CYAN, v)
	_head = UIKit.label("", 20, Color.WHITE, v)
	_body = UIKit.label("", 15, UITheme.TEXT, v)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.label("Überspringen: Menü ☰" if TouchControls.wanted() else "Überspringen: Pause [Esc]", 11, UITheme.MUTED, v)
	Events.trick_landed.connect(_on_trick)
	Events.combo_changed.connect(_on_combo)
	_start = player.global_position
	_show()


func _show() -> void:
	_count.text = "TUTORIAL %d/%d" % [_step + 1, STEPS.size()]
	var steps: Array = STEPS_TOUCH if TouchControls.wanted() else STEPS
	_head.text = steps[_step][0]
	_body.text = steps[_step][1]


func _process(_delta: float) -> void:
	if _step == 0 and player.global_position.distance_to(_start) > 4.0:
		advance()
	elif _step == 1 and not player.is_on_floor() and player.velocity.y > 1.0:
		advance()


func _on_trick(_id: StringName, _q: StringName, _a: float, _c: int) -> void:
	if _step == 2:
		advance()


func _on_combo(combo: int, _m: float) -> void:
	if _step == 3 and combo >= 2:
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if _step == 5 and event.is_action_pressed("hoverboard"):
		advance()


func notify_screen(screen_name: StringName) -> void:
	if _step == 4 and screen_name == &"shop":
		advance()


func advance() -> void:
	_step += 1
	Audio.play(&"reward")
	if _step >= STEPS.size():
		finish()
	else:
		_show()


func finish() -> void:
	SaveSystem.tutorial_done = true
	SaveSystem.save_game()
	Events.toast.emit("Tutorial geschafft – viel Spaß in Aura City!", UITheme.GREEN)
	queue_free()

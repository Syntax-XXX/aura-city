class_name TouchControls
extends Control
## Touch-Steuerung für Handy/Tablet:
##  links: schwebender Bewegungsstick · rechts: Wischen dreht die Kamera
##  Buttons: ZIEHEN (groß, halten), Pfeil-Kreuz für Kombos, Springen, Board, Sprint (umschaltbar), Interagieren, Menü
## Buttons erzeugen echte Eingabe-Aktionen (Input.parse_input_event) → Spiel-Logik bleibt unverändert.

const STICK_RADIUS := 110.0

var player: PlayerController
var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _cam_index := -1
var _cam_last := Vector2.ZERO
var _button_touches := {} # Touch-Index -> Aktion
var _buttons: Array[Dictionary] = [] # {rect: Rect2, action: String, label: String, color: Color, toggle: bool}
var _sprint_on := false
var _interact_visible := false


static func wanted() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or DisplayServer.is_touchscreen_available()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.interaction_prompt.connect(func(t: String): _interact_visible = t != "")
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var s := size
	var r := 64.0 # Grundgröße eines Buttons (Radius)
	var right := s.x - 40.0
	var bottom := s.y - 40.0
	_buttons = [
		{"c": Vector2(right - r * 1.6, bottom - r * 1.6), "r": r * 1.25, "action": "vape", "label": "ZIEHEN", "color": Color("facc15")},
		{"c": Vector2(right - r * 4.2, bottom - r * 0.9), "r": r * 0.85, "action": "jump", "label": "⤒", "color": Color("38bdf8")},
		# Pfeil-Kreuz links über dem Stick-Bereich der rechten Hand
		{"c": Vector2(right - r * 3.0, bottom - r * 4.4), "r": r * 0.55, "action": "combo_up", "label": "↑", "color": Color("c084fc")},
		{"c": Vector2(right - r * 3.0, bottom - r * 2.6), "r": r * 0.55, "action": "combo_down", "label": "↓", "color": Color("c084fc")},
		{"c": Vector2(right - r * 4.0, bottom - r * 3.5), "r": r * 0.55, "action": "combo_left", "label": "←", "color": Color("c084fc")},
		{"c": Vector2(right - r * 2.0, bottom - r * 3.5), "r": r * 0.55, "action": "combo_right", "label": "→", "color": Color("c084fc")},
		{"c": Vector2(right - r * 0.8, bottom - r * 6.0), "r": r * 0.55, "action": "hoverboard", "label": "BOARD", "color": Color("22d3ee")},
		{"c": Vector2(right - r * 2.3, bottom - r * 6.0), "r": r * 0.55, "action": "sprint", "label": "SPRINT", "color": Color("4ade80"), "toggle": true},
		{"c": Vector2(right - r * 3.8, bottom - r * 5.6), "r": r * 0.55, "action": "emote", "label": "EMOTE", "color": Color("f9a8d4")},
		{"c": Vector2(s.x * 0.5, s.y * 0.62), "r": r * 0.75, "action": "interact", "label": "E", "color": Color("ffffff"), "context": true},
		{"c": Vector2(s.x * 0.5, 56.0), "r": r * 0.5, "action": "pause", "label": "☰", "color": Color("e9d5ff")},
		{"c": Vector2(s.x * 0.5 + r * 1.3, 56.0), "r": r * 0.5, "action": "open_shop", "label": "SHOP", "color": Color("fbbf24")},
	]
	queue_redraw()


func _visible_button(b: Dictionary) -> bool:
	return not b.get("context", false) or _interact_visible


func _button_at(p: Vector2) -> int:
	for i in _buttons.size():
		var b: Dictionary = _buttons[i]
		if _visible_button(b) and p.distance_to(b["c"]) <= b["r"] * 1.15:
			return i
	return -1


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			var bi := _button_at(touch.position)
			if bi >= 0:
				var b: Dictionary = _buttons[bi]
				if b.get("toggle", false):
					_sprint_on = not _sprint_on
					if _sprint_on:
						Input.action_press(b["action"])
					else:
						Input.action_release(b["action"])
				else:
					_button_touches[touch.index] = b["action"]
					_send(b["action"], true)
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif touch.position.x < size.x * 0.42 and _stick_index == -1 and touch.position.y > size.y * 0.3:
				_stick_index = touch.index
				_stick_origin = touch.position
				_stick_pos = touch.position
				get_viewport().set_input_as_handled()
			elif _cam_index == -1:
				_cam_index = touch.index
				_cam_last = touch.position
		else:
			if _button_touches.has(touch.index):
				_send(_button_touches[touch.index], false)
				_button_touches.erase(touch.index)
				queue_redraw()
			if touch.index == _stick_index:
				_stick_index = -1
				_apply_stick(Vector2.ZERO)
			if touch.index == _cam_index:
				_cam_index = -1
		return
	var drag := event as InputEventScreenDrag
	if drag:
		if drag.index == _stick_index:
			_stick_pos = drag.position
			var v := (_stick_pos - _stick_origin) / STICK_RADIUS
			_apply_stick(v.limit_length(1.0))
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif drag.index == _cam_index and player and player.input_enabled:
			player.camera_rig.rotate_by_mouse((drag.position - _cam_last) * 1.6)
			_cam_last = drag.position


func _apply_stick(v: Vector2) -> void:
	for pair in [["move_right", maxf(v.x, 0.0)], ["move_left", maxf(-v.x, 0.0)], ["move_back", maxf(v.y, 0.0)], ["move_forward", maxf(-v.y, 0.0)]]:
		if pair[1] > 0.05:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


func _process(_delta: float) -> void:
	queue_redraw() # Kontext-Button (E) ein-/ausblenden


func _draw() -> void:
	var font := UITheme.font()
	if _stick_index >= 0:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.08))
		draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(_stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS), 46.0, Color(1, 1, 1, 0.35))
	else:
		var hint := Vector2(size.x * 0.16, size.y * 0.72)
		draw_arc(hint, STICK_RADIUS * 0.8, 0, TAU, 48, Color(1, 1, 1, 0.15), 2.0)
		draw_string(font, hint + Vector2(-60, 6), "BEWEGEN", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(1, 1, 1, 0.3))
	for b in _buttons:
		if not _visible_button(b):
			continue
		var held: bool = _button_touches.values().has(b["action"]) or (b.get("toggle", false) and _sprint_on)
		var col: Color = b["color"]
		draw_circle(b["c"], b["r"], Color(col, 0.38 if held else 0.18))
		draw_arc(b["c"], b["r"], 0, TAU, 48, Color(col, 0.8), 3.0)
		var fs := 30 if String(b["label"]).length() <= 2 else 18
		draw_string(font, b["c"] + Vector2(-b["r"], fs * 0.35), b["label"], HORIZONTAL_ALIGNMENT_CENTER, b["r"] * 2.0, fs, Color(1, 1, 1, 0.9))

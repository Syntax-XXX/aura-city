class_name DialogueBox
extends Control
## NPC-/Schild-Dialog unten im Bild. E / Leertaste / Klick = weiter.

signal finished

var _speaker: Label
var _text: Label
var _lines: PackedStringArray = []
var _index := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := UIKit.panel(self, Color(0.07, 0.05, 0.14, 0.95), UITheme.PURPLE, 18)
	p.custom_minimum_size = Vector2(900, 150)
	UIKit.pin(p, Control.PRESET_CENTER_BOTTOM, 120)
	var v := UIKit.vbox(p, 8)
	_speaker = UIKit.label("", 20, UITheme.CYAN, v)
	_text = UIKit.label("", 18, UITheme.TEXT, v)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var hint := UIKit.label("[E] / Klick – weiter", 12, UITheme.MUTED, v)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	visible = false


func start(speaker: String, lines: PackedStringArray) -> void:
	_speaker.text = speaker
	_lines = lines
	_index = 0
	visible = true
	_show()


func _show() -> void:
	_text.text = _lines[_index] if _index < _lines.size() else ""
	_text.visible_ratio = 0.0
	create_tween().tween_property(_text, "visible_ratio", 1.0, clampf(_text.text.length() * 0.012, 0.15, 0.8))


func advance() -> void:
	if _text.visible_ratio < 1.0:
		_text.visible_ratio = 1.0
		return
	_index += 1
	Audio.play(&"click")
	if _index >= _lines.size():
		visible = false
		finished.emit()
	else:
		_show()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()

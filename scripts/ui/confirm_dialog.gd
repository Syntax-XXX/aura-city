class_name UIConfirm
extends Control
## Modale Ja/Nein-Abfrage (z. B. Kaufbestätigung).

var _text: Label
var _yes: Button
var _callback: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UIKit.panel(center, UITheme.PANEL_2, UITheme.PURPLE, 18)
	p.custom_minimum_size = Vector2(460, 0)
	var v := UIKit.vbox(p, 18)
	_text = UIKit.label("", 19, UITheme.TEXT, v)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := UIKit.hbox(v, 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	UIKit.button("Abbrechen", hide, row, Vector2(150, 46))
	_yes = UIKit.primary("Bestätigen", _confirm, row)
	_yes.custom_minimum_size = Vector2(170, 46)
	visible = false


func ask(text: String, yes_text: String, callback: Callable) -> void:
	_text.text = text
	_yes.text = yes_text
	_callback = callback
	visible = true
	_yes.grab_focus()


func _confirm() -> void:
	visible = false
	if _callback.is_valid():
		_callback.call()

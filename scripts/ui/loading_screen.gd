class_name LoadingScreen
extends Control
## Ladebildschirm mit echtem Fortschritt (Weltaufbau in Schritten) und Tipps.

const TIPS := [
	"Perfekte Landungen geben ×1,5 Aura – achte auf den goldenen Bereich.",
	"Combos steigern den Multiplikator bis ×6. Nicht zu lange warten!",
	"Bestimmte Zug-Reihenfolgen sind Ketten mit großem Bonus – siehe Wolkenbuch [K].",
	"Während eines Aura Rush gibt es doppelte Aura.",
	"Hinter manchen Ecken verstecken sich geheime Splitter …",
	"Jeden Tag die Tagesbelohnung am Spawn abholen – die Serie zählt!",
]

var _bar: ProgressBar
var _step: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := UIKit.vbox(center, 14)
	v.custom_minimum_size = Vector2(640, 0)
	var t := UIKit.label("AURA CITY", 54, Color.WHITE, v)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar = UIKit.progress(0, 1, UITheme.CYAN, 12)
	v.add_child(_bar)
	_step = UIKit.label("", 15, UITheme.MUTED, v)
	_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tip := UIKit.label("Tipp: " + TIPS.pick_random(), 15, UITheme.CYAN, v)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible = false


func set_progress(value: float, text: String) -> void:
	_bar.value = value
	_step.text = text

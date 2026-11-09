class_name UIScreen
extends Control
## Basis für alle Vollbild-Menüs: abgedunkelter Hintergrund, zentrales Fenster mit Titel und
## Schließen-Knopf, weiche Ein-/Ausblend-Animation. Unterklassen bauen in build_content() und
## aktualisieren in refresh().

signal closed

var screen_title := ""
var window_size := Vector2(1100, 680)
var content: VBoxContainer
var title_label: Label
var window: PanelContainer
var _dim: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.02, 0.07, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	window = UIKit.panel(center, UITheme.PANEL, UITheme.LINE, 22)
	window.custom_minimum_size = window_size
	var outer := UIKit.vbox(window, 14)
	var head := UIKit.hbox(outer, 12)
	title_label = UIKit.title(screen_title, head, 30)
	UIKit.spacer(head)
	UIKit.button("✕", close, head, Vector2(44, 44)).tooltip_text = "Schließen (Esc)"
	UIKit.separator(outer)
	content = UIKit.vbox(outer, 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_content()
	visible = false


func build_content() -> void:
	pass


func refresh() -> void:
	pass


func open() -> void:
	refresh()
	visible = true
	window.pivot_offset = window.size / 2.0
	window.scale = Vector2.ONE * 0.94
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.16)
	tw.tween_property(window, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play(&"open")


func close() -> void:
	if not visible:
		return
	Audio.play(&"close")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func(): visible = false)
	closed.emit()

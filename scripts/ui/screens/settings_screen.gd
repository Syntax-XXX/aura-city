class_name SettingsScreen
extends UIScreen
## Einstellungen: Lautstärken, Maus, Sichtfeld, Anzeige, Spielstand zurücksetzen.

var confirm: UIConfirm
var _rows: VBoxContainer


func _init() -> void:
	screen_title = "Einstellungen"
	window_size = Vector2(820, 700)


func build_content() -> void:
	_rows = UIKit.vbox(null, 12)
	UIKit.scroll(content, _rows).size_flags_vertical = Control.SIZE_EXPAND_FILL


func refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()
	UIKit.label("Audio", 20, UITheme.CYAN, _rows)
	_slider("Gesamt", "master_volume", 0.0, 1.0, 0.05, true)
	_slider("Musik", "music_volume", 0.0, 1.0, 0.05, true)
	_slider("Effekte", "sfx_volume", 0.0, 1.0, 0.05, true)
	UIKit.label("Steuerung", 20, UITheme.CYAN, _rows)
	_slider("Maus-Empfindlichkeit", "mouse_sensitivity", 0.1, 3.0, 0.05, false)
	_toggle("Y-Achse invertieren", "invert_y")
	UIKit.label("Anzeige", 20, UITheme.CYAN, _rows)
	_choice("Grafikqualität", "graphics_quality", ["Niedrig", "Mittel", "Hoch"])
	_choice("Effekte (Wolken, Funken)", "effects_quality", ["Sparsam", "Normal", "Voll"])
	_slider("Sichtfeld (FOV)", "fov", 60.0, 100.0, 1.0, false)
	_toggle("Vollbild", "fullscreen")
	_toggle("FPS anzeigen", "show_fps")
	_toggle("Tag/Nacht-Zyklus", "day_night_cycle")
	UIKit.separator(_rows)
	var keys := UIKit.label("Tasten: WASD laufen · Shift sprinten · Leertaste springen · 1–4 Tricks · F/Linksklick landen · E interagieren · G Emote · Q Hoverboard · N Aura-Kiosk · P Foto-Modus · B Shop · I Inventar · C Garderobe · K Trickbuch · J Quests · O Erfolge · L Bestenliste · Esc Pause", 13, UITheme.MUTED, _rows)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var danger := UIKit.hbox(_rows, 10)
	UIKit.label("Spielstand: " + ProjectSettings.globalize_path(SaveSystem.save_path), 12, UITheme.MUTED, danger)
	UIKit.spacer(danger)
	UIKit.primary("Spielstand löschen", _ask_reset, danger, UITheme.RED)


func _slider(text: String, key: String, lo: float, hi: float, step: float, percent: bool) -> void:
	var h := UIKit.hbox(_rows, 12)
	var name_l := UIKit.label(text, 16, UITheme.TEXT, h)
	name_l.custom_minimum_size = Vector2(240, 0)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = Settings.get(key)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var val := UIKit.label("", 15, UITheme.MUTED, h)
	val.custom_minimum_size = Vector2(60, 0)
	var fmt := _fmt.bind(percent)
	val.text = fmt.call(s.value)
	s.value_changed.connect(_on_slider.bind(key, val, fmt))


func _fmt(v: float, percent: bool) -> String:
	return "%d %%" % roundi(v * 100) if percent else ("%.2f" % v if v < 10 else str(roundi(v)))


func _on_slider(v: float, key: String, val: Label, fmt: Callable) -> void:
	Settings.set(key, v)
	val.text = fmt.call(v)
	Settings.apply()


func _choice(text: String, key: String, options: Array) -> void:
	var h := UIKit.hbox(_rows, 12)
	UIKit.label(text, 16, UITheme.TEXT, h).custom_minimum_size = Vector2(240, 0)
	var o := OptionButton.new()
	for opt in options:
		o.add_item(opt)
	o.selected = int(Settings.get(key))
	o.item_selected.connect(_on_choice.bind(key))
	h.add_child(o)


func _on_choice(index: int, key: String) -> void:
	Settings.set(key, index)
	Settings.apply()


func _toggle(text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = Settings.get(key)
	c.toggled.connect(_on_toggle.bind(key))
	_rows.add_child(c)


func _on_toggle(on: bool, key: String) -> void:
	Settings.set(key, on)
	Settings.apply()


func _ask_reset() -> void:
	confirm.ask("Wirklich ALLES löschen? Aura, Items, Tricks und Erfolge sind dann weg.", "Löschen", _reset)


func _reset() -> void:
	SaveSystem.reset_all()
	Events.toast.emit("Spielstand zurückgesetzt", UITheme.RED)
	refresh()

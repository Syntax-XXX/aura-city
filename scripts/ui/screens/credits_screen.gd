class_name CreditsScreen
extends UIScreen
## Credits: Spiel, Fremd-Assets (alle CC0) und Werkzeuge.

func _init() -> void:
	screen_title = "Credits"
	window_size = Vector2(760, 620)


func build_content() -> void:
	var v := UIKit.vbox(null, 10)
	UIKit.scroll(content, v).size_flags_vertical = Control.SIZE_EXPAND_FILL
	for entry in [
		["AURA CITY", "Ein Godot-4-Spiel über Dampfwolken, Combos und Aura. Satire – alle Vapes sind erfunden."],
		["Figuren & Animationen", "Ultimate Animated Character Pack und Universal Animation Library von Quaternius (CC0) – quaternius.com"],
		["Natur, Straßen, Autos", "Stylized Nature MegaKit, Modular Street Pack, Car Pack von Quaternius (CC0)"],
		["Texturen", "Gras, Asphalt, Pflaster, Sand, Beton, Fliesen, Holz von Poly Haven (CC0) – polyhaven.com"],
		["Engine", "Godot Engine 4.3 (MIT) – godotengine.org"],
		["Musik & Sounds", "Prozedural im Spiel erzeugt"],
	]:
		var p := UIKit.panel(v, UITheme.PANEL_2, UITheme.LINE, 14)
		var pv := UIKit.vbox(p, 4)
		UIKit.label(entry[0], 18, UITheme.CYAN, pv)
		var l := UIKit.label(entry[1], 14, UITheme.TEXT, pv)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

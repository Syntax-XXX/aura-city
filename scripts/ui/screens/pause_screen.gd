class_name PauseScreen
extends UIScreen
## Pausemenü: Weiter, alle Menüs, Speichern, Hauptmenü, Beenden.

signal navigate(screen_name: StringName)
signal quit_to_menu
signal skip_tutorial

var _status: Label
var _skip: Button


func _init() -> void:
	screen_title = "Pause"
	window_size = Vector2(520, 0)


func build_content() -> void:
	UIKit.primary("Weiterspielen", close, content)
	for entry in [["Shop-Übersicht", &"shop"], ["Inventar", &"inventory"], ["Garderobe", &"customize"], ["Trickbuch", &"trickbook"], ["Quests", &"quests"], ["Erfolge", &"achievements"], ["Bestenliste", &"leaderboard"], ["Einstellungen", &"settings"]]:
		UIKit.button(entry[0], navigate.emit.bind(entry[1]), content)
	UIKit.separator(content)
	_skip = UIKit.button("Tutorial überspringen", skip_tutorial.emit, content)
	UIKit.button("Speichern", _save, content)
	UIKit.button("Hauptmenü", quit_to_menu.emit, content)
	UIKit.button("Spiel beenden", _quit, content)
	_status = UIKit.label("", 13, UITheme.MUTED, content)


func refresh() -> void:
	_skip.visible = not SaveSystem.tutorial_done
	_status.text = "Autosave aktiv · Spieler: %s" % Identity.display_name


func _save() -> void:
	_status.text = "Gespeichert ✔" if SaveSystem.save_game() else "Speichern fehlgeschlagen!"


func _quit() -> void:
	SaveSystem.save_game()
	get_tree().quit()

class_name QuestScreen
extends UIScreen
## Tägliche und wöchentliche Quests mit Fortschritt und Belohnung.

var _list: VBoxContainer


func _init() -> void:
	screen_title = "Quests"
	window_size = Vector2(900, 680)


func build_content() -> void:
	_list = UIKit.vbox(null, 10)
	UIKit.scroll(content, _list).size_flags_vertical = Control.SIZE_EXPAND_FILL


func refresh() -> void:
	Quests.check_reset()
	for c in _list.get_children():
		c.queue_free()
	_section("Täglich", QuestDef.Period.DAILY)
	_section("Wöchentlich", QuestDef.Period.WEEKLY)


func _section(heading: String, period: int) -> void:
	UIKit.label(heading, 20, UITheme.CYAN, _list)
	for q in Quests.list(period):
		var row := UIKit.panel(_list, UITheme.PANEL_2, UITheme.LINE, 14)
		var v := UIKit.vbox(row, 6)
		var head := UIKit.hbox(v, 8)
		var done := Quests.is_completed(q.id)
		UIKit.label(("✔ " if done else "") + q.display_name, 17, UITheme.GREEN if done else Color.WHITE, head)
		UIKit.spacer(head)
		UIKit.label("✦ " + UIFormat.number(q.reward_aura), 15, UITheme.GOLD, head)
		UIKit.label(q.description, 14, UITheme.MUTED, v)
		var p := mini(Quests.get_progress(q.id), q.goal)
		v.add_child(UIKit.progress(p, q.goal, UITheme.GREEN if done else UITheme.PURPLE))
		UIKit.label("%d / %d" % [p, q.goal], 12, UITheme.MUTED, v)

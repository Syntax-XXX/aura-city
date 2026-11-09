class_name LeaderboardScreen
extends UIScreen
## Bestenliste nach Lifetime-Aura. Lokal: du gegen feste NPC-Rivalen (als NPC markiert).

var _list: VBoxContainer


func _init() -> void:
	screen_title = "Bestenliste"
	window_size = Vector2(760, 680)


func build_content() -> void:
	var note := UIKit.label("Offline-Bestenliste: Rivalen sind NPCs. Mit einem Online-Server würden hier echte Spieler stehen.", 13, UITheme.MUTED, content)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list = UIKit.vbox(null, 6)
	UIKit.scroll(content, _list).size_flags_vertical = Control.SIZE_EXPAND_FILL


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var i := 0
	for e in LocalLeaderboard.entries():
		i += 1
		var me: bool = e["is_player"]
		var row := UIKit.panel(_list, UITheme.PURPLE.darkened(0.6) if me else UITheme.PANEL_2, UITheme.CYAN if me else UITheme.LINE, 12)
		var h := UIKit.hbox(row, 12)
		var medal: String = ["🥇", "🥈", "🥉"][i - 1] if i <= 3 else "#%d" % i
		UIKit.label(medal, 20, UITheme.GOLD, h).custom_minimum_size = Vector2(48, 0)
		UIKit.label(e["name"] + (" (du)" if me else " · NPC"), 17, Color.WHITE if me else UITheme.TEXT, h)
		UIKit.spacer(h)
		UIKit.label(Economy.rank_name(e["rank"]), 14, Economy.rank_color(e["rank"]), h)
		UIKit.label("✦ " + UIFormat.number(e["score"]), 17, UITheme.GOLD, h).custom_minimum_size = Vector2(150, 0)

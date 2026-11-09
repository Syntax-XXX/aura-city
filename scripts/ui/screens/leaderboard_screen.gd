class_name LeaderboardScreen
extends UIScreen
## Bestenliste nach Lifetime-Aura. Lokal: du gegen feste NPC-Rivalen (als NPC markiert).

var _list: VBoxContainer
var _note: Label


func _init() -> void:
	screen_title = "Bestenliste"
	window_size = Vector2(760, 680)


func build_content() -> void:
	_note = UIKit.label("", 13, UITheme.MUTED, content)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list = UIKit.vbox(null, 6)
	UIKit.scroll(content, _list).size_flags_vertical = Control.SIZE_EXPAND_FILL


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if not Net.online:
		_note.text = "Offline-Bestenliste: deine Rivalen sind NPCs. Online spielst du gegen echte Spieler."
		_fill(LocalLeaderboard.entries())
		return
	_note.text = "Online-Bestenliste (Lifetime-Aura, vom Server geprüft). Markierte Profile werden nicht gelistet."
	var loading := UIKit.label("Lade …", 15, UITheme.MUTED, _list)
	var entries := await Net.fetch_leaderboard()
	if not is_instance_valid(loading):
		return
	loading.queue_free()
	if entries.is_empty():
		UIKit.label("Keine Daten – Server nicht erreichbar oder noch niemand gelistet.", 15, UITheme.MUTED, _list)
	for e in entries:
		e["is_player"] = e["name"] == Identity.display_name
	_fill(entries)


func _fill(entries: Array) -> void:
	var i := 0
	for e in entries:
		i += 1
		var me: bool = e["is_player"]
		var row := UIKit.panel(_list, UITheme.PURPLE.darkened(0.6) if me else UITheme.PANEL_2, UITheme.CYAN if me else UITheme.LINE, 12)
		var h := UIKit.hbox(row, 12)
		var medal: String = ["🥇", "🥈", "🥉"][i - 1] if i <= 3 else "#%d" % i
		UIKit.label(medal, 20, UITheme.GOLD, h).custom_minimum_size = Vector2(48, 0)
		UIKit.label(str(e["name"]) + (" (du)" if me else ("" if Net.online else " · NPC")), 17, Color.WHITE if me else UITheme.TEXT, h)
		UIKit.spacer(h)
		UIKit.label(Economy.rank_name(int(e["rank"])), 14, Economy.rank_color(int(e["rank"])), h)
		UIKit.label("✦ " + UIFormat.number(float(e["score"])), 17, UITheme.GOLD, h).custom_minimum_size = Vector2(150, 0)

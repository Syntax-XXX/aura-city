class_name AchievementScreen
extends UIScreen
## Erfolge: freigeschaltet / Fortschritt; geheime bleiben verdeckt, bis sie erreicht sind.

var _grid: GridContainer
var _summary: Label


func _init() -> void:
	screen_title = "Erfolge"
	window_size = Vector2(1100, 700)


func build_content() -> void:
	_summary = UIKit.label("", 15, UITheme.MUTED, content)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	UIKit.scroll(content, _grid).size_flags_vertical = Control.SIZE_EXPAND_FILL


func refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var count := 0
	for a in Achievements.all():
		var got := Achievements.is_unlocked(a.id)
		count += int(got)
		var hidden := a.secret and not got
		var card := UIKit.panel(_grid, UITheme.PANEL_2, UITheme.GOLD if got else UITheme.LINE, 14)
		card.custom_minimum_size = Vector2(500, 0)
		var h := UIKit.hbox(card, 12)
		UIKit.label("?" if hidden else a.icon_glyph, 34, UITheme.GOLD if got else UITheme.MUTED, h)
		var v := UIKit.vbox(h, 4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.label("Geheimer Erfolg" if hidden else a.display_name, 17, Color.WHITE if got else UITheme.TEXT, v)
		var desc := UIKit.label("Erkunde die Stadt …" if hidden else a.description, 13, UITheme.MUTED, v)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var p := mini(Achievements.stat(a.stat), a.goal)
		if got:
			UIKit.label("✔ Freigeschaltet · ✦ " + UIFormat.number(a.reward_aura), 13, UITheme.GOLD, v)
		elif not hidden:
			v.add_child(UIKit.progress(p, a.goal, UITheme.PURPLE, 8))
			UIKit.label("%s / %s · ✦ %s" % [UIFormat.number(p), UIFormat.number(a.goal), UIFormat.number(a.reward_aura)], 12, UITheme.MUTED, v)
	_summary.text = "%d / %d freigeschaltet" % [count, Achievements.defs.size()]

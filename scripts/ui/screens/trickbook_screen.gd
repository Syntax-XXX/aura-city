class_name TrickbookScreen
extends UIScreen
## Trickbuch: alle 12 Tricks mit Stufe, Schwierigkeit, Meisterschaft, Freischaltung,
## Belegung der Tasten 1–4 und die benannten Ketten.

var _list: VBoxContainer
var _loadout_row: HBoxContainer
var _chains: VBoxContainer


func _init() -> void:
	screen_title = "Wolkenbuch"
	window_size = Vector2(1240, 720)


func build_content() -> void:
	var top := UIKit.hbox(content, 10)
	UIKit.label("Belegung:", 16, UITheme.MUTED, top)
	_loadout_row = UIKit.hbox(top, 8)
	var body := UIKit.hbox(content, 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = UIKit.vbox(null, 8)
	UIKit.scroll(body, _list).custom_minimum_size = Vector2(800, 0)
	var side := UIKit.panel(body, UITheme.PANEL_2, UITheme.LINE, 16)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chains = UIKit.vbox(side, 8)


func refresh() -> void:
	for c in _loadout_row.get_children():
		c.queue_free()
	for i in 4:
		var t := TrickDB.get_trick(TrickDB.loadout[i])
		UIKit.chip("[%d] %s" % [i + 1, t.display_name if t else "—"], UITheme.CYAN, _loadout_row)
	for c in _list.get_children():
		c.queue_free()
	for t in TrickDB.all():
		_trick_row(t)
	for c in _chains.get_children():
		c.queue_free()
	UIKit.label("Ketten", 20, UITheme.CYAN, _chains)
	var info := UIKit.label("Züge in genau dieser Reihenfolge innerhalb einer Combo geben einen Bonus.", 13, UITheme.MUTED, _chains)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for chain in TrickDB.CHAINS:
		var names: PackedStringArray = []
		for id in chain["sequence"]:
			names.append(TrickDB.get_trick(id).display_name)
		UIKit.label(chain["name"] + "  ·  ✦ " + UIFormat.number(chain["bonus"]), 16, UITheme.GOLD, _chains)
		var l := UIKit.label(" → ".join(names), 13, UITheme.TEXT, _chains)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _trick_row(t: TrickDef) -> void:
	var open := TrickDB.is_unlocked(t.id)
	var row := UIKit.panel(_list, UITheme.PANEL_2, t.effect_color.darkened(0.4) if open else UITheme.LINE, 14)
	var h := UIKit.hbox(row, 12)
	var v := UIKit.vbox(h, 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UIKit.hbox(v, 8)
	UIKit.label(t.display_name if open else "🔒 " + t.display_name, 18, Color.WHITE if open else UITheme.MUTED, head)
	UIKit.chip(["Anfänger", "Fortgeschritten", "Legendär"][t.tier], [UITheme.GREEN, UITheme.CYAN, UITheme.GOLD][t.tier], head)
	UIKit.label("Kombo:  %s" % (t.arrows() if t.keys != "" else "keine – einfach ziehen und loslassen"), 20, UITheme.GREEN if open else UITheme.MUTED, v)
	UIKit.label("mind. %d %% ziehen · ✦ %s Basis · %.1fs Abklingzeit" % [t.min_charge, UIFormat.number(t.base_aura), t.cooldown], 13, UITheme.MUTED, v)
	var d := UIKit.label(t.description, 13, UITheme.TEXT, v)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if open:
		var lvl := TrickDB.mastery_level(t.id)
		var p := TrickDB.mastery_progress(t.id)
		UIKit.label("Meisterschaft %s  (%d/%d)" % ["★".repeat(lvl) + "☆".repeat(5 - lvl), p.x, p.y], 13, UITheme.GOLD, v)
		var slots := UIKit.vbox(h, 4)
		UIKit.label("Auf Spickzettel:", 12, UITheme.MUTED, slots)
		var sh := UIKit.hbox(slots, 4)
		for i in 4:
			var b := UIKit.button(str(i + 1), _assign.bind(i, t.id), sh, Vector2(40, 40))
			if TrickDB.loadout[i] == t.id:
				b.add_theme_stylebox_override("normal", UITheme.box(UITheme.CYAN.darkened(0.4), 10, UITheme.CYAN, 2, 4))
	else:
		UIKit.label("Freischaltung bei ✦ %s Lifetime-Aura (du: %s)" % [UIFormat.number(t.unlock_lifetime_aura), UIFormat.number(Economy.lifetime)], 13, UITheme.RED, v)


func _assign(slot: int, id: StringName) -> void:
	if TrickDB.set_loadout_slot(slot, id):
		SaveSystem.save_game()
	refresh()

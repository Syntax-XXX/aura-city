class_name DrinksScreen
extends UIScreen
## Aura-Kiosk: fiktive Drinks mit zeitlich begrenzten Boosts (Stufe 1–7, mit Aura bezahlt).

var confirm: UIConfirm
var _list: VBoxContainer
var _active: Label
var _wallet: Label


func _init() -> void:
	screen_title = "Aura-Kiosk"
	window_size = Vector2(980, 700)


func build_content() -> void:
	var top := UIKit.hbox(content, 10)
	_active = UIKit.label("", 15, UITheme.CYAN, top)
	UIKit.spacer(top)
	_wallet = UIKit.label("", 20, UITheme.GOLD, top)
	var info := UIKit.label("Immer nur ein Drink aktiv – ein neuer ersetzt den alten. Höhere Stufen brauchen einen höheren Rang.", 13, UITheme.MUTED, content)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list = UIKit.vbox(null, 8)
	UIKit.scroll(content, _list).size_flags_vertical = Control.SIZE_EXPAND_FILL


func refresh() -> void:
	_wallet.text = "✦ " + UIFormat.number(Economy.aura)
	var left := Economy.boost_seconds_left()
	var cur := Drinks.get_drink(Economy.boost_id)
	_active.text = ("Aktiv: %s · noch %s" % [cur["name"], UIFormat.seconds(left)]) if left > 0.0 and not cur.is_empty() else "Kein Drink aktiv"
	for c in _list.get_children():
		c.queue_free()
	for i in Drinks.LIST.size():
		var d: Dictionary = Drinks.LIST[i]
		var col := Color(d["color"])
		var row := UIKit.panel(_list, UITheme.PANEL_2, col.darkened(0.4), 14)
		var h := UIKit.hbox(row, 14)
		var glyph := UIKit.label(d["glyph"], 40, col, h)
		glyph.custom_minimum_size = Vector2(56, 0)
		var v := UIKit.vbox(h, 3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := UIKit.hbox(v, 8)
		UIKit.label(d["name"], 18, Color.WHITE, head)
		UIKit.chip("Stufe %d" % (i + 1), col, head)
		UIKit.label(d["desc"], 13, UITheme.MUTED, v)
		var fx: PackedStringArray = []
		if float(d["aura"]) > 1.0:
			fx.append("Aura ×%s" % str(d["aura"]))
		if float(d["speed"]) > 1.0:
			fx.append("Tempo +%d %%" % roundi((float(d["speed"]) - 1.0) * 100))
		if float(d["timing"]) > 1.0:
			fx.append("Timing-Fenster +%d %%" % roundi((float(d["timing"]) - 1.0) * 100))
		UIKit.label(" · ".join(fx) + " · %s" % UIFormat.seconds(float(d["seconds"])), 13, col.lightened(0.3), v)
		var locked := Economy.rank_index < int(d["rank"])
		var b := UIKit.primary("🔒 " + Economy.rank_name(int(d["rank"])) if locked else "✦ " + UIFormat.number(float(d["price"])), _ask.bind(d), h, col.darkened(0.3))
		b.custom_minimum_size = Vector2(190, 48)
		b.disabled = locked or not Economy.can_afford(float(d["price"]))


func _ask(d: Dictionary) -> void:
	confirm.ask("%s für ✦ %s trinken?" % [d["name"], UIFormat.number(float(d["price"]))], "Trinken", _drink.bind(d["id"]))


func _drink(id: String) -> void:
	var err := Economy.drink(id)
	if err == "":
		Audio.play(&"purchase")
		FX.sparkles(get_tree().get_first_node_in_group(&"player").get_parent(), (get_tree().get_first_node_in_group(&"player") as Node3D).global_position + Vector3.UP, Color(Drinks.get_drink(id)["color"]), 30)
		close()
	else:
		Audio.play(&"denied")
		Events.toast.emit(err, UITheme.RED)
		refresh()

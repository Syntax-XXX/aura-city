class_name ShopScreen
extends UIScreen
## Shop: Suche, Kategorie- und Raritätsfilter, 3D-Vorschau, Kaufbestätigung.
## Jeder Shop führt nur einen Raritätsbereich (Starter / Neon / Luxus / Void).

var confirm: UIConfirm
var shop_name := "Aura Store"
var min_rarity := 0
var max_rarity := 2

var _grid: GridContainer
var _search: LineEdit
var _category: OptionButton
var _rarity: OptionButton
var _only_affordable: CheckButton
var _preview: PreviewViewport
var _detail_name: Label
var _detail_rarity: Label
var _detail_desc: Label
var _detail_req: Label
var _buy: Button
var _wallet: Label
var _selected: ItemDef
var _categories: Array[StringName] = []


func _init() -> void:
	screen_title = "Shop"
	window_size = Vector2(1240, 720)


func build_content() -> void:
	var bar := UIKit.hbox(content, 10)
	_search = LineEdit.new()
	_search.placeholder_text = "Suchen …"
	_search.custom_minimum_size = Vector2(260, 40)
	_search.text_changed.connect(func(_t): _rebuild())
	bar.add_child(_search)
	_category = OptionButton.new()
	_category.add_item("Alle Kategorien")
	for c in ItemDB.categories():
		_categories.append(c)
		_category.add_item(ItemDef.CATEGORY_NAMES[c])
	_category.item_selected.connect(func(_i): _rebuild())
	bar.add_child(_category)
	_rarity = OptionButton.new()
	_rarity.item_selected.connect(func(_i): _rebuild())
	bar.add_child(_rarity)
	_only_affordable = CheckButton.new()
	_only_affordable.text = "Nur leistbar"
	_only_affordable.toggled.connect(func(_b): _rebuild())
	bar.add_child(_only_affordable)
	UIKit.spacer(bar)
	_wallet = UIKit.label("", 20, UITheme.GOLD, bar)
	var body := UIKit.hbox(content, 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	var sc := UIKit.scroll(body, _grid)
	sc.custom_minimum_size = Vector2(820, 0)
	var detail := UIKit.panel(body, UITheme.PANEL_2, UITheme.LINE, 16)
	detail.custom_minimum_size = Vector2(340, 0)
	var dv := UIKit.vbox(detail, 8)
	_preview = PreviewViewport.new()
	_preview.custom_minimum_size = Vector2(300, 300)
	dv.add_child(_preview)
	_detail_name = UIKit.label("", 22, Color.WHITE, dv)
	_detail_rarity = UIKit.label("", 13, UITheme.MUTED, dv)
	_detail_desc = UIKit.label("", 15, UITheme.MUTED, dv)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_req = UIKit.label("", 14, UITheme.RED, dv)
	_detail_req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.spacer(dv, false)
	_buy = UIKit.primary("Kaufen", _on_buy, dv)
	Events.aura_changed.connect(_on_aura_changed)


func _on_aura_changed(_aura: float, _delta: float) -> void:
	if visible:
		_refresh_wallet()


## Kategorie für das nächste Öffnen (Vape-Shop-Automat, Taste B → Vapes)
static var next_category: StringName = &""


func set_shop(n: String, min_r: int, max_r: int) -> void:
	if _category:
		_category.selected = _categories.find(next_category) + 1 if next_category != &"" else 0
	next_category = &""
	shop_name = n
	min_rarity = min_r
	max_rarity = max_r
	title_label.text = n
	_rarity.clear()
	_rarity.add_item("Alle Raritäten")
	for r in range(min_r, max_r + 1):
		_rarity.add_item(ItemDef.RARITY_NAMES[r])
	_selected = null


func refresh() -> void:
	_refresh_wallet()
	_rebuild()


func _refresh_wallet() -> void:
	_wallet.text = "✦ " + UIFormat.number(Economy.aura)
	_update_detail()


func _filtered() -> Array[ItemDef]:
	var q := _search.text.strip_edges().to_lower()
	var cat: StringName = _categories[_category.selected - 1] if _category.selected > 0 else &""
	var rar := min_rarity + _rarity.selected - 1 if _rarity.selected > 0 else -1
	var out: Array[ItemDef] = []
	for item in ItemDB.all():
		if item.rarity < min_rarity or item.rarity > max_rarity:
			continue
		if item.starter or (item.hidden_until_unlocked and not Inventory.requirements_met(item)):
			continue
		if cat != &"" and item.category != cat:
			continue
		if rar >= 0 and item.rarity != rar:
			continue
		if q != "" and not (item.display_name.to_lower().contains(q) or item.description.to_lower().contains(q)):
			continue
		if _only_affordable.button_pressed and (Inventory.owns(item.id) or not Economy.can_afford(item.price)):
			continue
		out.append(item)
	return out


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var items := _filtered()
	for item in items:
		var card := ItemCard.new().setup(item, true)
		card.chosen.connect(_select)
		_grid.add_child(card)
	if items.is_empty():
		UIKit.label("Nichts gefunden – andere Filter probieren.", 16, UITheme.MUTED, _grid)
	if _selected == null and not items.is_empty():
		_select(items[0])
	else:
		_update_detail()


func _select(item: ItemDef) -> void:
	_selected = item
	_preview.show_with(item)
	for c in _grid.get_children():
		var card := c as ItemCard
		if card:
			card.button_pressed = card.item == item
	_update_detail()


func _update_detail() -> void:
	var item := _selected
	_buy.visible = item != null
	if item == null:
		_detail_name.text = "Item wählen"
		_detail_rarity.text = ""
		_detail_desc.text = ""
		_detail_req.text = ""
		return
	_detail_name.text = item.display_name
	_detail_rarity.text = "%s · %s" % [item.rarity_name(), ItemDef.CATEGORY_NAMES.get(item.category, "")]
	_detail_rarity.add_theme_color_override("font_color", item.rarity_color())
	_detail_desc.text = item.description
	if item.category == &"gadget":
		_detail_desc.text += "\n\nAura ×%s auf jede Wolke · Zug %d %%/s (%.1f s bis 100 %%)" % [str(Economy.vape_mult(item)), roundi(TrickSystem.rate_for(item)), 100.0 / TrickSystem.rate_for(item)]
	var reason := Inventory.unlock_reason(item)
	_buy.disabled = true
	if Inventory.owns(item.id):
		_detail_req.text = ""
		_buy.text = "Im Besitz"
	elif reason != "":
		_detail_req.text = "🔒 " + reason
		_buy.text = "Gesperrt"
	elif not Economy.can_afford(item.price):
		_detail_req.text = "Dir fehlen ✦ %s" % UIFormat.number(item.price - Economy.aura)
		_buy.text = "✦ %s" % UIFormat.number(item.price)
	else:
		_detail_req.text = ""
		_buy.text = "Kaufen · ✦ %s" % UIFormat.number(item.price)
		_buy.disabled = false


func _on_buy() -> void:
	var item := _selected
	if item == null:
		return
	confirm.ask("%s für ✦ %s kaufen?" % [item.display_name, UIFormat.number(item.price)], "Kaufen", _purchase.bind(item.id))


func _purchase(id: StringName) -> void:
	var err := Inventory.purchase(id)
	if err == "":
		Audio.play(&"purchase")
		var item := ItemDB.get_item(id)
		Inventory.equip(id)
		Events.toast.emit("Gekauft & ausgerüstet: %s" % item.display_name, item.rarity_color())
	else:
		Audio.play(&"denied")
		Events.toast.emit(err, UITheme.RED)
	_rebuild()

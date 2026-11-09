class_name InventoryScreen
extends UIScreen
## Inventar: alle eigenen Items als Raster mit Sortierung, Kategorie-Filter, Details und Ausrüsten/Ablegen.

var _grid: GridContainer
var _sort: OptionButton
var _category: OptionButton
var _count: Label
var _preview: PreviewViewport
var _name: Label
var _info: Label
var _equip: Button
var _selected: ItemDef
var _categories: Array[StringName] = []


func _init() -> void:
	screen_title = "Inventar"
	window_size = Vector2(1240, 720)


func build_content() -> void:
	var bar := UIKit.hbox(content, 10)
	_category = OptionButton.new()
	_category.add_item("Alle Kategorien")
	for c in ItemDB.categories():
		_categories.append(c)
		_category.add_item(ItemDef.CATEGORY_NAMES[c])
	_category.item_selected.connect(func(_i): refresh())
	bar.add_child(_category)
	_sort = OptionButton.new()
	for s in ["Rarität ↓", "Rarität ↑", "Name", "Kategorie"]:
		_sort.add_item(s)
	_sort.item_selected.connect(func(_i): refresh())
	bar.add_child(_sort)
	UIKit.spacer(bar)
	_count = UIKit.label("", 15, UITheme.MUTED, bar)
	var body := UIKit.hbox(content, 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	UIKit.scroll(body, _grid).custom_minimum_size = Vector2(820, 0)
	var detail := UIKit.panel(body, UITheme.PANEL_2, UITheme.LINE, 16)
	detail.custom_minimum_size = Vector2(340, 0)
	var dv := UIKit.vbox(detail, 8)
	_preview = PreviewViewport.new()
	_preview.custom_minimum_size = Vector2(300, 300)
	dv.add_child(_preview)
	_name = UIKit.label("", 22, Color.WHITE, dv)
	_info = UIKit.label("", 14, UITheme.MUTED, dv)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.spacer(dv, false)
	_equip = UIKit.primary("Ausrüsten", _toggle_equip, dv, UITheme.CYAN.darkened(0.2))


func _sorted() -> Array[ItemDef]:
	var cat: StringName = _categories[_category.selected - 1] if _category.selected > 0 else &""
	var out: Array[ItemDef] = []
	for id in Inventory.owned:
		var item := ItemDB.get_item(id)
		if item and (cat == &"" or item.category == cat):
			out.append(item)
	match _sort.selected:
		0: out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.rarity > b.rarity if a.rarity != b.rarity else a.display_name < b.display_name)
		1: out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.rarity < b.rarity if a.rarity != b.rarity else a.display_name < b.display_name)
		2: out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.display_name < b.display_name)
		3: out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return String(a.category) < String(b.category) if a.category != b.category else a.rarity > b.rarity)
	return out


func refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var items := _sorted()
	_count.text = "%d / %d Items" % [Inventory.owned.size(), ItemDB.items.size()]
	for item in items:
		var card := ItemCard.new().setup(item, false)
		card.chosen.connect(_select)
		_grid.add_child(card)
	if _selected == null or not Inventory.owns(_selected.id):
		_selected = items[0] if not items.is_empty() else null
	_update_detail()


func _select(item: ItemDef) -> void:
	_selected = item
	for c in _grid.get_children():
		var card := c as ItemCard
		if card:
			card.button_pressed = card.item == item
	_update_detail()


func _update_detail() -> void:
	_equip.visible = _selected != null
	if _selected == null:
		_name.text = "Leer"
		_info.text = ""
		return
	_preview.show_with(_selected)
	_name.text = _selected.display_name
	_name.add_theme_color_override("font_color", _selected.rarity_color())
	_info.text = "%s · %s\n\n%s" % [_selected.rarity_name(), ItemDef.CATEGORY_NAMES.get(_selected.category, ""), _selected.description]
	var equipped := Inventory.is_equipped(_selected.id)
	_equip.text = "Ablegen" if equipped else "Ausrüsten"
	_equip.disabled = equipped and _selected.slot() == &"skin"


func _toggle_equip() -> void:
	if _selected == null:
		return
	if Inventory.is_equipped(_selected.id):
		Inventory.unequip(_selected.slot())
	else:
		Inventory.equip(_selected.id)
	for c in _grid.get_children():
		var card := c as ItemCard
		if card:
			card.refresh(false)
	_update_detail()

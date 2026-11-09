class_name ItemCard
extends Button
## Kachel für ein Item (Shop & Inventar): Icon, Name, Rarität, Status (Preis / Besitz / ausgerüstet / gesperrt).

signal chosen(item: ItemDef)

var item: ItemDef
var _status: Label


func setup(it: ItemDef, show_price: bool) -> ItemCard:
	item = it
	custom_minimum_size = Vector2(150, 190)
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var c := it.rarity_color()
	add_theme_stylebox_override("normal", UITheme.box(UITheme.PANEL_2, 14, c.darkened(0.45), 1, 8))
	add_theme_stylebox_override("hover", UITheme.box(Color("261d42"), 14, c, 2, 8))
	add_theme_stylebox_override("pressed", UITheme.box(Color("2f2452"), 14, UITheme.CYAN, 2, 8))
	var v := UIKit.vbox(self, 6)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 10
	v.offset_bottom = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(center)
	center.add_child(UIKit.item_icon(it, 76))
	var name_l := UIKit.label(it.display_name, 14, Color.WHITE, v)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rar := UIKit.label(it.rarity_name().to_upper(), 11, c, v)
	rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = UIKit.label("", 13, UITheme.MUTED, v)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pressed.connect(func(): chosen.emit(item))
	refresh(show_price)
	return self


func refresh(show_price: bool) -> void:
	if Inventory.is_equipped(item.id):
		_status.text = "✔ Ausgerüstet"
		_status.add_theme_color_override("font_color", UITheme.CYAN)
	elif Inventory.owns(item.id):
		_status.text = "Im Besitz"
		_status.add_theme_color_override("font_color", UITheme.GREEN)
	elif not Inventory.requirements_met(item):
		_status.text = "🔒 Gesperrt"
		_status.add_theme_color_override("font_color", UITheme.RED)
	elif show_price:
		_status.text = "✦ " + UIFormat.number(item.price)
		_status.add_theme_color_override("font_color", UITheme.GOLD if Economy.can_afford(item.price) else UITheme.MUTED)

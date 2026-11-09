class_name CustomizeScreen
extends UIScreen
## Garderobe: pro Slot alle eigenen Varianten zum Durchklicken, Live-3D-Vorschau, Spielername.

const SLOT_NAMES := {
	&"skin": "Haut", &"hair": "Frisur", &"outfit": "Outfit", &"shoes": "Schuhe", &"accessory": "Accessoire",
	&"gadget": "Gadget", &"trail": "Spur", &"particle": "Partikel", &"title": "Titel", &"emote": "Emote [G]", &"animation": "Idle-Stil", &"board": "Hoverboard [Q]",
}

var _list: VBoxContainer
var _preview: PreviewViewport
var _name_edit: LineEdit
var _body_male: Button
var _body_female: Button


func _init() -> void:
	screen_title = "Garderobe"
	window_size = Vector2(1180, 720)


func build_content() -> void:
	var body := UIKit.hbox(content, 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := UIKit.vbox(body, 10)
	left.custom_minimum_size = Vector2(340, 0)
	_preview = PreviewViewport.new()
	_preview.custom_minimum_size = Vector2(340, 470)
	left.add_child(_preview)
	var body_row := UIKit.hbox(left, 8)
	UIKit.label("Figur", 13, UITheme.MUTED, body_row)
	_body_male = UIKit.button("Männlich", _set_body.bind(0), body_row, Vector2(110, 36))
	_body_female = UIKit.button("Weiblich", _set_body.bind(1), body_row, Vector2(110, 36))
	UIKit.label("Spielername", 13, UITheme.MUTED, left)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.text_submitted.connect(func(_t): _save_name())
	_name_edit.focus_exited.connect(_save_name)
	left.add_child(_name_edit)
	_list = UIKit.vbox(null, 8)
	UIKit.scroll(body, _list)


func _set_body(body: int) -> void:
	Settings.avatar_body = body
	Settings.apply()
	refresh()


func _save_name() -> void:
	var n := _name_edit.text.strip_edges().substr(0, 16)
	if n != "" and n != Identity.display_name:
		Identity.display_name = n
		Net.send({"type": "name", "name": n})
		SaveSystem.save_game()
		Events.toast.emit("Name gespeichert: " + n, UITheme.CYAN)


func refresh() -> void:
	_name_edit.text = Identity.display_name
	_body_male.disabled = Settings.avatar_body == 0
	_body_female.disabled = Settings.avatar_body == 1
	_preview.show_with(null)
	for c in _list.get_children():
		c.queue_free()
	for slot in Inventory.SLOTS:
		var row := UIKit.panel(_list, UITheme.PANEL_2, UITheme.LINE, 14)
		var v := UIKit.vbox(row, 6)
		var head := UIKit.hbox(v, 8)
		UIKit.label(SLOT_NAMES.get(slot, String(slot)), 16, Color.WHITE, head)
		var current := Inventory.equipped_item(slot)
		UIKit.label(current.display_name if current else "— nichts —", 14, current.rarity_color() if current else UITheme.MUTED, head)
		UIKit.spacer(head)
		if current and slot != &"skin":
			UIKit.button("Ablegen", _unequip.bind(slot), head, Vector2(100, 34))
		var options := UIKit.hbox(v, 8)
		var owned_any := false
		for item in ItemDB.all():
			if item.slot() != slot or not Inventory.owns(item.id):
				continue
			owned_any = true
			var b := Button.new()
			b.custom_minimum_size = Vector2(64, 64)
			b.tooltip_text = "%s (%s)" % [item.display_name, item.rarity_name()]
			b.flat = true
			var icon := UIKit.item_icon(item, 56)
			icon.position = Vector2(4, 4)
			b.add_child(icon)
			if Inventory.is_equipped(item.id):
				b.add_theme_stylebox_override("normal", UITheme.box(Color(0, 0, 0, 0), 12, UITheme.CYAN, 3, 0))
			b.pressed.connect(_equip.bind(item.id))
			b.mouse_entered.connect(_preview.show_with.bind(item))
			b.mouse_exited.connect(_preview.show_with.bind(null))
			options.add_child(b)
		if not owned_any:
			UIKit.label("Noch nichts – im Shop [B] holen.", 13, UITheme.MUTED, options)


func _equip(id: StringName) -> void:
	Inventory.equip(id)
	Audio.play(&"click")
	refresh()


func _unequip(slot: StringName) -> void:
	Inventory.unequip(slot)
	refresh()

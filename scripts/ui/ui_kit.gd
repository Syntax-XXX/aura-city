class_name UIKit
extends RefCounted
## Wiederverwendbare UI-Bausteine (Labels, Buttons mit Hover-Animation, Item-Icons, Chips, Leisten).


static func label(text: String, size := 17, color := UITheme.TEXT, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if parent:
		parent.add_child(l)
	return l


static func title(text: String, parent: Node = null, size := 30) -> Label:
	var l := label(text, size, Color.WHITE, parent)
	l.add_theme_constant_override("outline_size", 0)
	return l


## Button mit Klick-Sound und sanfter Hover-Skalierung.
static func button(text: String, callback: Callable, parent: Node = null, min_size := Vector2(0, 44)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if callback.is_valid():
		b.pressed.connect(callback)
	b.pressed.connect(func(): Audio.play(&"click"))
	b.mouse_entered.connect(_hover.bind(b, true))
	b.mouse_exited.connect(_hover.bind(b, false))
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	if parent:
		parent.add_child(b)
	return b


static func _hover(b: Button, on: bool) -> void:
	if b.disabled or not b.is_inside_tree():
		return
	if on:
		Audio.play(&"hover")
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * (1.03 if on else 1.0), 0.12).set_trans(Tween.TRANS_QUAD)


## Akzent-Button (gefüllt), z. B. „Kaufen“.
static func primary(text: String, callback: Callable, parent: Node = null, color := UITheme.PURPLE) -> Button:
	var b := button(text, callback, parent)
	b.add_theme_stylebox_override("normal", UITheme.box(color.darkened(0.15), 12, color.lightened(0.2), 1, 16))
	b.add_theme_stylebox_override("hover", UITheme.box(color, 12, Color.WHITE, 2, 16))
	b.add_theme_stylebox_override("pressed", UITheme.box(color.darkened(0.3), 12, UITheme.CYAN, 2, 16))
	b.add_theme_color_override("font_color", Color.WHITE)
	return b


static func panel(parent: Node = null, bg := UITheme.PANEL, border := UITheme.LINE, radius := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(bg, radius, border, 1, 18))
	if parent:
		parent.add_child(p)
	return p


static func vbox(parent: Node = null, sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	if parent:
		parent.add_child(v)
	return v


static func hbox(parent: Node = null, sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	if parent:
		parent.add_child(h)
	return h


static func spacer(parent: Node, horizontal := true) -> Control:
	var c := Control.new()
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


## Kleine farbige Marke (Rarität, Status).
static func chip(text: String, color: Color, parent: Node = null) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(color.darkened(0.7), 8, color, 1, 6))
	var l := label(text, 12, color, p)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if parent:
		parent.add_child(p)
	return p


## Prozedurales Item-Icon: Raritäts-Verlauf + Symbol (oder echte Textur, falls gesetzt).
static func item_icon(item: ItemDef, size := 72) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(size, size)
	var c := item.rarity_color()
	var sb := UITheme.box(c.darkened(0.72), int(size * 0.22), c, 2, 0)
	sb.shadow_color = Color(c, 0.35) if item.rarity >= ItemDef.Rarity.EPIC else Color(0, 0, 0, 0)
	sb.shadow_size = 6 if item.rarity >= ItemDef.Rarity.EPIC else 0
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.icon:
		var tr := TextureRect.new()
		tr.texture = item.icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(tr)
	else:
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(center)
		var swatch := PanelContainer.new()
		swatch.custom_minimum_size = Vector2(size * 0.62, size * 0.62)
		swatch.add_theme_stylebox_override("panel", UITheme.box(item.color, int(size * 0.31), item.accent_color, 2, 0))
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(swatch)
		var glyph := label(item.icon_glyph, int(size * 0.34), Color.WHITE)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		glyph.add_theme_constant_override("outline_size", 6)
		swatch.add_child(glyph)
	return frame


static func progress(value: float, max_value: float, color := UITheme.PURPLE, height := 10) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.add_theme_stylebox_override("fill", UITheme.box(color, int(height / 2), Color.TRANSPARENT, 0, 0))
	return bar


static func separator(parent: Node) -> void:
	var s := ColorRect.new()
	s.color = UITheme.LINE
	s.custom_minimum_size = Vector2(0, 1)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


## Scrollbereich mit Inhalt-Container.
static func scroll(parent: Node, content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	parent.add_child(s)
	return s

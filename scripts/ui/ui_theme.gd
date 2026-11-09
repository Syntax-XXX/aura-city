class_name UITheme
extends RefCounted
## Zentrales Theme: dunkle Flächen, Lila/Cyan-Akzente, runde Ecken, saubere Typo.
## Wird einmal gebaut und an die UI-Wurzel gehängt – alle Controls erben es.

const BG := Color("0d0a17")
const PANEL := Color("161126")
const PANEL_2 := Color("1f1836")
const LINE := Color("3b2f63")
const TEXT := Color("ede9fe")
const MUTED := Color("a99fca")
const PURPLE := Color("a855f7")
const CYAN := Color("22d3ee")
const PINK := Color("f472b6")
const GOLD := Color("facc15")
const GREEN := Color("4ade80")
const RED := Color("f87171")

static var _theme: Theme
static var _font: Font


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Inter", "Segoe UI", "Noto Sans", "DejaVu Sans", "Liberation Sans", "Arial", "Helvetica"])
		f.font_weight = 500
		var sym := SystemFont.new()
		sym.font_names = PackedStringArray(["Segoe UI Symbol", "Noto Sans Symbols 2", "DejaVu Sans", "Arial Unicode MS"])
		var emo := SystemFont.new()
		emo.font_names = PackedStringArray(["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"])
		f.fallbacks = [sym, emo]
		_font = f
	return _font


static func box(bg: Color, radius := 14, border := Color.TRANSPARENT, border_w := 0, margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.7
	s.content_margin_bottom = margin * 0.7
	s.anti_aliasing = true
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 17
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	# Buttons
	t.set_stylebox("normal", "Button", box(PANEL_2, 12, LINE, 1, 14))
	t.set_stylebox("hover", "Button", box(Color("2a2048"), 12, PURPLE, 2, 14))
	t.set_stylebox("pressed", "Button", box(Color("3b2a66"), 12, CYAN, 2, 14))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 12, CYAN, 2, 14))
	t.set_stylebox("disabled", "Button", box(Color("120e1f"), 12, Color("241c3d"), 1, 14))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", CYAN)
	t.set_color("font_disabled_color", "Button", Color("5b5280"))
	# Panels
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 18, LINE, 1, 18))
	t.set_stylebox("panel", "Panel", box(PANEL, 18, LINE, 1, 18))
	# Eingabefelder
	t.set_stylebox("normal", "LineEdit", box(Color("0f0b1c"), 10, LINE, 1, 12))
	t.set_stylebox("focus", "LineEdit", box(Color("0f0b1c"), 10, PURPLE, 2, 12))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", CYAN)
	# Fortschritt
	t.set_stylebox("background", "ProgressBar", box(Color("0f0b1c"), 8, LINE, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(PURPLE, 8, Color.TRANSPARENT, 0, 0))
	t.set_color("font_color", "ProgressBar", TEXT)
	# Slider
	t.set_stylebox("slider", "HSlider", box(Color("0f0b1c"), 6, LINE, 1, 3))
	t.set_stylebox("grabber_area", "HSlider", box(PURPLE, 6, Color.TRANSPARENT, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(CYAN, 6, Color.TRANSPARENT, 0, 3))
	# Option-Menü / CheckButton
	t.set_stylebox("normal", "OptionButton", box(PANEL_2, 10, LINE, 1, 12))
	t.set_stylebox("hover", "OptionButton", box(Color("2a2048"), 10, PURPLE, 2, 12))
	t.set_stylebox("pressed", "OptionButton", box(Color("3b2a66"), 10, CYAN, 2, 12))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_stylebox("panel", "PopupMenu", box(PANEL, 10, LINE, 1, 8))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", CYAN)
	t.set_stylebox("hover", "PopupMenu", box(Color("2a2048"), 6, Color.TRANSPARENT, 0, 6))
	# Scrollbar schlank
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0), 6, Color.TRANSPARENT, 0, 2))
	t.set_stylebox("grabber", "VScrollBar", box(LINE, 6, Color.TRANSPARENT, 0, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(PURPLE, 6, Color.TRANSPARENT, 0, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(CYAN, 6, Color.TRANSPARENT, 0, 2))
	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", box(PANEL_2, 8, LINE, 1, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	_theme = t
	return t

class_name MainMenu
extends Control
## Hauptmenü mit animiertem Neon-Hintergrund, Spielerprofil, Name, Einstellungen, Bestenliste.

signal play_pressed

const BG_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.15;
	float w = sin(uv.x * 6.0 + t * 3.0 + sin(uv.y * 4.0 - t * 2.0)) * 0.5 + 0.5;
	vec3 col = mix(vec3(0.05, 0.02, 0.12), vec3(0.32, 0.09, 0.55), smoothstep(0.2, 1.1, uv.y * 0.8 + w * 0.3));
	col = mix(col, vec3(0.05, 0.6, 0.75), pow(w, 8.0) * 0.35 * (1.0 - uv.y));
	vec2 g = fract(vec2(uv.x * 28.0, uv.y * 14.0 + TIME * 0.4));
	float line = step(0.965, g.x) + step(0.94, g.y);
	col += vec3(0.6, 0.3, 1.0) * line * 0.07 * uv.y;
	COLOR = vec4(col, 1.0);
}
"""

var confirm: UIConfirm
var _title: Label
var _profile: Label
var _name_edit: LineEdit
var _play: Button
var _notice: Label
var _settings: SettingsScreen
var _leaderboard: LeaderboardScreen
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = BG_SHADER
	bg.material = mat
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := UIKit.vbox(center, 14)
	v.custom_minimum_size = Vector2(520, 0)
	_title = UIKit.label("AURA CITY", 96, Color.WHITE, v)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override("outline_size", 18)
	_title.add_theme_color_override("font_outline_color", Color(0.55, 0.2, 0.95, 0.6))
	var sub := UIKit.label("Tricks. Combos. Aura. Werde zur Legende der Stadt.", 18, UITheme.CYAN, v)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var card := UIKit.panel(v, Color(0.07, 0.05, 0.14, 0.88), UITheme.LINE, 18)
	var cv := UIKit.vbox(card, 10)
	_profile = UIKit.label("", 15, UITheme.TEXT, cv)
	_profile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.label("Spielername", 13, UITheme.MUTED, cv)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.placeholder_text = "Dein Name"
	cv.add_child(_name_edit)
	_play = UIKit.primary("Spielen", _on_play, cv)
	_play.custom_minimum_size = Vector2(0, 58)
	_play.add_theme_font_size_override("font_size", 22)
	var row := UIKit.hbox(cv, 10)
	var b1 := UIKit.button("Einstellungen", _open_settings, row)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b2 := UIKit.button("Bestenliste", _open_leaderboard, row)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.button("Beenden", get_tree().quit, cv)
	_notice = UIKit.label("", 13, UITheme.GOLD, v)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ver := UIKit.label("v%s · Satire: alle „Gadgets“ sind rein kosmetisch" % ProjectSettings.get_setting("application/config/version", "0.1.0"), 12, UITheme.MUTED, self)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
	confirm = UIConfirm.new()
	_settings = SettingsScreen.new()
	_leaderboard = LeaderboardScreen.new()
	add_child(_settings)
	add_child(_leaderboard)
	add_child(confirm)
	_settings.confirm = confirm
	refresh()


func refresh() -> void:
	_name_edit.text = Identity.display_name
	var has_progress := Economy.lifetime > 0.0
	_play.text = "Weiterspielen" if has_progress else "Neues Spiel"
	_profile.text = "%s · ✦ %s · Lifetime ✦ %s · %d Items" % [Economy.rank_name(), UIFormat.number(Economy.aura), UIFormat.number(Economy.lifetime), Inventory.owned.size()]
	_profile.add_theme_color_override("font_color", Economy.rank_color())
	match SaveSystem.last_load_status:
		"backup": _notice.text = "Hinweis: Der Spielstand war beschädigt – das automatische Backup wurde geladen."
		"corrupt": _notice.text = "Hinweis: Spielstand und Backup waren beschädigt – neues Profil gestartet."
		_: _notice.text = ""


func _process(delta: float) -> void:
	_t += delta
	_title.add_theme_color_override("font_color", Color.from_hsv(0.75 + sin(_t * 0.6) * 0.08, 0.35, 1.0))


func _on_play() -> void:
	var n := _name_edit.text.strip_edges().substr(0, 16)
	if n != "":
		Identity.display_name = n
	SaveSystem.save_game()
	play_pressed.emit()


func _open_settings() -> void:
	_settings.open()


func _open_leaderboard() -> void:
	_leaderboard.open()

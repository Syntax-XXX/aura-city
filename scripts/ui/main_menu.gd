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
	// über der echten Stadt: links dunkler (Lesbarkeit), rechts durchsichtig
	COLOR = vec4(col, mix(0.85, 0.15, smoothstep(0.25, 0.8, uv.x)));
}
"""

var confirm: UIConfirm
var _title: Label
var _profile: Label
var _name_edit: LineEdit
var _play: Button
var _offline: Button
var _server_edit: LineEdit
var _notice: Label
var _settings: SettingsScreen
var _leaderboard: LeaderboardScreen
var _credits: CreditsScreen
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = BG_SHADER
	bg.material = mat
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 0.5 # Menü links, rechts sieht man die Stadt
	add_child(center)
	var v := UIKit.vbox(center, 14)
	v.custom_minimum_size = Vector2(520, 0)
	_title = UIKit.label("AURA CITY", 96, Color.WHITE, v)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override("outline_size", 18)
	_title.add_theme_color_override("font_outline_color", Color(0.55, 0.2, 0.95, 0.6))
	var sub := UIKit.label("Ziehen. Wolken. Aura. Werde zur Legende der Stadt.", 18, UITheme.CYAN, v)
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
	UIKit.label("Server (Online-Profil, Aura wird vom Server geprüft)", 13, UITheme.MUTED, cv)
	_server_edit = LineEdit.new()
	_server_edit.placeholder_text = Net.DEFAULT_URL
	cv.add_child(_server_edit)
	_play = UIKit.primary("Online spielen", _on_play_online, cv)
	_play.custom_minimum_size = Vector2(0, 58)
	_play.add_theme_font_size_override("font_size", 22)
	_offline = UIKit.button("Offline spielen (lokal, ohne Bestenliste)", _on_play_offline, cv)
	var row := UIKit.hbox(cv, 10)
	var b1 := UIKit.button("Einstellungen", _open_settings, row)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b2 := UIKit.button("Bestenliste", _open_leaderboard, row)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row2 := UIKit.hbox(cv, 10)
	var b3 := UIKit.button("Credits", func(): _credits.open(), row2)
	b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b4 := UIKit.button("Beenden", get_tree().quit, row2)
	b4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice = UIKit.label("", 13, UITheme.GOLD, v)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ver := UIKit.label("v%s · Satire: alle „Gadgets“ sind rein kosmetisch" % ProjectSettings.get_setting("application/config/version", "0.1.0"), 12, UITheme.MUTED, self)
	UIKit.pin(ver, Control.PRESET_BOTTOM_LEFT, 14)
	confirm = UIConfirm.new()
	_settings = SettingsScreen.new()
	_leaderboard = LeaderboardScreen.new()
	add_child(_settings)
	add_child(_leaderboard)
	_credits = CreditsScreen.new()
	add_child(_credits)
	add_child(confirm)
	_settings.confirm = confirm
	refresh()


func refresh() -> void:
	_name_edit.text = Identity.display_name
	_server_edit.text = Net.server_url
	_profile.text = "Offline-Profil: %s · ✦ %s · Lifetime ✦ %s · %d Items" % [Economy.rank_name(), UIFormat.number(Economy.aura), UIFormat.number(Economy.lifetime), Inventory.owned.size()]
	_profile.add_theme_color_override("font_color", Economy.rank_color())
	match SaveSystem.last_load_status:
		"backup": _notice.text = "Hinweis: Der Spielstand war beschädigt – das automatische Backup wurde geladen."
		"corrupt": _notice.text = "Hinweis: Spielstand und Backup waren beschädigt – neues Profil gestartet."
		_: _notice.text = ""


func _process(delta: float) -> void:
	_t += delta
	_title.add_theme_color_override("font_color", Color.from_hsv(0.75 + sin(_t * 0.6) * 0.08, 0.35, 1.0))


func _entered_name() -> String:
	var n := _name_edit.text.strip_edges().substr(0, 16)
	return n if n != "" else Identity.display_name


func _on_play_online() -> void:
	_play.disabled = true
	_offline.disabled = true
	_notice.text = "Verbinde mit %s …" % (_server_edit.text if _server_edit.text != "" else Net.DEFAULT_URL)
	var err := await Net.connect_profile(_server_edit.text if _server_edit.text.strip_edges() != "" else Net.DEFAULT_URL, _entered_name())
	_play.disabled = false
	_offline.disabled = false
	if err != "":
		_notice.text = "Online nicht möglich: %s\nDu kannst offline spielen – dieser Fortschritt bleibt lokal." % err
		return
	_notice.text = ""
	play_pressed.emit()


func _on_play_offline() -> void:
	Net.disconnect_profile()
	SaveSystem.load_game()
	Identity.display_name = _entered_name()
	SaveSystem.save_game()
	play_pressed.emit()


func _open_settings() -> void:
	_settings.open()


func _open_leaderboard() -> void:
	_leaderboard.open()

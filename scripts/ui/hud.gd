class_name HUD
extends Control
## Spiel-HUD: Aura (animiert), Rang + Fortschritt, Level, Aura/min, Combo, Timing-Leiste,
## Trick-Slots mit Cooldown, Quest-Tracker, Interaktions-Hinweis, Challenge-Status,
## Event-Banner, Uhrzeit/Bezirk, FPS.

var player: PlayerController
var world: WorldRoot

var _aura_label: Label
var _shown_aura := 0.0
var _rank_label: Label
var _rank_bar: ProgressBar
var _rank_next: Label
var _level_label: Label
var _apm_label: Label
var _combo_box: VBoxContainer
var _combo_label: Label
var _combo_mult: Label
var _combo_bar: ProgressBar
var _timing: Control
var _timing_name: Label
var _timing_bar: Control
var _needle: ColorRect
var _good_zone: ColorRect
var _perfect_zone: ColorRect
var _slots: Array[Dictionary] = []
var _quest_box: VBoxContainer
var _prompt: Label
var _challenge: Label
var _event: Label
var _boost: Label
var _clock: Label
var _district: Label
var _fps: Label
var _net: Label
var _quest_refresh := 0.0

const TIMING_W := 520.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_left()
	_build_top_right()
	_build_combo()
	_build_timing()
	_build_slots()
	_build_center_texts()
	var legend := UIKit.label("" if TouchControls.wanted() else "[Q] Hoverboard   [N] Aura-Kiosk   [B] Shop   [K] Wolkenbuch   [P] Foto-Modus   [Esc] Menü", 12, Color(1, 1, 1, 0.55), self)
	legend.add_theme_constant_override("outline_size", 4)
	legend.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	UIKit.pin(legend, Control.PRESET_BOTTOM_LEFT, 12)
	_shown_aura = Economy.aura
	Events.combo_changed.connect(_on_combo)
	Events.combo_ended.connect(_on_combo_end)
	Events.interaction_prompt.connect(_on_prompt)
	Events.challenge_status.connect(_on_challenge_status)
	Events.district_entered.connect(_on_district)
	Events.aura_rewarded.connect(_on_reward)
	Events.quest_progressed.connect(_on_quest_progress)
	player.tricks.timing_started.connect(_on_timing_started)
	player.tricks.timing_updated.connect(_on_timing_updated)
	player.tricks.timing_finished.connect(_on_timing_finished)
	_refresh_slots_labels()
	_refresh_quests()


func _panel_at(preset: int) -> PanelContainer:
	var p := UIKit.panel(self, Color(0.06, 0.04, 0.12, 0.78), UITheme.LINE, 14)
	UIKit.pin(p, preset, 18)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_top_left() -> void:
	var p := _panel_at(Control.PRESET_TOP_LEFT)
	p.custom_minimum_size = Vector2(340, 0)
	var v := UIKit.vbox(p, 4)
	_aura_label = UIKit.label("", 34, UITheme.GOLD, v)
	var row := UIKit.hbox(v, 8)
	_rank_label = UIKit.label("", 18, Color.WHITE, row)
	UIKit.spacer(row)
	_level_label = UIKit.label("", 14, UITheme.CYAN, row)
	_rank_bar = UIKit.progress(0, 1, UITheme.PURPLE, 8)
	v.add_child(_rank_bar)
	_rank_next = UIKit.label("", 12, UITheme.MUTED, v)
	_apm_label = UIKit.label("", 13, UITheme.MUTED, v)
	_boost = UIKit.label("", 14, UITheme.CYAN, v)
	var qt := UIKit.label("Quests [J]", 13, UITheme.CYAN, v)
	qt.add_theme_constant_override("line_spacing", 0)
	_quest_box = UIKit.vbox(v, 2)


func _build_top_right() -> void:
	var p := _panel_at(Control.PRESET_TOP_RIGHT)
	var v := UIKit.vbox(p, 2)
	var minimap := Minimap.new()
	minimap.player = player
	v.add_child(minimap)
	_clock = UIKit.label("", 20, Color.WHITE, v)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_district = UIKit.label("Spawn City", 14, UITheme.CYAN, v)
	_district.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_net = UIKit.label("", 12, UITheme.MUTED, v)
	_net.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps = UIKit.label("", 12, UITheme.MUTED, v)
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_combo() -> void:
	_combo_box = UIKit.vbox(self, 2)
	UIKit.pin(_combo_box, Control.PRESET_CENTER_RIGHT, 40)
	_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_label = UIKit.label("", 46, UITheme.PINK, _combo_box)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_mult = UIKit.label("", 18, UITheme.CYAN, _combo_box)
	_combo_mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_bar = UIKit.progress(0, TrickSystem.COMBO_WINDOW, UITheme.PINK, 6)
	_combo_bar.custom_minimum_size = Vector2(160, 6)
	_combo_box.add_child(_combo_bar)
	_combo_box.visible = false


func _build_timing() -> void:
	_timing = VBoxContainer.new()
	_timing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timing.custom_minimum_size = Vector2(TIMING_W, 70)
	add_child(_timing)
	UIKit.pin(_timing, Control.PRESET_CENTER_BOTTOM, 120)
	_timing_name = UIKit.label("", 20, Color.WHITE, _timing)
	_timing_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timing_bar = Panel.new()
	_timing_bar.custom_minimum_size = Vector2(TIMING_W, 26)
	_timing_bar.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.03, 0.1, 0.85), 13, UITheme.LINE, 2, 0))
	_timing.add_child(_timing_bar)
	_good_zone = ColorRect.new()
	_good_zone.color = Color(UITheme.CYAN, 0.35)
	_timing_bar.add_child(_good_zone)
	_perfect_zone = ColorRect.new()
	_perfect_zone.color = Color(UITheme.GOLD, 0.8)
	_timing_bar.add_child(_perfect_zone)
	_needle = ColorRect.new()
	_needle.color = Color.WHITE
	_needle.size = Vector2(4, 34)
	_timing_bar.add_child(_needle)
	var hint := UIKit.label("Tippe AUSATMEN, wenn die Nadel im Feld ist" if TouchControls.wanted() else "[%s] / Linksklick zum Ausatmen" % Controls.key_label("trick_land"), 13, UITheme.MUTED, _timing)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timing.visible = false


func _build_slots() -> void:
	var row := UIKit.hbox(self, 10)
	UIKit.pin(row, Control.PRESET_CENTER_BOTTOM, 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:
		var p := UIKit.panel(row, Color(0.06, 0.04, 0.12, 0.85), UITheme.LINE, 12)
		p.custom_minimum_size = Vector2(150, 64)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := UIKit.vbox(p, 2)
		var key := UIKit.label("[%d]" % (i + 1), 12, UITheme.CYAN, v)
		var name_l := UIKit.label("", 15, Color.WHITE, v)
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var cd := UIKit.progress(0, 1, UITheme.PURPLE, 4)
		v.add_child(cd)
		_slots.append({"panel": p, "key": key, "name": name_l, "cd": cd})
	# Zentrum: Fadenkreuz-Punkt
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.5)
	dot.size = Vector2(4, 4)
	dot.custom_minimum_size = Vector2(4, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)
	UIKit.pin(dot, Control.PRESET_CENTER)


func _build_center_texts() -> void:
	_prompt = UIKit.label("", 20, Color.WHITE, self)
	_prompt.custom_minimum_size = Vector2(600, 0)
	UIKit.pin(_prompt, Control.PRESET_CENTER)
	_prompt.offset_top += 90
	_prompt.offset_bottom += 90
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_challenge = UIKit.label("", 18, UITheme.GOLD, self)
	_challenge.custom_minimum_size = Vector2(600, 0)
	UIKit.pin(_challenge, Control.PRESET_CENTER_TOP, 110)
	_challenge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_challenge.add_theme_constant_override("outline_size", 6)
	_challenge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_event = UIKit.label("", 24, UITheme.PINK, self)
	_event.custom_minimum_size = Vector2(600, 0)
	UIKit.pin(_event, Control.PRESET_CENTER_TOP, 24)
	_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event.add_theme_constant_override("outline_size", 8)
	_event.add_theme_color_override("font_outline_color", Color(0.1, 0, 0.2, 0.9))


func _process(delta: float) -> void:
	# Aura-Zähler läuft weich hoch/runter
	_shown_aura = lerpf(_shown_aura, Economy.aura, minf(1.0, delta * 8.0))
	if absf(_shown_aura - Economy.aura) < 0.5:
		_shown_aura = Economy.aura
	_aura_label.text = "✦ " + UIFormat.number(_shown_aura)
	_rank_label.text = Economy.rank_name()
	_rank_label.add_theme_color_override("font_color", Economy.rank_color())
	var nr := Economy.next_rank_progress()
	_rank_bar.max_value = 1.0
	_rank_bar.value = nr["progress"]
	_rank_next.text = "Max-Rang erreicht" if nr["name"] == "" else "Noch ✦ %s bis %s" % [UIFormat.number(nr["missing"]), nr["name"]]
	_level_label.text = "Lv. %d" % Economy.level()
	_apm_label.text = "✦ %s / min" % UIFormat.number(Economy.aura_per_minute())
	# Combo-Zeit
	if _combo_box.visible:
		_combo_bar.value = player.tricks.combo_time_left
	# Cooldowns
	for i in 4:
		var id: StringName = TrickDB.loadout[i]
		var t := TrickDB.get_trick(id)
		var left := player.tricks.cooldown_left(id)
		var bar: ProgressBar = _slots[i]["cd"]
		bar.max_value = t.cooldown if t else 1.0
		bar.value = (t.cooldown - left) if t else 0.0
		var p: PanelContainer = _slots[i]["panel"]
		p.modulate.a = 0.55 if left > 0.0 else 1.0
	# Event
	var ev := Economy.event_seconds_left()
	var bl := Economy.boost_seconds_left()
	_boost.visible = bl > 0.0
	if bl > 0.0:
		var dr := Drinks.get_drink(Economy.boost_id)
		_boost.text = "%s %s · %s" % [dr.get("glyph", ""), dr.get("name", ""), UIFormat.seconds(bl)]
		_boost.add_theme_color_override("font_color", Color(dr.get("color", "ffffff")))
	_event.text = "⚡ AURA RUSH ×%s · %ds" % [str(Economy.event_multiplier), ceili(ev)] if ev > 0.0 else ""
	if world and world.day_night:
		_clock.text = world.day_night.clock_text()
	if Net.online:
		_net.text = "⚠ Profil wird geprüft" if Net.flagged else "● " + Net.status_text
		_net.add_theme_color_override("font_color", UITheme.RED if Net.flagged or Net.status_text != "Online" else UITheme.GREEN)
	else:
		_net.text = "● Offline-Profil"
	_fps.visible = Settings.show_fps
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	_quest_refresh -= delta
	if _quest_refresh <= 0.0:
		_quest_refresh = 2.0
		_refresh_slots_labels()


func _refresh_slots_labels() -> void:
	for i in 4:
		var t := TrickDB.get_trick(TrickDB.loadout[i])
		(_slots[i]["name"] as Label).text = t.display_name if t else "—"
		(_slots[i]["name"] as Label).add_theme_color_override("font_color", t.effect_color.lightened(0.3) if t else UITheme.MUTED)


func _refresh_quests() -> void:
	for c in _quest_box.get_children():
		c.queue_free()
	var shown := 0
	for q in Quests.list(QuestDef.Period.DAILY):
		if Quests.is_completed(q.id) or shown >= 3:
			continue
		shown += 1
		UIKit.label("• %s  %d/%d" % [q.display_name, mini(Quests.get_progress(q.id), q.goal), q.goal], 12, UITheme.TEXT, _quest_box)
	if shown == 0:
		UIKit.label("✔ Alle Tagesquests erledigt", 12, UITheme.GREEN, _quest_box)


func _on_quest_progress(_id: StringName, _p: int, _g: int) -> void:
	_refresh_quests()


func _on_combo(combo: int, mult: float) -> void:
	_combo_box.visible = combo >= 2
	_combo_label.text = "×%d COMBO" % combo
	_combo_mult.text = "Aura ×%.2f" % mult
	_combo_label.pivot_offset = _combo_label.size / 2.0
	var tw := create_tween()
	_combo_label.scale = Vector2.ONE * 1.35
	tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _on_combo_end(_final: int) -> void:
	_combo_box.visible = false


func _on_prompt(text: String) -> void:
	_prompt.text = text


func _on_challenge_status(text: String) -> void:
	_challenge.text = text


func _on_district(id: StringName) -> void:
	_district.text = DistrictArea.NAMES.get(id, String(id))


func _on_reward(amount: float, _reason: String, _pos: Vector3) -> void:
	if amount <= 0.0:
		return
	_aura_label.pivot_offset = _aura_label.size / 2.0
	_aura_label.scale = Vector2.ONE * 1.12
	create_tween().tween_property(_aura_label, "scale", Vector2.ONE, 0.2)


func _on_timing_started(trick: TrickDef, window: float, perfect_window: float) -> void:
	_timing.visible = true
	_timing_name.text = trick.display_name
	_timing_name.add_theme_color_override("font_color", trick.effect_color.lightened(0.3))
	# Leiste: Nadel 0..1, Zielmitte 0.5
	_good_zone.position = Vector2((0.5 - window * 0.5) * TIMING_W, 0)
	_good_zone.size = Vector2(window * TIMING_W, 26)
	_perfect_zone.position = Vector2((0.5 - perfect_window * 0.5) * TIMING_W, 0)
	_perfect_zone.size = Vector2(perfect_window * TIMING_W, 26)


func _on_timing_updated(needle: float) -> void:
	_needle.position = Vector2(needle * TIMING_W - 2, -4)


func _on_timing_finished(quality: StringName) -> void:
	_timing_name.text = {&"perfect": "PERFEKT!", &"good": "Gut", &"fail": "Verpatzt"}.get(quality, "")
	_timing_name.add_theme_color_override("font_color", {&"perfect": UITheme.GOLD, &"good": UITheme.CYAN}.get(quality, UITheme.RED))
	await get_tree().create_timer(0.45).timeout
	if player.tricks.phase != TrickSystem.Phase.TIMING:
		_timing.visible = false

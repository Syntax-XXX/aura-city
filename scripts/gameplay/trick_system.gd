class_name TrickSystem
extends Node
## Dampfen wie in Aura Farm V1 (intern heißen Wolken noch „Tricks“, der Server nutzt die IDs):
##  1. F / rechte Maustaste HALTEN = ziehen → die Zug-Leiste füllt sich (Tempo hängt von der Vape ab).
##  2. Währenddessen Pfeiltasten = Kombo eingeben (z. B. ↓ ↑ = Ghost). Ohne Kombo = einfache Wolke.
##  3. Loslassen = ausblasen. Kombo passt + genug gezogen → Wolke + Aura (ab 75 % = Perfect).
##  Falsche Kombo, zu wenig gezogen oder 100 % erreicht (Husten) → Aura weg, Combo vorbei.

signal inhale_started
## charge 0–100, typed = eingegebene Pfeile, target = passende Wolke (oder null), bad = Kombo falsch
signal inhale_updated(charge: float, typed: String, target: TrickDef, bad: bool)
signal inhale_finished(quality: StringName, trick: TrickDef, reason: String)

enum Phase { READY, INHALING, PERFORMING }

## Längster möglicher Zug in Sekunden (langsamste Vape) – der Server rechnet damit sein Combo-Fenster.
const TIMING_TIMEOUT := 5.0
const COMBO_WINDOW := 3.2
const PERFECT_CHARGE := 75.0
const FAIL_PAUSE := 1.2

@export var animator: CharacterAnimator
@export var visual: CharacterVisual
var player: Node3D
var camera_rig: CameraRig

var phase: Phase = Phase.READY
var charge := 0.0
var typed := ""
var combo := 0
var combo_time_left := 0.0
var combo_chain: Array[StringName] = []
## Von Challenges gesetzt (z. B. 1.5 während einer Challenge)
var challenge_multiplier := 1.0

var _pause_left := 0.0
var _cooldowns := {} # StringName -> Sekunden


func _process(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id] = float(_cooldowns[id]) - delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	match phase:
		Phase.INHALING:
			charge += charge_rate() * delta
			if charge >= 100.0:
				charge = 100.0
				_fail(TrickDB.get_trick(&"basic_spin"), "Zu lange gezogen – Hustenanfall!")
			else:
				_emit_update()
		Phase.PERFORMING:
			_pause_left -= delta
			if _pause_left <= 0.0:
				phase = Phase.READY
	if combo > 0 and phase == Phase.READY:
		combo_time_left -= delta
		if combo_time_left <= 0.0:
			end_combo()


## % pro Sekunde: größere Vapes ziehen langsamer (mehr Zeit für lange Kombos).
static func rate_for(gadget: ItemDef) -> float:
	return 30.0 - (gadget.rarity * 1.2 if gadget else 0.0)


func charge_rate() -> float:
	return TrickSystem.rate_for(Inventory.equipped_item(&"gadget"))


func cooldown_left(id: StringName) -> float:
	return float(_cooldowns.get(id, 0.0))


func is_busy() -> bool:
	return phase != Phase.READY


func is_inhaling() -> bool:
	return phase == Phase.INHALING


## Freigeschaltete Wolke mit genau dieser Kombo (oder null).
static func match_keys(k: String) -> TrickDef:
	for t: TrickDef in TrickDB.all():
		if t.keys == k and TrickDB.is_unlocked(t.id):
			return t
	return null


## Gibt es eine freigeschaltete Wolke, deren Kombo so anfängt?
static func is_prefix(k: String) -> bool:
	for t: TrickDef in TrickDB.all():
		if t.keys.begins_with(k) and TrickDB.is_unlocked(t.id):
			return true
	return false


## Qualität eines Zugs (rein, testbar): "" = kein Fehler, sonst Fehlergrund.
static func judge(trick: TrickDef, charge_pct: float) -> Array:
	if trick == null:
		return [&"fail", "Kombo verkackt"]
	if charge_pct >= 100.0:
		return [&"fail", "Zu lange gezogen – Hustenanfall!"]
	if charge_pct < trick.min_charge:
		return [&"fail", "Zu wenig gezogen für %s (%d/%d %%)" % [trick.display_name, int(charge_pct), trick.min_charge]]
	return [&"perfect" if charge_pct >= maxf(PERFECT_CHARGE, minf(trick.min_charge + 15.0, 95.0)) else &"good", ""]


func start_inhale() -> String:
	if phase != Phase.READY:
		return "Beschäftigt"
	phase = Phase.INHALING
	charge = 0.0
	typed = ""
	inhale_started.emit()
	_emit_update()
	Events.trick_started.emit(&"inhale")
	Audio.play(&"trick_start", 0.8)
	if animator and not _first_person():
		animator.play_action(&"pull", TIMING_TIMEOUT)
	return ""


func push_key(k: String) -> void:
	if phase != Phase.INHALING or not k in ["U", "D", "L", "R"]:
		return
	typed += k
	Audio.play(&"click" if TrickSystem.is_prefix(typed) else &"fail", 1.2)
	_emit_update()


func release() -> void:
	if phase != Phase.INHALING:
		return
	var bad := not TrickSystem.is_prefix(typed)
	var trick: TrickDef = null if bad else TrickSystem.match_keys(typed)
	var verdict := TrickSystem.judge(trick, charge)
	if verdict[0] == &"fail":
		# Bei „zu wenig gezogen“ zählt der Fehlschlag für die angepeilte Wolke
		_fail(trick if trick else TrickDB.get_trick(&"basic_spin"), verdict[1])
		return
	if cooldown_left(trick.id) > 0.0:
		phase = Phase.PERFORMING
		_pause_left = 0.4
		inhale_finished.emit(&"none", trick, "%s braucht noch %.1f s" % [trick.display_name, cooldown_left(trick.id)])
		_cloud(TrickDB.get_trick(&"basic_spin"), Color(0.8, 0.8, 0.8), 0.6)
		return
	_finish(trick, verdict[0])


## Für Tests und Touch-Demo: kompletten Zug mit Kombo und Zugstärke auf einmal ausführen.
func perform(id: StringName, charge_pct := 80.0) -> String:
	var t := TrickDB.get_trick(id)
	if t == null:
		return "Unbekannt"
	var err := start_inhale()
	if err != "":
		return err
	for k in t.keys:
		push_key(k)
	charge = charge_pct
	release()
	return ""


func _emit_update() -> void:
	var bad := not TrickSystem.is_prefix(typed)
	inhale_updated.emit(charge, typed, null if bad else TrickSystem.match_keys(typed), bad)


func _first_person() -> bool:
	return camera_rig != null and camera_rig.first_person


func _mouth() -> Array:
	if camera_rig and camera_rig.first_person:
		var cam := camera_rig.camera.global_transform
		return [cam * Vector3(0, -0.12, -0.35), -cam.basis.z]
	var fwd := -player.global_transform.basis.z
	return [visual.mouth_position(fwd) if visual else player.global_position + Vector3.UP * 1.55, fwd]


func _fail(trick: TrickDef, reason: String) -> void:
	phase = Phase.PERFORMING
	_pause_left = FAIL_PAUSE
	_cooldowns[trick.id] = maxf(trick.cooldown, _cooldowns.get(trick.id, 0.0))
	inhale_finished.emit(&"fail", trick, reason)
	if animator and not _first_person():
		animator.play_action(&"cough", FAIL_PAUSE)
	Audio.play(&"fail")
	Economy.lose(trick.base_aura * Economy.FAIL_LOSS, "Husten", player.global_position + Vector3.UP * 2.2 if player else Vector3.ZERO)
	if player:
		var m := _mouth()
		FX.cough(player.get_parent(), m[0], m[1])
		if camera_rig:
			camera_rig.shake(0.25)
	Events.toast.emit(reason, Color("fca5a5"))
	Events.trick_failed.emit(trick.id)
	end_combo()


func _finish(trick: TrickDef, quality: StringName) -> void:
	inhale_finished.emit(quality, trick, "")
	_cooldowns[trick.id] = trick.cooldown
	phase = Phase.PERFORMING
	_pause_left = trick.duration
	combo += 1
	combo_chain.append(trick.id)
	combo_time_left = COMBO_WINDOW
	var multiplier := Economy.combo_multiplier(combo) + (trick.combo_bonus if combo > 1 else 0.0)
	var aura := Economy.calculate_trick_aura(trick, quality, multiplier, TrickDB.mastery_level(trick.id), challenge_multiplier)
	var pos := player.global_position + Vector3.UP * 2.2 if player else Vector3.ZERO
	var granted := Economy.earn(aura, trick.display_name, pos)
	TrickDB.add_mastery_hit(trick.id)
	if animator and not _first_person():
		animator.play_action(trick.animation, trick.duration)
	_effects(trick, quality)
	Audio.play(&"land_perfect" if quality == &"perfect" else &"land_good", trick.sound_pitch)
	if combo > 1:
		Audio.play(&"combo", 1.0 + combo * 0.05)
	Events.trick_landed.emit(trick.id, quality, granted, combo)
	Events.combo_changed.emit(combo, multiplier)
	_check_chains()


func _cloud(trick: TrickDef, color: Color, strength: float) -> void:
	if player == null:
		return
	var m := _mouth()
	FX.vape_cloud(player.get_parent(), m[0], m[1], color, trick.cloud_shape, trick.cloud_count, strength)


func _effects(trick: TrickDef, quality: StringName) -> void:
	if player == null:
		return
	var world := player.get_parent()
	var gadget: ItemDef = Inventory.equipped_item(&"gadget")
	var cloud_color := gadget.accent_color if gadget else trick.effect_color
	var strength := (1.0 + trick.tier * 0.6 + (0.3 if quality == &"perfect" else 0.0)) * (0.6 + charge / 100.0 * 0.6)
	if gadget and gadget.rarity >= ItemDef.Rarity.LEGENDARY:
		strength += 0.6
	_cloud(trick, cloud_color, strength)
	if trick.tier > 0 or quality == &"perfect":
		FX.sparkles(world, player.global_position + Vector3.UP * 1.2, trick.effect_color, 10 + trick.tier * 16, 1.0 + trick.tier * 0.4)
	if trick.tier == TrickDef.Tier.LEGENDARY and camera_rig:
		camera_rig.shake(0.6 if trick.id == &"aura_explosion" else 0.35)


func _check_chains() -> void:
	for chain in TrickDB.CHAINS:
		var seq: Array = chain["sequence"]
		if combo_chain.size() < seq.size():
			continue
		var tail := combo_chain.slice(combo_chain.size() - seq.size())
		var match_all := true
		for i in seq.size():
			if tail[i] != seq[i]:
				match_all = false
				break
		if match_all:
			var pos := player.global_position + Vector3.UP * 2.8 if player else Vector3.ZERO
			Economy.earn(float(chain["bonus"]) * challenge_multiplier, "Kette: " + str(chain["name"]), pos)
			Events.chain_completed.emit(str(chain["name"]))
			Events.toast.emit("Wolken-Kette: %s!" % chain["name"], Color("facc15"))
			Audio.play(&"reward")


func end_combo() -> void:
	if combo > 0:
		Events.combo_ended.emit(combo)
	combo = 0
	combo_chain.clear()
	Events.combo_changed.emit(0, 1.0)

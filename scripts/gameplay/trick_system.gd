class_name TrickSystem
extends Node
## Trick-Ablauf am Spieler:
##  1. Taste 1–4 startet den Trick aus dem Loadout → Timing-Leiste läuft (Nadel pendelt).
##  2. Linke Maustaste / F „landet“ den Trick: grüne Zone = Good, Mitte = Perfect, daneben = Fail.
##  3. Erfolgreiche Tricks in kurzer Folge bilden eine Combo (Multiplikator), feste Folgen = Ketten-Bonus.
## Ein Fail kostet keine Aura – nur die Combo endet.

signal timing_started(trick: TrickDef, window: float, perfect_window: float)
signal timing_updated(needle: float)
signal timing_finished(quality: StringName)

enum Phase { READY, TIMING, PERFORMING }

const TIMING_TIMEOUT := 2.4
const COMBO_WINDOW := 3.2

@export var animator: CharacterAnimator
@export var visual: CharacterVisual
var player: Node3D
var camera_rig: CameraRig

var phase: Phase = Phase.READY
var current: TrickDef
var needle := 0.0
var combo := 0
var combo_time_left := 0.0
var combo_chain: Array[StringName] = []
## Von Challenges gesetzt (z. B. 1.5 während einer Challenge)
var challenge_multiplier := 1.0

var _needle_dir := 1.0
var _timing_elapsed := 0.0
var _cooldowns := {} # StringName -> Sekunden
var _rng := RandomNumberGenerator.new()


func _process(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id] = float(_cooldowns[id]) - delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	match phase:
		Phase.TIMING:
			_timing_elapsed += delta
			needle += _needle_dir * current.needle_speed() * delta * 2.0
			if needle >= 1.0:
				needle = 1.0
				_needle_dir = -1.0
			elif needle <= 0.0:
				needle = 0.0
				_needle_dir = 1.0
			timing_updated.emit(needle)
			if _timing_elapsed >= TIMING_TIMEOUT:
				_finish(&"fail")
		Phase.PERFORMING:
			if animator and not animator.is_busy():
				phase = Phase.READY
	if combo > 0 and phase != Phase.PERFORMING and phase != Phase.TIMING:
		combo_time_left -= delta
		if combo_time_left <= 0.0:
			end_combo()


func cooldown_left(id: StringName) -> float:
	return float(_cooldowns.get(id, 0.0))


func is_busy() -> bool:
	return phase != Phase.READY


## Trick aus Loadout-Slot (0–3) starten. Liefert Fehlertext oder "".
func start_slot(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= TrickDB.loadout.size():
		return "Kein Trick"
	return start_trick(TrickDB.loadout[slot_index])


func start_trick(id: StringName) -> String:
	var trick := TrickDB.get_trick(id)
	if trick == null:
		return "Unbekannter Trick"
	if not TrickDB.is_unlocked(id):
		return "Noch gesperrt"
	if phase != Phase.READY:
		return "Beschäftigt"
	if cooldown_left(id) > 0.0:
		return "Abklingzeit %.1f s" % cooldown_left(id)
	current = trick
	phase = Phase.TIMING
	needle = _rng.randf_range(0.0, 0.25)
	_needle_dir = 1.0
	_timing_elapsed = 0.0
	var window := trick.timing_window() * (1.0 + TrickDB.mastery_level(id) * 0.06) * Economy.boost("timing")
	timing_started.emit(trick, window, window * 0.3)
	Events.trick_started.emit(id)
	Audio.play(&"trick_start", trick.sound_pitch)
	return ""


## Qualität aus Nadelposition (rein, testbar).
static func evaluate(needle_pos: float, window: float) -> StringName:
	var off := absf(needle_pos - 0.5)
	if off <= window * 0.15:
		return &"perfect"
	if off <= window * 0.5:
		return &"good"
	return &"fail"


## Spieler drückt „Landen“.
func land() -> void:
	if phase != Phase.TIMING:
		return
	var window := current.timing_window() * (1.0 + TrickDB.mastery_level(current.id) * 0.06) * Economy.boost("timing")
	_finish(evaluate(needle, window))


func _finish(quality: StringName) -> void:
	timing_finished.emit(quality)
	var trick := current
	_cooldowns[trick.id] = trick.cooldown
	if quality == &"fail":
		phase = Phase.READY
		if animator:
			animator.play_action(&"twist", 0.35)
		Audio.play(&"fail")
		Events.trick_failed.emit(trick.id)
		end_combo()
		return
	phase = Phase.PERFORMING
	combo += 1
	combo_chain.append(trick.id)
	combo_time_left = COMBO_WINDOW
	var multiplier := Economy.combo_multiplier(combo) + (trick.combo_bonus if combo > 1 else 0.0)
	var aura := Economy.calculate_trick_aura(trick, quality, multiplier, TrickDB.mastery_level(trick.id), challenge_multiplier)
	var pos := player.global_position + Vector3.UP * 2.2 if player else Vector3.ZERO
	var granted := Economy.earn(aura, trick.display_name, pos)
	TrickDB.add_mastery_hit(trick.id)
	if animator:
		animator.play_action(trick.animation, trick.duration)
	_effects(trick, quality)
	Audio.play(&"land_perfect" if quality == &"perfect" else &"land_good", trick.sound_pitch)
	if combo > 1:
		Audio.play(&"combo", 1.0 + combo * 0.05)
	Events.trick_landed.emit(trick.id, quality, granted, combo)
	Events.combo_changed.emit(combo, multiplier)
	_check_chains()


func _effects(trick: TrickDef, quality: StringName) -> void:
	if player == null:
		return
	var world := player.get_parent()
	var gadget: ItemDef = Inventory.equipped_item(&"gadget")
	var cloud_color := gadget.accent_color if gadget else trick.effect_color
	var strength := 1.0 + trick.tier * 0.6 + (0.3 if quality == &"perfect" else 0.0)
	if gadget and gadget.rarity >= ItemDef.Rarity.LEGENDARY:
		strength += 0.6
	var tip := visual.gadget_tip.global_position if visual else player.global_position + Vector3.UP * 1.5
	FX.cloud(world, tip, -player.global_transform.basis.z + Vector3.UP * 0.4, cloud_color, strength)
	FX.sparkles(world, player.global_position + Vector3.UP * 1.2, trick.effect_color, 16 + trick.tier * 20, 1.0 + trick.tier * 0.4)
	if trick.tier == TrickDef.Tier.LEGENDARY or quality == &"perfect":
		FX.ring(world, player.global_position + Vector3.UP * 0.2, trick.effect_color, 2.0 + trick.tier * 1.5)
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
			Events.toast.emit("Trick-Kette: %s!" % chain["name"], Color("facc15"))
			Audio.play(&"reward")


func end_combo() -> void:
	if combo > 0:
		Events.combo_ended.emit(combo)
	combo = 0
	combo_chain.clear()
	Events.combo_changed.emit(0, 1.0)

class_name CharacterAnimator
extends Node
## Prozedurale Animations-State-Machine für CharacterVisual.
## Zustände: idle, walk, run, jump, fall, land, trick, emote.
## Jeder Zustand liefert eine Ziel-Pose (Gelenkwinkel); zwischen Posen wird weich überblendet.

enum State { IDLE, WALK, RUN, JUMP, FALL, LAND, TRICK, EMOTE }

@export var visual: CharacterVisual
var state: State = State.IDLE
var idle_style: StringName = &"chill"
var speed := 0.0 # horizontale Geschwindigkeit (m/s)

var _time := 0.0
var _state_time := 0.0
var _phase := 0.0 # Schrittphase
var _action: StringName = &"" # Trick- oder Emote-Animation
var _action_duration := 1.0
var _blend := 12.0
var _root_offset := Vector3.ZERO
var _root_rotation := Vector3.ZERO


func set_state(s: State) -> void:
	if s == state:
		return
	state = s
	_state_time = 0.0


## Trick- bzw. Emote-Animation abspielen. Liefert nichts; Ende über is_busy().
func play_action(animation_name: StringName, duration: float, is_emote := false) -> void:
	_action = animation_name
	_action_duration = maxf(0.2, duration)
	set_state(State.EMOTE if is_emote else State.TRICK)
	_state_time = 0.0


func is_busy() -> bool:
	return (state == State.TRICK or state == State.EMOTE) and _state_time < _action_duration


func action_progress() -> float:
	return clampf(_state_time / _action_duration, 0.0, 1.0)


func cancel_action() -> void:
	if state == State.TRICK or state == State.EMOTE:
		set_state(State.IDLE)


func _process(delta: float) -> void:
	if visual == null:
		return
	_time += delta
	_state_time += delta
	if state == State.LAND and _state_time > 0.18:
		set_state(State.IDLE)
	if (state == State.TRICK or state == State.EMOTE) and _state_time >= _action_duration:
		set_state(State.IDLE)
	_phase += delta * clampf(speed, 0.0, 12.0) * 1.6
	var pose := _pose()
	var k := minf(1.0, delta * _blend)
	# Gelenke ohne Angabe in der Pose gehen in die Grundstellung zurück
	for joint in visual.pivots:
		var p: Node3D = visual.pivots[joint]
		p.rotation = p.rotation.lerp(pose.get(joint, Vector3.ZERO), k)
	_root_offset = _root_offset.lerp(pose.get("root_pos", Vector3.ZERO), minf(1.0, delta * 18.0))
	# Drehungen bei Tricks direkt setzen (keine Überblendung, sonst „schwimmt“ die Drehung)
	var target_rot: Vector3 = pose.get("root_rot", Vector3.ZERO)
	_root_rotation = target_rot if state == State.TRICK else _root_rotation.lerp(target_rot, minf(1.0, delta * 10.0))
	visual.position = _root_offset
	visual.rotation = _root_rotation


## Ziel-Pose für den aktuellen Zustand.
func _pose() -> Dictionary:
	match state:
		State.WALK, State.RUN:
			return _locomotion(state == State.RUN)
		State.JUMP:
			return _jump(false)
		State.FALL:
			return _jump(true)
		State.LAND:
			return {"hips": Vector3(0, 0, 0), "torso": Vector3(-0.25, 0, 0), "knee_l": Vector3(0.7, 0, 0), "knee_r": Vector3(0.7, 0, 0), "leg_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.5, 0, 0), "root_pos": Vector3(0, -0.18, 0)}
		State.TRICK:
			return _trick(_action, action_progress())
		State.EMOTE:
			return _emote(_action, _state_time)
		_:
			return _idle()


func _idle() -> Dictionary:
	var breathe := sin(_time * 2.0) * 0.04
	var p := {"torso": Vector3(breathe, 0, 0), "head": Vector3(0, sin(_time * 0.5) * 0.25, 0),
		"arm_l": Vector3(0, 0, -0.08), "arm_r": Vector3(0, 0, 0.08), "elbow_l": Vector3(-0.15, 0, 0), "elbow_r": Vector3(-0.15, 0, 0),
		"leg_l": Vector3.ZERO, "leg_r": Vector3.ZERO, "knee_l": Vector3.ZERO, "knee_r": Vector3.ZERO}
	match idle_style:
		&"bounce":
			var b := absf(sin(_time * 4.0))
			p["root_pos"] = Vector3(0, -b * 0.06, 0)
			p["knee_l"] = Vector3(b * 0.3, 0, 0)
			p["knee_r"] = Vector3(b * 0.3, 0, 0)
			p["head"] = Vector3(b * 0.12, 0, 0)
		&"flex":
			p["arm_l"] = Vector3(0, 0, -1.5)
			p["arm_r"] = Vector3(0, 0, 1.5)
			p["elbow_l"] = Vector3(0, 0, -1.4 - sin(_time * 3.0) * 0.15)
			p["elbow_r"] = Vector3(0, 0, 1.4 + sin(_time * 3.0) * 0.15)
		_:
			p["arm_r"] = Vector3(-0.35, 0, 0.1) # Gadget locker in der Hand
			p["elbow_r"] = Vector3(-0.9, 0, 0)
	return p


func _locomotion(running: bool) -> Dictionary:
	var amp := 0.9 if running else 0.55
	var s := sin(_phase)
	var c := cos(_phase)
	return {
		"torso": Vector3(-0.18 if running else -0.05, 0, 0),
		"head": Vector3(0.1 if running else 0.0, 0, 0),
		"leg_l": Vector3(s * amp, 0, 0), "leg_r": Vector3(-s * amp, 0, 0),
		"knee_l": Vector3(maxf(0.0, -c) * amp * 1.3, 0, 0), "knee_r": Vector3(maxf(0.0, c) * amp * 1.3, 0, 0),
		"arm_l": Vector3(-s * amp * 0.8, 0, -0.1), "arm_r": Vector3(s * amp * 0.8, 0, 0.1),
		"elbow_l": Vector3(-0.4 - (0.6 if running else 0.0), 0, 0), "elbow_r": Vector3(-0.4 - (0.6 if running else 0.0), 0, 0),
		"root_pos": Vector3(0, absf(sin(_phase)) * (0.08 if running else 0.04), 0),
	}


func _jump(falling: bool) -> Dictionary:
	return {
		"torso": Vector3(0.1 if falling else -0.15, 0, 0),
		"leg_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(0.2 if falling else -0.3, 0, 0),
		"knee_l": Vector3(1.0, 0, 0), "knee_r": Vector3(0.6, 0, 0),
		"arm_l": Vector3(0, 0, -1.0 if falling else -2.4), "arm_r": Vector3(0, 0, 1.0 if falling else 2.4),
		"elbow_l": Vector3.ZERO, "elbow_r": Vector3.ZERO,
	}


## Trick-Animationen: t = Fortschritt 0..1
func _trick(anim: StringName, t: float) -> Dictionary:
	var e := t * t * (3.0 - 2.0 * t)
	var hop := sin(t * PI)
	var p := {"leg_l": Vector3.ZERO, "leg_r": Vector3.ZERO, "knee_l": Vector3.ZERO, "knee_r": Vector3.ZERO,
		"arm_l": Vector3(0, 0, -0.3), "arm_r": Vector3(0, 0, 0.3), "elbow_l": Vector3.ZERO, "elbow_r": Vector3.ZERO,
		"torso": Vector3.ZERO, "head": Vector3.ZERO}
	match anim:
		&"spin":
			p["root_rot"] = Vector3(0, e * TAU, 0)
			p["arm_l"] = Vector3(0, 0, -1.4)
			p["arm_r"] = Vector3(0, 0, 1.4)
		&"double_spin":
			p["root_rot"] = Vector3(0, e * TAU * 2.0, 0)
			p["root_pos"] = Vector3(0, hop * 0.6, 0)
			p["arm_l"] = Vector3(0, 0, -2.6)
			p["arm_r"] = Vector3(0, 0, 2.6)
		&"ultra_spin":
			p["root_rot"] = Vector3(0, e * TAU * 5.0, 0)
			p["root_pos"] = Vector3(0, hop * 1.4, 0)
			p["arm_l"] = Vector3(0, 0, -3.0)
			p["arm_r"] = Vector3(0, 0, 3.0)
			p["leg_l"] = Vector3(0, 0, -0.3)
			p["leg_r"] = Vector3(0, 0, 0.3)
		&"flip":
			p["arm_r"] = Vector3(-1.6, 0, 0.2)
			p["elbow_r"] = Vector3(-0.6 + sin(t * TAU * 3.0) * 0.6, 0, 0)
			p["head"] = Vector3(0.3, -0.3, 0)
		&"pose":
			p["arm_l"] = Vector3(0, 0, -2.4 * hop)
			p["arm_r"] = Vector3(-1.2 * hop, 0, 0.5)
			p["elbow_r"] = Vector3(-1.5 * hop, 0, 0)
			p["torso"] = Vector3(0, 0, 0.2 * hop)
			p["leg_l"] = Vector3(0, 0, -0.35 * hop)
			p["head"] = Vector3(-0.2 * hop, 0.4 * hop, 0)
		&"twist":
			var w := sin(t * TAU * 2.0)
			p["hips"] = Vector3(0, w * 0.6, 0)
			p["torso"] = Vector3(0, -w * 0.9, 0)
			p["arm_l"] = Vector3(-w * 0.8, 0, -0.6)
			p["arm_r"] = Vector3(w * 0.8, 0, 0.6)
			p["knee_l"] = Vector3(0.4, 0, 0)
			p["knee_r"] = Vector3(0.4, 0, 0)
		&"shadow":
			p["root_pos"] = Vector3(0, -0.7 * hop, 0)
			p["root_rot"] = Vector3(0, e * PI, 0)
			p["torso"] = Vector3(-0.8 * hop, 0, 0)
			p["knee_l"] = Vector3(1.8 * hop, 0, 0)
			p["knee_r"] = Vector3(1.8 * hop, 0, 0)
			p["leg_l"] = Vector3(-1.2 * hop, 0, 0)
			p["leg_r"] = Vector3(-1.2 * hop, 0, 0)
		&"neon_flip":
			p["root_rot"] = Vector3(-e * TAU, 0, 0)
			p["root_pos"] = Vector3(0, hop * 1.3 + hop * 0.6, 0)
			p["knee_l"] = Vector3(2.0 * hop, 0, 0)
			p["knee_r"] = Vector3(2.0 * hop, 0, 0)
			p["leg_l"] = Vector3(-1.6 * hop, 0, 0)
			p["leg_r"] = Vector3(-1.6 * hop, 0, 0)
		&"air_pose":
			p["root_pos"] = Vector3(0, hop * 1.6, 0)
			p["leg_l"] = Vector3(-1.4 * hop, 0, 0)
			p["leg_r"] = Vector3(0.6 * hop, 0, 0)
			p["arm_l"] = Vector3(0, 0, -2.8 * hop)
			p["arm_r"] = Vector3(0, 0, 1.2 * hop)
			p["head"] = Vector3(-0.4 * hop, 0, 0)
		&"phantom":
			var steps := floorf(t * 3.0)
			p["root_rot"] = Vector3(0, steps * TAU / 3.0 + e * 0.5, 0)
			p["root_pos"] = Vector3(sin(t * TAU * 1.5) * 0.4, hop * 0.4, 0)
			p["arm_l"] = Vector3(-1.2, 0, -1.0)
			p["arm_r"] = Vector3(-1.2, 0, 1.0)
		&"cosmic":
			p["root_pos"] = Vector3(0, hop * 2.2, 0)
			p["root_rot"] = Vector3(0, e * TAU, 0)
			p["arm_l"] = Vector3(0, 0, -2.0 * hop)
			p["arm_r"] = Vector3(0, 0, 2.0 * hop)
			p["leg_l"] = Vector3(0, 0, -0.5 * hop)
			p["leg_r"] = Vector3(0, 0, 0.5 * hop)
			p["head"] = Vector3(-0.6 * hop, 0, 0)
		&"explosion":
			var crouch := clampf(t / 0.4, 0.0, 1.0)
			var burst := clampf((t - 0.4) / 0.25, 0.0, 1.0)
			p["root_pos"] = Vector3(0, -0.35 * crouch * (1.0 - burst) + burst * 0.8 * (1.0 - t), 0)
			p["knee_l"] = Vector3(1.4 * crouch * (1.0 - burst), 0, 0)
			p["knee_r"] = Vector3(1.4 * crouch * (1.0 - burst), 0, 0)
			p["leg_l"] = Vector3(-0.8 * crouch * (1.0 - burst), 0, -0.4 * burst)
			p["leg_r"] = Vector3(-0.8 * crouch * (1.0 - burst), 0, 0.4 * burst)
			p["arm_l"] = Vector3(0, 0, -0.4 - 2.6 * burst)
			p["arm_r"] = Vector3(0, 0, 0.4 + 2.6 * burst)
			p["torso"] = Vector3(-0.6 * crouch * (1.0 - burst), 0, 0)
	return p


func _emote(anim: StringName, time: float) -> Dictionary:
	var p := _idle()
	match anim:
		&"wave":
			p["arm_r"] = Vector3(0, 0, 2.6)
			p["elbow_r"] = Vector3(0, 0, sin(time * 10.0) * 0.6)
		&"dance":
			var b := sin(time * 8.0)
			p["root_pos"] = Vector3(b * 0.08, absf(b) * 0.1, 0)
			p["hips"] = Vector3(0, b * 0.4, 0)
			p["arm_l"] = Vector3(b * 1.2, 0, -1.0)
			p["arm_r"] = Vector3(-b * 1.2, 0, 1.0)
			p["knee_l"] = Vector3(maxf(0.0, b) * 0.8, 0, 0)
			p["knee_r"] = Vector3(maxf(0.0, -b) * 0.8, 0, 0)
		&"dab":
			p["arm_l"] = Vector3(0, 0, -2.3)
			p["arm_r"] = Vector3(-1.0, 0, -0.9)
			p["elbow_r"] = Vector3(0, 0, -2.2)
			p["head"] = Vector3(0.6, -0.4, 0.3)
		&"flex":
			p["arm_l"] = Vector3(0, 0, -1.5)
			p["arm_r"] = Vector3(0, 0, 1.5)
			p["elbow_l"] = Vector3(0, 0, -1.7)
			p["elbow_r"] = Vector3(0, 0, 1.7)
			p["torso"] = Vector3(-0.15, 0, 0)
	return p

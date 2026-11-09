class_name CharacterAnimator
extends Node
## Animations-State-Machine für CharacterVisual: echte (retargetete) Animationen mit Überblendung,
## dazu prozedurale Drehungen/Sprünge/Salti für Tricks über den Pose-Knoten.

enum State { IDLE, WALK, RUN, JUMP, FALL, LAND, TRICK, EMOTE }

## Aktion: [Animation, Startanteil, Drehungen (Y), Höhe (m), Salti (X)]
const ACTIONS := {
	&"spin": ["ual/Dance", 0.25, 1.0, 0.15, 0.0],
	&"flip": ["ual/Interact", 0.0, 0.0, 0.0, 0.0],
	&"pose": ["CharacterArmature|Victory", 0.0, 0.0, 0.0, 0.0],
	&"twist": ["ual/Punch_Cross", 0.0, 0.5, 0.0, 0.0],
	&"double_spin": ["ual/Dance", 0.4, 2.0, 0.35, 0.0],
	&"shadow": ["ual/Crouch_Fwd", 0.0, 0.0, 0.0, 0.0],
	&"neon_flip": ["ual/Jump", 0.15, 0.0, 1.3, -1.0],
	&"air_pose": ["CharacterArmature|Victory", 0.0, 0.0, 1.5, 0.0],
	&"phantom": ["ual/Punch_Jab", 0.0, 1.0, 0.3, 0.0],
	&"ultra_spin": ["ual/Spell_Simple_Idle", 0.0, 5.0, 0.9, 0.0],
	&"cosmic": ["ual/Spell_Simple_Enter", 0.0, 0.5, 1.9, 0.0],
	&"explosion": ["ual/Spell_Simple_Shoot", 0.0, 1.0, 1.2, 0.0],
	# Emotes
	&"wave": ["ual/Idle_Talking", 0.0, 0.0, 0.0, 0.0],
	&"dance": ["ual/Dance", 0.0, 0.0, 0.0, 0.0],
	&"flex": ["CharacterArmature|Victory", 0.0, 0.0, 0.0, 0.0],
	&"dab": ["ual/Punch_Cross", 0.2, 0.0, 0.0, 0.0],
	&"cheer": ["CharacterArmature|Victory", 0.0, 0.0, 0.0, 0.0],
	&"sit": ["ual/Sitting_Idle", 0.0, 0.0, 0.0, 0.0],
}
const IDLES := {&"chill": "ual/Idle", &"bounce": "CharacterArmature|Idle", &"flex": "ual/Sword_Idle"}
const LOOPING := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Jump", "Crouch_Idle", "Crouch_Fwd", "Dance", "Idle_Talking",
	"Sword_Idle", "Spell_Simple_Idle", "Sitting_Idle", "Swim_Fwd", "Swim_Idle", "Walk_Formal", "Pistol_Idle", "Driving"]

static var _loops_set := false

@export var visual: CharacterVisual
var state: State = State.IDLE
var idle_style: StringName = &"chill"
var speed := 0.0
## Auf dem Hoverboard: Surf-Haltung (seitlich, leicht in die Knie)
var boarding := false

var _state_time := 0.0
var _action: StringName = &""
var _action_duration := 1.0
var _current := ""
var _player: AnimationPlayer


func _ready() -> void:
	if not _loops_set:
		_loops_set = true
		for a in LOOPING:
			if CharacterVisual.ANIMS.has_animation(a):
				CharacterVisual.ANIMS.get_animation(a).loop_mode = Animation.LOOP_LINEAR


func set_state(s: State) -> void:
	if s == state:
		return
	state = s
	_state_time = 0.0


func play_action(animation_name: StringName, duration: float, is_emote := false) -> void:
	_action = animation_name
	_action_duration = maxf(0.2, duration)
	state = State.EMOTE if is_emote else State.TRICK
	_state_time = 0.0
	var spec: Array = ACTIONS.get(animation_name, ACTIONS[&"pose"])
	_play(spec[0], 0.1)
	if _player and _player.current_animation != "":
		var length := _player.current_animation_length
		_player.seek(length * float(spec[1]), true)
		# Trick-Animation in die Trick-Dauer einpassen (Emotes laufen normal)
		_player.speed_scale = 1.0 if is_emote else clampf(length * (1.0 - float(spec[1])) / _action_duration, 0.6, 2.5)


func is_busy() -> bool:
	return (state == State.TRICK or state == State.EMOTE) and _state_time < _action_duration


func action_progress() -> float:
	return clampf(_state_time / _action_duration, 0.0, 1.0)


func cancel_action() -> void:
	if state == State.TRICK or state == State.EMOTE:
		set_state(State.IDLE)


func _play(anim_name: String, blend := 0.18) -> void:
	if _player == null or not _player.has_animation(anim_name):
		return
	if anim_name != _current:
		_current = anim_name
		_player.play(anim_name, blend)


func _process(delta: float) -> void:
	if visual == null or visual.anim == null:
		return
	if visual.anim != _player:
		_player = visual.anim # Modell wurde gewechselt (Outfit)
		_current = ""
	_state_time += delta
	if state == State.LAND and _state_time > 0.25:
		set_state(State.IDLE)
	if (state == State.TRICK or state == State.EMOTE) and _state_time >= _action_duration:
		set_state(State.IDLE)
	var p := visual.pose
	match state:
		State.TRICK, State.EMOTE:
			var spec: Array = ACTIONS.get(_action, ACTIONS[&"pose"])
			var t := action_progress()
			var e := t * t * (3.0 - 2.0 * t)
			p.position = Vector3(0, float(spec[3]) * sin(t * PI), 0)
			p.rotation = Vector3(float(spec[4]) * TAU * e, float(spec[2]) * TAU * e, 0)
			return
		State.IDLE, State.WALK, State.RUN when boarding:
			_player.speed_scale = 1.0
			_play("ual/Crouch_Idle")
		State.IDLE:
			_player.speed_scale = 1.0
			_play(IDLES.get(idle_style, "ual/Idle"))
		State.WALK:
			_play("ual/Walk")
			_player.speed_scale = clampf(speed / 1.7, 0.6, 2.2)
		State.RUN:
			if speed > 7.0:
				_play("ual/Sprint")
				_player.speed_scale = clampf(speed / 7.5, 0.8, 1.5)
			else:
				_play("ual/Jog_Fwd")
				_player.speed_scale = clampf(speed / 4.2, 0.8, 1.6)
		State.JUMP:
			_player.speed_scale = 1.0
			_play("ual/Jump_Start" if _state_time < 0.25 else "ual/Jump", 0.1)
		State.FALL:
			_player.speed_scale = 1.0
			_play("ual/Jump", 0.15)
		State.LAND:
			_player.speed_scale = 1.4
			_play("ual/Jump_Land", 0.08)
	# Trick-Transform weich zurücksetzen (bzw. in die Surf-Haltung auf dem Board)
	var goal_pos := Vector3(0, 0.17, 0) if boarding else Vector3.ZERO
	var goal_rot := Vector3(0, PI * 0.42, 0) if boarding else Vector3.ZERO
	p.position = p.position.lerp(goal_pos, minf(1.0, delta * 12.0))
	var r := Vector3(wrapf(p.rotation.x, -PI, PI), wrapf(p.rotation.y, -PI, PI), 0)
	p.rotation = r.lerp(goal_rot, minf(1.0, delta * 12.0))

class_name Npc
extends CharacterBody3D
## Stadtbewohner mit echter Figur (Quaternius-Modelle) und Animationen.
##  - schlendert im Distrikt umher oder patrouilliert als Passant zwischen zwei Punkten
##  - schaut den Spieler beim Reden an, jubelt bei Perfect-Tricks in der Nähe
##  - manche haben ein Gadget und machen selbst ab und zu einen (kosmetischen) Wolken-Trick
##  - weit entfernt: Physik und Animation pausieren (große Map, viele NPCs)

const MODELS := {
	&"default": ["Casual_Male", "Casual_Female", "Casual2_Male", "Casual2_Female", "Casual3_Male", "Casual3_Female", "Casual_Bald"],
	&"business": ["Suit_Male", "Suit_Female", "OldClassy_Male", "OldClassy_Female", "Doctor_Male_Old", "Doctor_Female_Young"],
	&"harbor": ["Pirate_Male", "Pirate_Female", "Worker_Male", "Worker_Female", "Casual_Bald"],
	&"street": ["Ninja_Male", "Casual2_Male", "Casual3_Female", "Kimono_Female", "Kimono_Male", "Cowboy_Male"],
	&"work": ["Worker_Male", "Worker_Female", "Chef_Male", "Chef_Female"],
}
const REACTIONS := ["W!", "Sheesh!", "Aura +1000", "Krass!", "Main Character!", "Wie?!", "Legendär!"]
const ACTIVE_DISTANCE := 75.0

@export var npc_name := "Passant"
@export var lines: PackedStringArray = ["Schöner Tag, oder?"]
@export var wander_center := Vector3.ZERO
@export var wander_radius := 12.0
@export var walk_speed := 1.5
@export var style: StringName = &"default"
## Passant: läuft zwischen patrol_a und patrol_b hin und her (wenn gesetzt)
@export var patrol_a := Vector3.INF
@export var patrol_b := Vector3.INF

var visual: CharacterVisual
var animator: CharacterAnimator
var has_gadget := false
var _target := Vector3.ZERO
var _wait := 0.0
var _talk: InfoSign
var _bubble: Label3D
var _bubble_left := 0.0
var _trick_timer := 0.0
var _lod_timer := 0.0
var _active := true
var _patrol_to_b := true
var _rng := RandomNumberGenerator.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	_rng.seed = hash(npc_name + str(wander_center) + str(patrol_a))
	collision_layer = 4
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	visual = CharacterVisual.new()
	add_child(visual)
	var pool: Array = MODELS.get(style, MODELS[&"default"])
	visual.apply_npc(pool[_rng.randi() % pool.size()], _rng)
	has_gadget = _rng.randf() < 0.75
	if has_gadget:
		var gadgets := ItemDB.by_category(&"gadget")
		visual._build_gadget(gadgets[_rng.randi() % gadgets.size()])
	animator = CharacterAnimator.new()
	animator.visual = visual
	animator.idle_style = [&"chill", &"bounce"][_rng.randi() % 2]
	add_child(animator)
	var name_label := Label3D.new()
	name_label.text = npc_name
	name_label.font_size = 40
	name_label.pixel_size = 0.005
	name_label.outline_size = 10
	name_label.position = Vector3(0, 2.15, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.modulate = Color(1, 1, 1, 0.8)
	name_label.visibility_range_end = 25.0
	name_label.set_meta(&"keep_range", true)
	add_child(name_label)
	_bubble = Label3D.new()
	_bubble.font_size = 56
	_bubble.pixel_size = 0.006
	_bubble.outline_size = 14
	_bubble.position = Vector3(0, 2.5, 0)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.modulate = Color("facc15")
	_bubble.visible = false
	add_child(_bubble)
	_talk = InfoSign.new()
	_talk.speaker = npc_name
	_talk.lines = lines
	_talk.prompt = "Mit %s reden" % npc_name
	add_child(_talk)
	_trick_timer = _rng.randf_range(6.0, 30.0)
	_pick_target()
	Events.trick_landed.connect(_on_trick)


func _is_patrol() -> bool:
	return patrol_a != Vector3.INF and patrol_b != Vector3.INF


func _pick_target() -> void:
	if _is_patrol():
		_patrol_to_b = not _patrol_to_b
		_target = patrol_b if _patrol_to_b else patrol_a
		_wait = _rng.randf_range(0.5, 3.0)
		return
	var a := _rng.randf() * TAU
	var r := _rng.randf() * wander_radius
	_target = wander_center + Vector3(cos(a) * r, 0, sin(a) * r)
	_wait = _rng.randf_range(1.0, 5.0)


func _set_active(on: bool) -> void:
	_active = on
	visual.visible = on
	if visual.anim:
		visual.anim.active = on
	animator.set_process(on)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = 0.5
		var near := player == null or player.global_position.distance_to(global_position) < ACTIVE_DISTANCE
		if near != _active:
			_set_active(near)
	if not _active:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var near_player := player != null and player.global_position.distance_to(global_position) < 3.0
	var to := _target - global_position
	to.y = 0
	var moving := false
	if animator.is_busy():
		velocity.x = 0
		velocity.z = 0
	elif near_player:
		var d := player.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), minf(1.0, delta * 5.0))
		velocity.x = 0
		velocity.z = 0
	elif _wait > 0.0:
		_wait -= delta
		velocity.x = 0
		velocity.z = 0
	elif to.length() < 0.6:
		_pick_target()
	else:
		var dir := to.normalized()
		velocity.x = dir.x * walk_speed
		velocity.z = dir.z * walk_speed
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 6.0))
		moving = true
	move_and_slide()
	if is_on_wall() and moving:
		_pick_target()
	if not animator.is_busy():
		animator.speed = Vector2(velocity.x, velocity.z).length()
		animator.set_state(CharacterAnimator.State.WALK if moving else CharacterAnimator.State.IDLE)
	# Eigener Wolken-Trick (nur wenn der Spieler es sehen kann)
	_trick_timer -= delta
	if has_gadget and _trick_timer <= 0.0 and player and player.global_position.distance_to(global_position) < 35.0:
		_trick_timer = _rng.randf_range(8.0, 25.0)
		_do_trick()
	if _bubble_left > 0.0:
		_bubble_left -= delta
		_bubble.visible = _bubble_left > 0.0


func _do_trick() -> void:
	# NPC dampft: meist eine normale Wolke, manchmal Ringe oder ein Ghost
	if not animator.is_busy():
		animator.play_action(&"exhale", 1.2)
	var color := Color.from_hsv(_rng.randf(), 0.35, 1.0)
	var fwd := -global_transform.basis.z
	var shape: StringName = [&"puff", &"puff", &"puff", &"rings", &"ghost", &"waterfall"][_rng.randi() % 6]
	FX.vape_cloud(get_parent(), visual.mouth_position(fwd), fwd, color, shape, 1, 0.8)


func _on_trick(_id: StringName, quality: StringName, _aura: float, _combo: int) -> void:
	if not _active:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or player.global_position.distance_to(global_position) > 10.0 or _rng.randf() > 0.5:
		return
	_bubble.text = REACTIONS[_rng.randi() % REACTIONS.size()] if quality == &"perfect" or _rng.randf() < 0.5 else "Nice!"
	_bubble_left = 1.8
	_bubble.visible = true
	if not animator.is_busy() and _rng.randf() < 0.5:
		animator.play_action(&"cheer" if quality == &"perfect" else &"wave", 1.6, true)

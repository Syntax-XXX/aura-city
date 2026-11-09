class_name Npc
extends CharacterBody3D
## Einfacher Stadtbewohner: läuft zu zufälligen Punkten im Distrikt, macht Pausen,
## schaut den Spieler beim Reden an und reagiert auf Tricks in der Nähe.

@export var npc_name := "Passant"
@export var lines: PackedStringArray = ["Schöner Tag, oder?"]
@export var wander_center := Vector3.ZERO
@export var wander_radius := 12.0
@export var walk_speed := 1.6

var visual: CharacterVisual
var animator: CharacterAnimator
var _target := Vector3.ZERO
var _wait := 0.0
var _talk: InfoSign
var _bubble: Label3D
var _bubble_left := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
const REACTIONS := ["W!", "Sheesh!", "Aura +1000", "Krass!", "Main Character!", "Wie?!"]


func _ready() -> void:
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
	visual.apply_look(_random_look())
	animator = CharacterAnimator.new()
	animator.visual = visual
	animator.idle_style = [&"chill", &"bounce"].pick_random()
	add_child(animator)
	var name_label := Label3D.new()
	name_label.text = npc_name
	name_label.font_size = 40
	name_label.pixel_size = 0.005
	name_label.outline_size = 10
	name_label.position = Vector3(0, 2.25, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.modulate = Color(1, 1, 1, 0.8)
	add_child(name_label)
	_bubble = Label3D.new()
	_bubble.font_size = 56
	_bubble.pixel_size = 0.006
	_bubble.outline_size = 14
	_bubble.position = Vector3(0, 2.65, 0)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.modulate = Color("facc15")
	_bubble.visible = false
	add_child(_bubble)
	_talk = InfoSign.new()
	_talk.speaker = npc_name
	_talk.lines = lines
	_talk.prompt = "Mit %s reden" % npc_name
	add_child(_talk)
	_pick_target()
	Events.trick_landed.connect(_on_trick)


## Zufällige Kosmetik aus den günstigeren Items.
func _random_look() -> Dictionary:
	var look := {}
	for slot in [&"skin", &"hair", &"outfit", &"shoes", &"accessory", &"gadget"]:
		var pool: Array = ItemDB.all().filter(func(i: ItemDef) -> bool: return i.slot() == slot and i.rarity <= ItemDef.Rarity.RARE)
		if not pool.is_empty() and (slot != &"accessory" or randf() < 0.5):
			look[slot] = pool.pick_random()
	return look


func _pick_target() -> void:
	var a := randf() * TAU
	var r := randf() * wander_radius
	_target = wander_center + Vector3(cos(a) * r, 0, sin(a) * r)
	_wait = randf_range(1.0, 4.0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var near_player := player != null and player.global_position.distance_to(global_position) < 3.0
	var to := _target - global_position
	to.y = 0
	var moving := false
	if near_player:
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
	if _bubble_left > 0.0:
		_bubble_left -= delta
		_bubble.visible = _bubble_left > 0.0


func _on_trick(_id: StringName, quality: StringName, _aura: float, _combo: int) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or player.global_position.distance_to(global_position) > 10.0 or randf() > 0.5:
		return
	_bubble.text = REACTIONS.pick_random() if quality == &"perfect" or randf() < 0.5 else "Nice!"
	_bubble_left = 1.8
	_bubble.visible = true
	if randf() < 0.4:
		animator.play_action(&"wave", 1.5, true)

class_name ChallengeZone
extends Interactable
## Skill-Challenge: in der Zeit ein Ziel erreichen.
##  perfects – N Perfect-Landungen
##  combo    – Combo von N Tricks
##  score    – N Aura verdienen
## Während der Challenge gibt es ×1.5 Aura auf Tricks.

@export var challenge_name := "Challenge"
@export_enum("perfects", "combo", "score") var kind := "perfects"
@export var goal := 3
@export var seconds := 30.0
@export var reward := 500
@export var color := Color("22d3ee")

var _active := false
var _left := 0.0
var _progress := 0
var _player: PlayerController
var _ring: MeshInstance3D


func _ready() -> void:
	super._ready()
	prompt = "Challenge starten: " + challenge_name
	var torus := TorusMesh.new()
	torus.inner_radius = 2.2
	torus.outer_radius = 2.5
	torus.rings = 48
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = CharacterVisual.make_material(color, 0.3, 0.0, 2.0)
	_ring.position.y = 0.05
	add_child(_ring)
	var label := Label3D.new()
	label.text = "%s\n%s" % [challenge_name, describe()]
	label.font_size = 64
	label.pixel_size = 0.008
	label.outline_size = 14
	label.modulate = color
	label.position = Vector3(0, 3.0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	Events.trick_landed.connect(_on_trick)
	Events.aura_changed.connect(_on_aura)


func describe() -> String:
	match kind:
		"combo": return "%d-er Combo in %d s · +%d Aura" % [goal, seconds, reward]
		"score": return "%d Aura in %d s · +%d Aura" % [goal, seconds, reward]
		_: return "%d Perfects in %d s · +%d Aura" % [goal, seconds, reward]


func is_available() -> bool:
	return not _active


func interact(player: Node3D) -> void:
	_player = player as PlayerController
	_active = true
	_left = seconds
	_progress = 0
	if _player:
		_player.tricks.challenge_multiplier = 1.5
	Audio.play(&"open")
	Events.challenge_started.emit(challenge_name)


func _process(delta: float) -> void:
	_ring.rotation.y += delta * (2.0 if _active else 0.4)
	if not _active:
		return
	_left -= delta
	Events.challenge_status.emit("%s: %d/%d · %.0f s" % [challenge_name, _progress, goal, maxf(0.0, _left)])
	if _progress >= goal:
		_finish(true)
	elif _left <= 0.0:
		_finish(false)


func _on_trick(_id: StringName, quality: StringName, _aura: float, combo: int) -> void:
	if not _active:
		return
	match kind:
		"perfects":
			if quality == &"perfect":
				_progress += 1
		"combo":
			_progress = maxi(_progress, combo)


func _on_aura(_current: float, delta: float) -> void:
	if _active and kind == "score" and delta > 0.0:
		_progress += int(delta)


func _finish(success: bool) -> void:
	_active = false
	if _player:
		_player.tricks.challenge_multiplier = 1.0
	Events.challenge_status.emit("")
	if success:
		Audio.play(&"reward")
		FX.ring(get_parent(), global_position + Vector3.UP * 0.3, color, 4.0)
		Economy.earn(reward, "Challenge: " + challenge_name, global_position + Vector3.UP * 2.5)
		Events.challenge_completed.emit(challenge_name, reward)
		Events.toast.emit("Challenge geschafft: %s!" % challenge_name, Color("4ade80"))
	else:
		Audio.play(&"fail")
		Events.challenge_failed.emit(challenge_name)
		Events.toast.emit("Challenge verpasst – probier's nochmal", Color("fca5a5"))

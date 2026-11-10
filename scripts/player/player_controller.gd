class_name PlayerController
extends CharacterBody3D
## Ego-Steuerung (V = Third-Person) mit sanfter Beschleunigung, Coyote-Time, Sprung-Puffer und Landeerkennung.
## Hält Figur, Animator, Kamera, Trick-System, Interaktion und kosmetische Effekte zusammen.

@export_group("Bewegung")
@export var walk_speed := 4.6
@export var run_speed := 8.4
@export var acceleration := 22.0
@export var deceleration := 26.0
@export var air_control := 0.45
@export var jump_velocity := 7.2
@export var gravity_scale := 1.7
@export var turn_speed := 12.0
@export var coyote_time := 0.12
@export var jump_buffer := 0.15
@export var interact_radius := 2.6

var visual: CharacterVisual
var animator: CharacterAnimator
var camera_rig: CameraRig
var tricks: TrickSystem
var input_enabled := true

var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _step_timer := 0.0
var _rank_label: Label3D
var _trail: CPUParticles3D
var _aura_fx: CPUParticles3D
var _nearest: Interactable
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
## Hoverboard: Fortbewegung auf der großen Map, Tempo je nach Board-Stufe
const BOARD_SPEEDS := {&"street": 12.0, &"neon": 15.0, &"cloud": 17.0, &"jet": 20.0, &"aurora": 23.0, &"void": 25.0}
var boarding := false
var _board: Node3D
var fp_vape: FpVape


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = 2
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
	animator = CharacterAnimator.new()
	animator.visual = visual
	add_child(animator)
	camera_rig = CameraRig.new()
	camera_rig.target = self
	add_child(camera_rig)
	tricks = TrickSystem.new()
	tricks.animator = animator
	tricks.visual = visual
	tricks.player = self
	tricks.camera_rig = camera_rig
	add_child(tricks)
	fp_vape = FpVape.new()
	fp_vape.tricks = tricks
	camera_rig.camera.add_child(fp_vape)
	_rank_label = Label3D.new()
	_rank_label.position = Vector3(0, 2.35, 0)
	_rank_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rank_label.font_size = 54
	_rank_label.outline_size = 14
	_rank_label.pixel_size = 0.005
	_rank_label.no_depth_test = true
	add_child(_rank_label)
	_trail = _make_emitter(0.6, 40)
	_trail.position = Vector3(0, 0.15, 0)
	_aura_fx = _make_emitter(1.6, 24)
	_aura_fx.position = Vector3(0, 1.0, 0)
	_aura_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_aura_fx.emission_sphere_radius = 0.8
	Events.item_equipped.connect(func(_s, _i): refresh_look())
	Events.rank_changed.connect(func(_r): refresh_look())
	Events.settings_changed.connect(_on_settings_changed)
	refresh_look()


func _make_emitter(lifetime: float, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.18
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	p.spread = 30.0
	p.direction = Vector3.UP
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.3, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	add_child(p)
	return p


func _on_settings_changed() -> void:
	if visual.body_type != Settings.avatar_body:
		refresh_look()


## Ausrüstung + Rang auf die Figur übertragen.
func refresh_look() -> void:
	var look := {}
	for slot in Inventory.SLOTS:
		look[slot] = Inventory.equipped_item(slot)
	visual.body_type = Settings.avatar_body
	visual.apply_look(look)
	var idle: ItemDef = look.get(&"animation")
	animator.idle_style = idle.variant if idle else &"chill"
	var trail: ItemDef = look.get(&"trail")
	_trail.emitting = false
	if trail:
		_trail.color = trail.color
		if trail.variant == &"rainbow":
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
			g.colors = PackedColorArray([Color("ef4444"), Color("facc15"), Color("22d3ee"), Color(0.66, 0.33, 0.97, 0)])
			_trail.color_ramp = g
	var fx: ItemDef = look.get(&"particle")
	_aura_fx.emitting = fx != null
	if fx:
		_aura_fx.color = fx.color
	var title: ItemDef = look.get(&"title")
	var rank_color := Economy.rank_color()
	_rank_label.text = "%s\n%s" % [Economy.rank_name(), title.display_name if title else ""]
	_rank_label.modulate = rank_color
	_rank_label.outline_modulate = Color(0, 0, 0, 0.85).lerp(rank_color.darkened(0.6), float(Economy.RANKS[Economy.rank_index]["glow"]))
	_trail.set_meta("has_trail", trail != null)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rig.rotate_by_mouse(motion.relative)
		return
	if event.is_action_pressed("jump"):
		_jump_buffer = jump_buffer
	elif event.is_action_pressed("vape"):
		var err := tricks.start_inhale()
		if err != "" and err != "Beschäftigt":
			Events.toast.emit(err, Color("fca5a5"))
	elif event.is_action_released("vape"):
		tricks.release()
	elif event.is_action_pressed("mouse_capture") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not TouchControls.wanted():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("toggle_view"):
		camera_rig.set_first_person(not camera_rig.first_person)
	elif event.is_action_pressed("interact") and _nearest:
		_nearest.interact(self)
	elif event.is_action_pressed("hoverboard"):
		toggle_board()
	elif event.is_action_pressed("emote") and not boarding:
		var emote: ItemDef = Inventory.equipped_item(&"emote")
		if emote and not tricks.is_busy():
			animator.play_action(emote.variant, 2.4, true)
	else:
		for k in ["up", "down", "left", "right"]:
			if event.is_action_pressed("combo_" + k):
				tricks.push_key(k[0].to_upper())
				break


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	_coyote = coyote_time if on_floor else _coyote - delta
	_jump_buffer -= delta
	if not on_floor:
		velocity.y -= _gravity * gravity_scale * delta
		_fall_speed = minf(_fall_speed, velocity.y)
	# Eingabe relativ zur Kamera
	var input_vec := Vector2.ZERO
	if input_enabled:
		input_vec = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var forward := camera_rig.forward_flat()
	var right := Vector3(-forward.z, 0, forward.x)
	var wish := (forward * input_vec.y + right * input_vec.x)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var busy := animator.is_busy() and animator.state == CharacterAnimator.State.TRICK
	var sprinting := input_enabled and Input.is_action_pressed("sprint") and wish.length() > 0.1 and not busy
	var target_speed := (run_speed if sprinting else walk_speed) * (0.35 if busy else 1.0) * Economy.boost("speed")
	var accel := (acceleration if wish.length() > 0.05 else deceleration) * (1.0 if on_floor else air_control)
	if boarding:
		target_speed = board_speed() * (1.25 if Input.is_action_pressed("sprint") else 1.0) * Economy.boost("speed")
		accel = (11.0 if wish.length() > 0.05 else 4.0) * (1.0 if on_floor else 0.6)
	var target := wish * target_speed
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(target, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	# Springen (mit Coyote-Time und Sprung-Puffer)
	if _jump_buffer > 0.0 and _coyote > 0.0 and not busy:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		animator.set_state(CharacterAnimator.State.JUMP)
	move_and_slide()
	# Ego: Figur schaut immer in Blickrichtung; sonst in Laufrichtung drehen
	if camera_rig.first_person:
		rotation.y = camera_rig.yaw
	elif horizontal.length() > 0.3 and not busy:
		var target_yaw := atan2(-horizontal.x, -horizontal.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * turn_speed))
	camera_rig.set_sprint(sprinting or (boarding and horizontal.length() > 10.0))
	_update_animation(on_floor, horizontal.length(), delta)
	_was_on_floor = is_on_floor()
	_trail.emitting = (bool(_trail.get_meta("has_trail", false)) or boarding) and horizontal.length() > 2.0
	_update_interaction()
	_apply_view()
	# Aus der Welt gefallen → zurück zum Spawn
	if global_position.y < -60.0 and global_position.y > -150.0:
		teleport(Vector3(0, 2, 8))


func _update_animation(on_floor: bool, speed: float, delta: float) -> void:
	animator.speed = speed
	if animator.state == CharacterAnimator.State.TRICK or animator.state == CharacterAnimator.State.EMOTE:
		if animator.state == CharacterAnimator.State.EMOTE and speed > 0.5:
			animator.cancel_action()
		return
	if on_floor and not _was_on_floor:
		if _fall_speed < -5.0:
			animator.set_state(CharacterAnimator.State.LAND)
			Audio.play(&"step", 0.7)
		_fall_speed = 0.0
	if not on_floor:
		animator.set_state(CharacterAnimator.State.JUMP if velocity.y > 0.0 else CharacterAnimator.State.FALL)
	elif animator.state != CharacterAnimator.State.LAND:
		if speed > walk_speed + 0.5:
			animator.set_state(CharacterAnimator.State.RUN)
		elif speed > 0.4:
			animator.set_state(CharacterAnimator.State.WALK)
		else:
			animator.set_state(CharacterAnimator.State.IDLE)
	if on_floor and speed > 0.5:
		_step_timer -= delta * speed
		if _step_timer <= 0.0:
			_step_timer = 2.2
			Audio.play(&"step", randf_range(0.9, 1.2))


func _update_interaction() -> void:
	var best: Interactable = null
	var best_d := interact_radius
	for n in get_tree().get_nodes_in_group(&"interactables"):
		var it := n as Interactable
		if it == null or not it.is_available():
			continue
		var d := it.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = it
	if best != _nearest:
		_nearest = best
		Events.interaction_prompt.emit(best.prompt_text() if best else "")


func board_speed() -> float:
	var item: ItemDef = Inventory.equipped_item(&"board")
	return BOARD_SPEEDS.get(item.variant if item else &"street", 12.0)


## Auf- bzw. absteigen.
func toggle_board() -> void:
	if boarding:
		boarding = false
		animator.boarding = false
		if _board:
			_board.queue_free()
			_board = null
		Audio.play(&"close")
		return
	if tricks.is_busy() or not is_on_floor():
		return
	boarding = true
	animator.boarding = true
	_board = _make_board(Inventory.equipped_item(&"board"))
	# Board hängt am Pose-Knoten → dreht sich bei Board-Tricks mit; Gegendrehung zur Surf-Haltung
	visual.pose.add_child(_board)
	_board.rotation.y = -CharacterAnimator.SURF_YAW
	_board.position.y = -CharacterAnimator.SURF_LIFT
	Audio.play(&"teleport", 1.4)
	FX.ring(get_parent(), global_position + Vector3.UP * 0.1, _board.get_meta(&"glow"), 1.5)


func _make_board(item: ItemDef) -> Node3D:
	var root := Node3D.new()
	var base := item.color if item else Color("64748b")
	var glow := item.accent_color if item else Color("22d3ee")
	root.set_meta(&"glow", glow)
	var deck := BoxMesh.new()
	deck.size = Vector3(0.55, 0.07, 1.55)
	var d := MeshInstance3D.new()
	d.mesh = deck
	d.material_override = CharacterVisual.make_material(base, 0.35, 0.4)
	d.position = Vector3(0, 0.12, 0)
	root.add_child(d)
	for z: float in [-0.55, 0.55]:
		var pad := CylinderMesh.new()
		pad.top_radius = 0.16
		pad.bottom_radius = 0.2
		pad.height = 0.05
		var mi := MeshInstance3D.new()
		mi.mesh = pad
		mi.material_override = CharacterVisual.make_material(glow, 0.2, 0.0, 3.0)
		mi.position = Vector3(0, 0.06, z)
		root.add_child(mi)
	var rail := BoxMesh.new()
	rail.size = Vector3(0.58, 0.02, 1.58)
	var r := MeshInstance3D.new()
	r.mesh = rail
	r.material_override = CharacterVisual.make_material(glow, 0.3, 0.0, 1.6)
	r.position = Vector3(0, 0.155, 0)
	root.add_child(r)
	return root


## Ego-Perspektive: eigene Figur und Namensschild aus, Vape in der Hand an (Board bleibt sichtbar).
func _apply_view() -> void:
	var fp := camera_rig.first_person
	if visual.model and visual.model.visible == fp:
		visual.model.visible = not fp
	_rank_label.visible = not fp
	fp_vape.visible = fp and not boarding


func teleport(target_pos: Vector3) -> void:
	global_position = target_pos
	velocity = Vector3.ZERO
	camera_rig.global_position = target_pos + Vector3.UP * camera_rig.height


func yaw() -> float:
	return rotation.y

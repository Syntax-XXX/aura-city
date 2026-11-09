class_name FX
extends RefCounted
## Effekte mit festen Emitter-Pools (keine neuen Nodes/Meshes/Materialien pro Effekt).
## Gegen Ruckler bei mehreren Wolken hintereinander:
##  - pro Effektart nur POOL_SIZE Emitter, der älteste wird wiederverwendet
##  - Partikel blenden nah an der Kamera aus (kein bildschirmfüllendes Transparenz-Stapeln)
##  - Menge/Größe skaliert mit Settings.effects_quality

const POOL_SIZE := {&"cloud": 6, &"spark": 6, &"ring": 3}
const QUALITY_MULT := [0.35, 0.7, 1.0]

static var _pools := {} # Art -> Array[CPUParticles3D]
static var _next := {} # Art -> Index (Round Robin)
static var _materials := {}
static var _tex: Texture2D
static var _labels: Array[Label3D] = []


static func _soft_texture() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_tex = t
	return _tex


static func _material(kind: StringName) -> StandardMaterial3D:
	if not _materials.has(kind):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _soft_texture()
		m.disable_receive_shadows = true
		# nah an der Kamera ausblenden → kein Vollbild-Overdraw
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		m.distance_fade_min_distance = 0.8
		m.distance_fade_max_distance = 2.6
		if kind == &"spark":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_materials[kind] = m
	return _materials[kind]


static func quality() -> float:
	return QUALITY_MULT[clampi(Settings.effects_quality, 0, 2)]


## Freien (bzw. ältesten) Emitter einer Art holen.
static func _emitter(parent: Node, kind: StringName) -> CPUParticles3D:
	var pool: Array = _pools.get(kind, [])
	pool = pool.filter(func(p): return is_instance_valid(p) and p.is_inside_tree())
	_pools[kind] = pool
	for p: CPUParticles3D in pool:
		if not p.emitting and p.get_parent() == parent:
			return p
	if pool.size() < POOL_SIZE[kind]:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.explosiveness = 0.85
		p.local_coords = false
		var quad := QuadMesh.new()
		quad.material = _material(kind)
		p.mesh = quad
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0.75 if kind == &"cloud" else 1.0))
		ramp.set_color(1, Color(1, 1, 1, 0.0))
		p.color_ramp = ramp
		parent.add_child(p)
		pool.append(p)
		return p
	var i: int = _next.get(kind, 0) % pool.size()
	_next[kind] = i + 1
	var reuse: CPUParticles3D = pool[i]
	if reuse.get_parent() != parent:
		reuse.reparent(parent, false)
	return reuse


static func _fire(p: CPUParticles3D, pos: Vector3, amount: int, lifetime: float, color: Color, size: float) -> void:
	amount = maxi(1, amount)
	if p.amount != amount:
		p.amount = amount
	p.lifetime = lifetime
	(p.mesh as QuadMesh).size = Vector2.ONE * size
	p.color = color
	p.global_position = pos
	p.restart()


## Bunte Effektwolke (fiktives Gadget, rein kosmetisch). strength skaliert Größe und Menge.
static func cloud(parent: Node, pos: Vector3, dir: Vector3, color: Color, strength := 1.0) -> void:
	var q := quality()
	var s := minf(strength, 2.2)
	var p := _emitter(parent, &"cloud")
	_fire(p, pos, mini(int(10 * s * q) + 2, 22), 1.3, color.lerp(Color.WHITE, 0.5), 0.28 * s)
	p.direction = dir
	p.spread = 25.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8 * s
	p.gravity = Vector3(0, 0.5, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	if p.scale_amount_curve == null:
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.5))
		curve.add_point(Vector2(1, 1.5))
		p.scale_amount_curve = curve


static func sparkles(parent: Node, pos: Vector3, color: Color, amount := 24, radius := 1.0) -> void:
	var p := _emitter(parent, &"spark")
	_fire(p, pos, mini(int(amount * quality()), 40), 0.8, color, 0.1)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.3
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0 * radius
	p.initial_velocity_max = 4.5 * radius
	p.gravity = Vector3(0, -3.0, 0)


static func ring(parent: Node, pos: Vector3, color: Color, radius := 3.0) -> void:
	var p := _emitter(parent, &"ring")
	_fire(p, pos, int(36 * quality()) + 6, 0.7, color, 0.22)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.3
	p.emission_ring_inner_radius = 0.2
	p.emission_ring_height = 0.05
	p.direction = Vector3(1, 0, 0)
	p.spread = 180.0
	p.flatness = 1.0
	p.initial_velocity_min = radius * 2.0
	p.initial_velocity_max = radius * 2.4
	p.gravity = Vector3.ZERO


## Schwebender Text (z. B. "+120 ✦"), höchstens 10 gleichzeitig.
static func floating_text(parent: Node, pos: Vector3, text: String, color: Color, size := 64) -> void:
	_labels = _labels.filter(func(l): return is_instance_valid(l))
	if _labels.size() >= 10:
		_labels.pop_front().queue_free()
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.outline_size = 12
	l.font_size = size
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	parent.add_child(l)
	_labels.append(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", pos + Vector3.UP * 1.4, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.tween_callback(l.queue_free)

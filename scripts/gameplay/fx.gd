class_name FX
extends RefCounted
## Effekte mit festen Emitter-Pools (keine neuen Nodes/Meshes/Materialien pro Effekt).
## Gegen Ruckler bei mehreren Wolken hintereinander:
##  - pro Effektart nur POOL_SIZE Emitter, der älteste wird wiederverwendet
##  - Partikel blenden nah an der Kamera aus (kein bildschirmfüllendes Transparenz-Stapeln)
##  - Menge/Größe skaliert mit Settings.effects_quality

const POOL_SIZE := {&"cloud": 6, &"spark": 6, &"ring": 3, &"vape": 12, &"vring": 6}
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
		ramp.set_color(0, Color(1, 1, 1, 0.75 if kind in [&"cloud", &"vape", &"vring"] else 1.0))
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


## Eine Dampfwolke: setzt ALLE Eigenschaften neu, weil Emitter aus dem Pool wiederverwendet werden.
static func _puff(parent: Node, pos: Vector3, vel: Vector3, color: Color, amount: int, size: float,
		life := 1.6, spread := 18.0, gravity := Vector3(0, 0.35, 0)) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p := _emitter(parent, &"vape")
	_fire(p, pos, maxi(2, int(amount * quality())), life, color.lerp(Color.WHITE, 0.65), size)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.15
	var speed := vel.length()
	p.direction = vel.normalized() if speed > 0.01 else Vector3.UP
	p.spread = spread
	p.flatness = 0.0
	p.initial_velocity_min = speed * 0.7
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.damping_min = speed * 0.6
	p.damping_max = speed * 0.9
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	if p.scale_amount_curve == null:
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.4))
		curve.add_point(Vector2(1, 1.8))
		p.scale_amount_curve = curve


## Wandernder Dampfring (Ring-Emitter senkrecht zur Flugrichtung, alle Partikel gleich schnell).
static func _vape_ring(parent: Node, pos: Vector3, dir: Vector3, color: Color, radius: float, speed := 1.6) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p := _emitter(parent, &"vring")
	_fire(p, pos, maxi(10, int(26 * quality())), 2.2, color.lerp(Color.WHITE, 0.65), radius * 0.55)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = dir.normalized()
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = radius * 0.85
	p.emission_ring_height = 0.02
	p.direction = dir.normalized()
	p.spread = 0.0
	p.flatness = 0.0
	p.initial_velocity_min = speed
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, 0.15, 0)
	p.damping_min = speed * 0.3
	p.damping_max = speed * 0.3
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0


static func _later(parent: Node, seconds: float, f: Callable) -> void:
	if seconds <= 0.0:
		f.call()
	elif is_instance_valid(parent) and parent.is_inside_tree():
		parent.get_tree().create_timer(seconds).timeout.connect(f)


## Dampfwolke in einer Form (fiktive Vape, rein visuell). shape: puff, rings, ghost, waterfall,
## jellyfish, dragon, bullseye, tornado, mega. count wiederholt die Form, strength = Vape-Stufe.
static func vape_cloud(parent: Node, mouth: Vector3, forward: Vector3, color: Color, shape: StringName, count := 1, strength := 1.0) -> void:
	var f := Vector3(forward.x, 0, forward.z).normalized()
	if f == Vector3.ZERO:
		f = Vector3.FORWARD
	var side := f.cross(Vector3.UP).normalized()
	var s := clampf(strength, 0.6, 3.0)
	for i in maxi(count, 1):
		var t := i * 0.45
		var big := s * (1.6 if shape == &"ghost" and count == 2 else 1.0)
		match shape:
			&"rings":
				_later(parent, t, func(): _vape_ring(parent, mouth + f * 0.15, f, color, 0.12 * s))
			&"ghost":
				# Ball raus, kurz stehen lassen, dann zurück zum Mund ziehen
				_later(parent, t, func(): _puff(parent, mouth + f * 0.1, f * 0.9, color, int(14 * big), 0.22 * big, 1.1, 10.0, Vector3.ZERO))
				_later(parent, t + 0.7, func(): _puff(parent, mouth + f * 0.55 * big, -f * 0.9, color, int(10 * big), 0.2 * big, 0.6, 8.0, Vector3.ZERO))
			&"waterfall":
				_later(parent, t, func(): _puff(parent, mouth + f * 0.1, f * 0.4 + Vector3.DOWN * 0.2, color, int(18 * s), 0.2 * s, 2.4, 25.0, Vector3(0, -0.45, 0)))
			&"jellyfish":
				_later(parent, t, func(): _vape_ring(parent, mouth + f * 0.15, f + Vector3.UP * 0.6, color, 0.16 * s, 1.2))
				_later(parent, t + 0.25, func(): _puff(parent, mouth + f * 0.3, f * 0.6, color, int(12 * s), 0.14 * s, 2.0, 12.0, Vector3(0, -0.3, 0)))
			&"dragon":
				_later(parent, t, func():
					_puff(parent, mouth + f * 0.1, f * 2.0, color, int(14 * s), 0.18 * s, 1.4, 12.0)
					_puff(parent, mouth + side * 0.05, (side + Vector3.DOWN * 0.4) * 1.4, color, int(8 * s), 0.13 * s, 1.2, 10.0)
					_puff(parent, mouth - side * 0.05, (-side + Vector3.DOWN * 0.4) * 1.4, color, int(8 * s), 0.13 * s, 1.2, 10.0))
			&"bullseye":
				_later(parent, t, func(): _vape_ring(parent, mouth + f * 0.15, f, color, 0.3 * s, 0.9))
				_later(parent, t + 0.55, func(): _vape_ring(parent, mouth + f * 0.15, f, color, 0.08 * s, 2.6))
			&"tornado":
				for k in 10:
					var a := k * 0.7
					var off := (side * cos(a) + f * sin(a)) * (0.15 + k * 0.04) * s + Vector3.UP * k * 0.12 * s
					_later(parent, t + k * 0.08, func(): _puff(parent, mouth + f * 0.6 + off, Vector3.UP * 0.5, color, int(5 * s), 0.14 * s, 1.4, 20.0))
			&"mega":
				_later(parent, t, func():
					_puff(parent, mouth + f * 0.2, f * 2.2 + Vector3.UP * 0.3, color, int(30 * s), 0.45 * s, 3.0, 35.0, Vector3(0, 0.25, 0))
					_vape_ring(parent, mouth + f * 0.4, f, color, 0.35 * s, 1.0))
			_:
				_later(parent, t, func(): _puff(parent, mouth + f * 0.1, f * 1.4 + Vector3.UP * 0.2, color, int(12 * s), 0.2 * s))


## Husten: kleine, zerfetzte graue Stöße.
static func cough(parent: Node, mouth: Vector3, forward: Vector3) -> void:
	for k in 3:
		_later(parent, k * 0.18, func(): _puff(parent, mouth + forward * 0.1, (forward + Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.2), 0)) * 1.8, Color(0.75, 0.75, 0.75), 5, 0.1, 0.7, 40.0))


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

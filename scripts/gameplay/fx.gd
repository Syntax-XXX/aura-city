class_name FX
extends RefCounted
## Effekt-Fabrik: Wolken-Puffs, Funken, Ringe, schwebender Text. Alles CPUParticles3D (läuft überall).


static func _particles(parent: Node, pos: Vector3, amount: int, lifetime: float, color: Color, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_texture()
	quad.material = m
	p.mesh = quad
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.emitting = true
	return p


static var _tex: Texture2D


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


## Bunte Effektwolke (fiktives Gadget). strength skaliert Größe und Menge.
static func cloud(parent: Node, pos: Vector3, dir: Vector3, color: Color, strength := 1.0) -> void:
	var p := _particles(parent, pos, int(18 * strength), 1.8, color.lerp(Color.WHITE, 0.55), 0.35 * strength)
	p.direction = dir
	p.spread = 25.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2 * strength
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.8))
	p.scale_amount_curve = curve


static func sparkles(parent: Node, pos: Vector3, color: Color, amount := 24, radius := 1.0) -> void:
	var p := _particles(parent, pos, amount, 0.9, color, 0.12)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.3
	p.spread = 180.0
	p.initial_velocity_min = 2.0 * radius
	p.initial_velocity_max = 4.5 * radius
	p.gravity = Vector3(0, -3.0, 0)


static func ring(parent: Node, pos: Vector3, color: Color, radius := 3.0) -> void:
	var p := _particles(parent, pos, 48, 0.8, color, 0.25)
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


## Schwebender Text (z. B. "+120 ✦").
static func floating_text(parent: Node, pos: Vector3, text: String, color: Color, size := 64) -> void:
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
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", pos + Vector3.UP * 1.4, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.tween_callback(l.queue_free)

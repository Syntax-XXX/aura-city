class_name WorldKit
extends RefCounted
## Bausteine für die prozedurale Stadt: Boden, Kisten, Gebäude, Rampen, Laternen, Schilder, Bäume.

static var _mat_cache := {}


static func mat(c: Color, rough := 0.85, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), rough, metal, glow]
	if not _mat_cache.has(key):
		_mat_cache[key] = CharacterVisual.make_material(c, rough, metal, glow)
	return _mat_cache[key]


## Box mit optionaler Kollision. rot = Euler-Winkel.
static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, collide := true, rot := Vector3.ZERO) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	if not collide:
		mi.position = pos
		mi.rotation = rot
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	body.add_child(mi)
	parent.add_child(body)
	return body


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, collide := true) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	if not collide:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	body.add_child(mi)
	parent.add_child(body)
	return body


static func _window_texture(base: Color, lit: Color, dark: Color) -> ImageTexture:
	var img := Image.create(64, 128, false, Image.FORMAT_RGB8)
	img.fill(base)
	for y in range(8, 120, 16):
		for x in range(6, 58, 14):
			img.fill_rect(Rect2i(x, y, 8, 10), lit if randf() < 0.4 else dark)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Gebäude mit Fensterraster und Dach. neon = leuchtende Fenster (Nacht-Distrikt).
static func building(parent: Node3D, pos: Vector3, size: Vector3, base: Color, neon := Color.TRANSPARENT) -> void:
	var lit := neon if neon.a > 0.0 else Color("fde68a")
	var m := StandardMaterial3D.new()
	m.albedo_texture = _window_texture(base, lit, base.darkened(0.5))
	m.uv1_scale = Vector3(maxf(1.0, roundf(size.x / 4.0)), maxf(1.0, roundf(size.y / 8.0)), 1)
	m.roughness = 0.8
	if neon.a > 0.0:
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission = Color(0.6, 0.6, 0.6)
		m.emission_energy_multiplier = 0.9
	box(parent, size, pos + Vector3(0, size.y / 2, 0), m)
	box(parent, Vector3(size.x + 0.4, 0.4, size.z + 0.4), pos + Vector3(0, size.y + 0.2, 0), mat(base.darkened(0.4)), false)
	if neon.a > 0.0:
		box(parent, Vector3(size.x + 0.1, 0.25, 0.25), pos + Vector3(0, size.y * 0.6, size.z / 2 + 0.15), mat(neon, 0.3, 0.0, 3.0), false)


static func street_light(parent: Node3D, pos: Vector3, color := Color("fff1c4")) -> void:
	cylinder(parent, 0.09, 4.5, pos + Vector3(0, 2.25, 0), mat(Color("1f2937"), 0.4, 0.6))
	var bulb := cylinder(parent, 0.3, 0.2, pos + Vector3(0, 4.55, 0), mat(color, 0.3, 0.0, 2.5), false)
	bulb.add_to_group(&"street_light_bulbs")
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 4.2, 0)
	light.omni_range = 9.0
	light.light_color = color
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.add_to_group(&"street_lights")
	parent.add_child(light)


static func tree(parent: Node3D, pos: Vector3, scale := 1.0) -> void:
	cylinder(parent, 0.25 * scale, 2.4 * scale, pos + Vector3(0, 1.2 * scale, 0), mat(Color("7c4a2d")))
	var leaves := SphereMesh.new()
	leaves.radius = 1.6 * scale
	leaves.height = 2.8 * scale
	leaves.radial_segments = 8
	leaves.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = leaves
	mi.material_override = mat(Color.from_hsv(randf_range(0.25, 0.33), 0.55, 0.45))
	mi.position = pos + Vector3(0, 3.4 * scale, 0)
	parent.add_child(mi)


static func bench(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation.y = yaw
	parent.add_child(b)
	box(b, Vector3(2.2, 0.12, 0.6), Vector3(0, 0.5, 0), mat(Color("9a6b3f")))
	box(b, Vector3(2.2, 0.5, 0.1), Vector3(0, 0.85, 0.28), mat(Color("9a6b3f")), false)
	for x in [-0.9, 0.9]:
		box(b, Vector3(0.1, 0.5, 0.5), Vector3(x, 0.25, 0), mat(Color("222222")), false)


## Großes, leuchtendes Schild (Label3D) – Distriktnamen, Shops, Hinweise.
static func sign_text(parent: Node3D, pos: Vector3, text: String, color: Color, size := 160, yaw := 0.0, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 24
	l.outline_modulate = color.darkened(0.75)
	l.position = pos
	l.rotation.y = yaw
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l


## Bodenplatte mit Kollision (Oberkante bei pos.y).
static func ground(parent: Node3D, size: Vector2, pos: Vector3, material: Material, thickness := 1.0) -> void:
	box(parent, Vector3(size.x, thickness, size.y), pos - Vector3(0, thickness / 2, 0), material)


## Bereich, der beim Betreten den Distrikt meldet.
static func district_area(parent: Node3D, district_id: StringName, center: Vector3, size: Vector3) -> void:
	var area := DistrictArea.new()
	area.district_id = district_id
	area.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	area.add_child(col)
	parent.add_child(area)

class_name WorldKit
extends RefCounted
## Bausteine für die prozedurale Stadt: Boden, Kisten, Gebäude, Rampen, Laternen, Schilder, Bäume.

static var _mat_cache := {}
static var _building_cache := {} # gleiche Fassaden teilen sich Textur + Material (große Map!)
static var _invisible := StandardMaterial3D.new()
static var _surface_cache := {}
static var _nature_cache := {}

## PBR-Oberflächen (Poly Haven, CC0): Texturname, Kachelgröße in Metern
const SURFACES := {
	&"grass": ["leafy_grass", 5.0], &"asphalt": ["asphalt_02", 6.0], &"plaza": ["hexagonal_concrete_paving", 4.0],
	&"sidewalk": ["pavement_03", 3.0], &"sand": ["coast_sand_01", 5.0], &"concrete": ["concrete_floor_02", 5.0],
	&"tiles": ["large_floor_tiles_02", 4.0], &"wood": ["wood_planks", 3.0],
}
const TREES := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5"]
const PINES := ["Pine_1", "Pine_2", "Pine_3"]
const BUSHES := ["Bush_Common", "Bush_Common_Flowers", "Flower_3_Group", "Flower_4_Group", "Fern_1", "Plant_1_Big"]
const ROCKS := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]


static func mat(c: Color, rough := 0.85, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), rough, metal, glow]
	if not _mat_cache.has(key):
		_mat_cache[key] = CharacterVisual.make_material(c, rough, metal, glow)
	return _mat_cache[key]


## Texturierte PBR-Oberfläche mit Weltraum-Projektion (kachelt auf beliebig großen Flächen).
## tint färbt ein (z. B. dunkler, nasser Neon-Asphalt), rough skaliert die Rauheit.
static func surface(kind: StringName, tint := Color.WHITE, rough := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%.2f" % [kind, tint.to_html(), rough]
	if _surface_cache.has(key):
		return _surface_cache[key]
	var spec: Array = SURFACES[kind]
	var base := "res://assets/textures/%s_" % spec[0]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(base + "diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(base + "nor.jpg")
	m.normal_scale = 0.8
	m.roughness_texture = load(base + "rough.jpg")
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / float(spec[1])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_surface_cache[key] = m
	return m


## Modell aus dem Stylized Nature MegaKit platzieren (optional mit Stamm-Kollision).
static func nature(parent: Node3D, model_id: String, pos: Vector3, scale := 1.0, trunk_radius := 0.0) -> Node3D:
	if not _nature_cache.has(model_id):
		_nature_cache[model_id] = load("res://assets/nature/%s.gltf" % model_id)
	var n: Node3D = (_nature_cache[model_id] as PackedScene).instantiate()
	n.position = pos
	n.rotation.y = randf() * TAU
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	if trunk_radius > 0.0:
		cylinder(parent, trunk_radius * scale, 3.0 * scale, pos + Vector3(0, 1.5 * scale, 0), _invisible).get_child(1).queue_free()
	return n


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
	var uv := Vector3(maxf(1.0, roundf(size.x / 4.0)), maxf(1.0, roundf(size.y / 8.0)), 1)
	var key := "%s|%s|%s|%d" % [base.to_html(), lit.to_html(), uv, randi() % 3]
	if not _building_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _window_texture(base, lit, base.darkened(0.5))
		m.uv1_scale = uv
		m.roughness = 0.8
		if neon.a > 0.0:
			m.emission_enabled = true
			m.emission_texture = m.albedo_texture
			m.emission = Color(0.6, 0.6, 0.6)
			m.emission_energy_multiplier = 0.9
		_building_cache[key] = m
	box(parent, size, pos + Vector3(0, size.y / 2, 0), _building_cache[key])
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
	light.distance_fade_enabled = true # ferne Laternen kosten nichts
	light.distance_fade_begin = 70.0
	light.distance_fade_length = 20.0
	light.add_to_group(&"street_lights")
	parent.add_child(light)


static func tree(parent: Node3D, pos: Vector3, scale := 1.0) -> void:
	if randf() < 0.25:
		nature(parent, PINES[randi() % PINES.size()], pos, scale * 1.1, 0.35)
	else:
		nature(parent, TREES[randi() % TREES.size()], pos, scale, 0.4)


static func bush(parent: Node3D, pos: Vector3, scale := 1.0) -> void:
	nature(parent, BUSHES[randi() % BUSHES.size()], pos, scale)


static func rock(parent: Node3D, pos: Vector3, scale := 1.0) -> void:
	nature(parent, ROCKS[randi() % ROCKS.size()], pos, scale, 0.8)


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


## Unsichtbare Wand (Kollision ohne Mesh).
static func invisible_wall(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	box(parent, size, pos, _invisible, true).get_child(1).queue_free()


## Wendeltreppe aus Blöcken um `center`; liefert die Oberkante der letzten Stufe.
static func spiral_stairs(parent: Node3D, center: Vector3, steps: int, step_h: float, radius: float, material: Material, start_angle := 0.0) -> Vector3:
	var top := center
	for i in steps:
		var a := start_angle + i * 0.62
		var h := step_h * (i + 1)
		var p := center + Vector3(cos(a) * radius, h / 2.0, sin(a) * radius)
		box(parent, Vector3(2.4, h, 2.4), p, material)
		top = Vector3(p.x, h, p.z)
	return top


## Palme: schräger Stamm + flache Blätter.
static func palm(parent: Node3D, pos: Vector3, scale := 1.0) -> void:
	var lean := randf_range(-0.18, 0.18)
	box(parent, Vector3(0.45, 6.0, 0.45) * scale, pos + Vector3(0, 3.0 * scale, 0), mat(Color("8b5a2b")), true, Vector3(lean, 0, lean))
	var top := pos + Vector3(lean * 3.0 * scale, 6.0 * scale, -lean * 3.0 * scale)
	for i in 6:
		var a := i * TAU / 6.0
		box(parent, Vector3(3.2, 0.12, 0.8) * scale, top + Vector3(cos(a), -0.3, sin(a)) * 1.4 * scale, mat(Color("15803d")), false, Vector3(0, -a, 0.35))


## Einfaches Haus mit Satteldach (Vororte zwischen den Distrikten).
static func house(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var h := Node3D.new()
	h.position = pos
	h.rotation.y = yaw
	parent.add_child(h)
	var walls := [Color("f5f5f4"), Color("fde68a"), Color("bfdbfe"), Color("fecaca"), Color("d9f99d")]
	var size := Vector3(randf_range(7, 10), 4.0, randf_range(6, 8))
	box(h, size, Vector3(0, size.y / 2, 0), mat(walls[randi() % walls.size()]))
	var roof := mat(Color("7f1d1d") if randf() < 0.5 else Color("334155"))
	for side: float in [-1.0, 1.0]:
		box(h, Vector3(size.x + 0.6, 0.3, size.z * 0.62), Vector3(0, size.y + 1.0, side * size.z * 0.25), roof, false, Vector3(-side * 0.6, 0, 0))
	box(h, Vector3(1.2, 2.2, 0.1), Vector3(0, 1.1, size.z / 2 + 0.05), mat(Color("78350f")), false)

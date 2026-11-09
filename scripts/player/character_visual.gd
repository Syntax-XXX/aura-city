class_name CharacterVisual
extends Node3D
## Prozedurale Low-Poly-Figur mit Gelenk-Pivots. Wird für Spieler, NPCs und Vorschauen benutzt.
## Kosmetik (Haut, Frisur, Outfit, Schuhe, Accessoire, Gadget) wird über apply_look() gesetzt.

var pivots := {} # Name -> Node3D (hips, torso, head, arm_l, arm_r, elbow_l, elbow_r, leg_l, leg_r, knee_l, knee_r)
var _materials := {} # Teil -> StandardMaterial3D
var _hair_root: Node3D
var _accessory_root: Node3D
var _gadget_root: Node3D
var _outfit_extra: Node3D
var gadget_tip: Node3D # Ursprung für Gadget-Effekte


func _init() -> void:
	_build()


static func make_material(c: Color, rough := 0.8, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _mat(part: String, c: Color) -> StandardMaterial3D:
	var m := make_material(c)
	_materials[part] = m
	return m


func _mesh(m: Mesh, material: Material, parent: Node3D, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pivot(pivot_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = pivot_name
	p.position = pos
	parent.add_child(p)
	pivots[pivot_name] = p
	return p


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


func _build() -> void:
	var skin := _mat("skin", Color("e0ac69"))
	var shirt := _mat("shirt", Color("6b7280"))
	var pants := _mat("pants", Color("1f2937"))
	var shoe := _mat("shoes", Color("f8fafc"))
	var hips := _pivot("hips", self, Vector3(0, 0.95, 0))
	var torso := _pivot("torso", hips, Vector3(0, 0.05, 0))
	_mesh(_capsule(0.24, 0.72), shirt, torso, Vector3(0, 0.3, 0))
	_mesh(_box(Vector3(0.42, 0.2, 0.24)), pants, hips, Vector3(0, -0.02, 0))
	var head := _pivot("head", torso, Vector3(0, 0.72, 0))
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.19
	head_mesh.height = 0.4
	_mesh(head_mesh, skin, head, Vector3(0, 0.12, 0))
	var eye := SphereMesh.new()
	eye.radius = 0.028
	eye.height = 0.056
	var eye_mat := make_material(Color("111111"), 0.3)
	_mesh(eye, eye_mat, head, Vector3(-0.07, 0.15, -0.17))
	_mesh(eye, eye_mat, head, Vector3(0.07, 0.15, -0.17))
	_hair_root = Node3D.new()
	head.add_child(_hair_root)
	_accessory_root = Node3D.new()
	head.add_child(_accessory_root)
	_outfit_extra = Node3D.new()
	torso.add_child(_outfit_extra)
	for side in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var arm := _pivot("arm_" + s, torso, Vector3(0.3 * side, 0.58, 0))
		_mesh(_capsule(0.075, 0.38), shirt, arm, Vector3(0, -0.16, 0))
		var elbow := _pivot("elbow_" + s, arm, Vector3(0, -0.34, 0))
		_mesh(_capsule(0.065, 0.34), skin, elbow, Vector3(0, -0.15, 0))
		if side > 0:
			_gadget_root = Node3D.new()
			_gadget_root.position = Vector3(0, -0.33, -0.04)
			elbow.add_child(_gadget_root)
		var leg := _pivot("leg_" + s, hips, Vector3(0.12 * side, -0.08, 0))
		_mesh(_capsule(0.09, 0.46), pants, leg, Vector3(0, -0.2, 0))
		var knee := _pivot("knee_" + s, leg, Vector3(0, -0.42, 0))
		_mesh(_capsule(0.08, 0.42), pants, knee, Vector3(0, -0.18, 0))
		_mesh(_box(Vector3(0.14, 0.09, 0.26)), shoe, knee, Vector3(0, -0.4, -0.05))
	gadget_tip = Node3D.new()
	_gadget_root.add_child(gadget_tip)
	gadget_tip.position = Vector3(0, 0.12, 0)


## Kosmetik anwenden. look: Slot -> ItemDef (fehlende Slots = Standard).
func apply_look(look: Dictionary) -> void:
	var skin: ItemDef = look.get(&"skin")
	var skin_color := skin.color if skin else Color("e0ac69")
	_materials["skin"].albedo_color = skin_color
	_set_glow(_materials["skin"], skin and skin.variant == &"glow", skin_color)
	_materials["skin"].metallic = 0.8 if skin and skin.variant == &"metal" else 0.0
	_materials["skin"].roughness = 0.3 if skin and skin.variant == &"metal" else 0.8
	var outfit: ItemDef = look.get(&"outfit")
	_materials["shirt"].albedo_color = outfit.color if outfit else Color("6b7280")
	_materials["pants"].albedo_color = outfit.accent_color.darkened(0.55) if outfit else Color("1f2937")
	_set_glow(_materials["shirt"], outfit and outfit.rarity >= ItemDef.Rarity.EPIC, outfit.accent_color if outfit else Color.BLACK, 0.25)
	_build_outfit_extra(outfit)
	var shoes: ItemDef = look.get(&"shoes")
	_materials["shoes"].albedo_color = shoes.color if shoes else Color("f8fafc")
	_set_glow(_materials["shoes"], shoes and shoes.rarity >= ItemDef.Rarity.EPIC, shoes.color if shoes else Color.BLACK, 0.6)
	_build_hair(look.get(&"hair"))
	_build_accessory(look.get(&"accessory"))
	_build_gadget(look.get(&"gadget"))


func _set_glow(m: StandardMaterial3D, on: bool, c: Color, energy := 0.8) -> void:
	m.emission_enabled = on
	if on:
		m.emission = c
		m.emission_energy_multiplier = energy


func _clear(n: Node3D) -> void:
	for c in n.get_children():
		c.queue_free()


func _build_hair(item: ItemDef) -> void:
	_clear(_hair_root)
	if item == null:
		return
	var m := make_material(item.color, 0.9)
	if item.accent_color != Color.BLACK and item.rarity >= ItemDef.Rarity.EPIC:
		_set_glow(m, true, item.accent_color, 0.4)
	match item.variant:
		&"short":
			var cap := SphereMesh.new()
			cap.radius = 0.2
			cap.height = 0.24
			cap.is_hemisphere = true
			_mesh(cap, m, _hair_root, Vector3(0, 0.16, 0.01))
		&"spiky":
			for i in 7:
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.07
				cone.height = 0.22
				var spike := _mesh(cone, m, _hair_root, Vector3((i - 3) * 0.05, 0.3, randf_range(-0.06, 0.06)))
				spike.rotation.z = (i - 3) * 0.18
		&"long":
			var cap := SphereMesh.new()
			cap.radius = 0.21
			cap.height = 0.42
			_mesh(cap, m, _hair_root, Vector3(0, 0.16, 0.03))
			_mesh(_box(Vector3(0.36, 0.38, 0.12)), m, _hair_root, Vector3(0, -0.04, 0.12))
		&"afro":
			var ball := SphereMesh.new()
			ball.radius = 0.3
			ball.height = 0.56
			_mesh(ball, m, _hair_root, Vector3(0, 0.24, 0.03))
		&"mohawk":
			_mesh(_box(Vector3(0.06, 0.2, 0.36)), m, _hair_root, Vector3(0, 0.36, 0.02))


func _build_accessory(item: ItemDef) -> void:
	_clear(_accessory_root)
	if item == null:
		return
	var m := make_material(item.color, 0.4, 0.3)
	var accent := make_material(item.accent_color, 0.4, 0.2)
	match item.variant:
		&"cap":
			var dome := SphereMesh.new()
			dome.radius = 0.21
			dome.height = 0.24
			dome.is_hemisphere = true
			_mesh(dome, m, _accessory_root, Vector3(0, 0.19, 0))
			_mesh(_box(Vector3(0.22, 0.02, 0.18)), accent, _accessory_root, Vector3(0, 0.2, 0.2))
		&"shades":
			_mesh(_box(Vector3(0.3, 0.07, 0.03)), m, _accessory_root, Vector3(0, 0.15, -0.19))
		&"headphones":
			var band := TorusMesh.new()
			band.inner_radius = 0.19
			band.outer_radius = 0.22
			var b := _mesh(band, m, _accessory_root, Vector3(0, 0.14, 0))
			b.rotation.z = PI / 2
			for side in [-1, 1]:
				_mesh(_box(Vector3(0.06, 0.12, 0.12)), accent, _accessory_root, Vector3(0.2 * side, 0.12, 0))
		&"chain":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.17
			ring.outer_radius = 0.2
			var r := _mesh(ring, make_material(item.color, 0.2, 1.0), _accessory_root, Vector3(0, -0.12, -0.03))
			r.rotation.x = 1.2
		&"crown":
			var base := CylinderMesh.new()
			base.top_radius = 0.17
			base.bottom_radius = 0.15
			base.height = 0.1
			_mesh(base, make_material(item.color, 0.2, 1.0, 0.3), _accessory_root, Vector3(0, 0.33, 0))
			for i in 5:
				var a := i / 5.0 * TAU
				_mesh(_box(Vector3(0.04, 0.08, 0.04)), accent, _accessory_root, Vector3(cos(a) * 0.15, 0.41, sin(a) * 0.15))
		&"halo":
			var halo := TorusMesh.new()
			halo.inner_radius = 0.18
			halo.outer_radius = 0.22
			_mesh(halo, make_material(item.color, 0.2, 0.0, 2.5), _accessory_root, Vector3(0, 0.52, 0))
		&"horns":
			for side in [-1, 1]:
				var horn := CylinderMesh.new()
				horn.top_radius = 0.0
				horn.bottom_radius = 0.05
				horn.height = 0.2
				var h := _mesh(horn, make_material(item.accent_color, 0.4, 0.0, 0.8), _accessory_root, Vector3(0.12 * side, 0.32, 0))
				h.rotation.z = -0.4 * side


func _build_gadget(item: ItemDef) -> void:
	for c in _gadget_root.get_children():
		if c != gadget_tip:
			c.queue_free()
	if item == null:
		return
	var body := make_material(item.color, 0.3, 0.6)
	var glow := make_material(item.accent_color, 0.3, 0.0, 1.5)
	match item.variant:
		&"box":
			_mesh(_box(Vector3(0.07, 0.12, 0.04)), body, _gadget_root)
			_mesh(_box(Vector3(0.072, 0.02, 0.042)), glow, _gadget_root, Vector3(0, -0.02, 0))
		&"orb":
			var s := SphereMesh.new()
			s.radius = 0.06
			s.height = 0.12
			_mesh(s, glow, _gadget_root, Vector3(0, 0.03, 0))
		&"wand":
			_mesh(_box(Vector3(0.025, 0.24, 0.025)), body, _gadget_root, Vector3(0, 0.06, 0))
			var tip := SphereMesh.new()
			tip.radius = 0.035
			tip.height = 0.07
			_mesh(tip, glow, _gadget_root, Vector3(0, 0.19, 0))
		_:
			_mesh(_box(Vector3(0.035, 0.13, 0.02)), body, _gadget_root)
			_mesh(_box(Vector3(0.037, 0.03, 0.022)), glow, _gadget_root, Vector3(0, -0.02, 0))


func _build_outfit_extra(item: ItemDef) -> void:
	_clear(_outfit_extra)
	if item == null:
		return
	match item.variant:
		&"hoodie":
			var hood := TorusMesh.new()
			hood.inner_radius = 0.12
			hood.outer_radius = 0.2
			_mesh(hood, make_material(item.color.darkened(0.15)), _outfit_extra, Vector3(0, 0.68, 0.06))
		&"jacket", &"suit", &"tracksuit":
			_mesh(_box(Vector3(0.08, 0.5, 0.02)), make_material(item.accent_color, 0.6), _outfit_extra, Vector3(0, 0.33, -0.235))
		&"robe":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.26
			cone.bottom_radius = 0.42
			cone.height = 0.75
			_mesh(cone, make_material(item.color, 0.7, 0.0, 0.2), _outfit_extra, Vector3(0, -0.3, 0))

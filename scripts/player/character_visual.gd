class_name CharacterVisual
extends Node3D
## Spielfigur auf Basis der Quaternius-Stadtfiguren (CC0) mit retargeteten Animationen der
## Universal Animation Library (siehe tools/retarget_ual.gd).
##  - Outfit-Item bestimmt das Basismodell (männlich/weiblich), Farben kommen aus dem Item
##  - Frisur-Item übernimmt die Haar-Geometrie eines anderen Modells (gleiches Skelett) oder baut sie
##  - Schuhe, Accessoires und Gadget hängen an Knochen (BoneAttachment3D)

const MODEL_DIR := "res://assets/characters/models/"
const ANIMS: AnimationLibrary = preload("res://assets/characters/ual_anims.res")
const MODEL_SCALE := 0.8
const BODIES := {
	&"tee": ["Casual_Male", "Casual_Female"], &"hoodie": ["Casual2_Male", "Casual2_Female"],
	&"jacket": ["Casual3_Male", "Casual3_Female"], &"tracksuit": ["Worker_Male", "Worker_Female"],
	&"suit": ["Suit_Male", "Suit_Female"], &"robe": ["Kimono_Male", "Kimono_Female"],
}
const HAIR_DONORS := {&"short": "Casual_Male", &"spiky": "Kimono_Female", &"long": "Doctor_Female_Young"}
const PRIMARY := ["Shirt", "Clothes", "Main", "Jacket", "Top", "Vest", "Black"]
const SECONDARY := ["Pants", "DarkClothes", "Band", "Belt", "Details", "Detail"]
const HAIR_SURFACES := ["Hair"]
const HAT_SURFACES := ["Hat", "HatBrown", "HatLightBrown"]

static var _scenes := {} # Modellname -> PackedScene
static var _mesh_cache := {} # Schlüssel -> ArrayMesh
static var _bounds_cache := {} # Modellname -> {bone: AABB im Modellraum}
static var _mat_cache := {}

## 0 = männlich, 1 = weiblich (Spieler: Settings.avatar_body)
var body_type := 0
var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var body_mesh: MeshInstance3D
var pose: Node3D
var gadget_tip: Node3D
var model_name := ""
var _extras: Array[Node] = []
var _attachments := {}


func _init() -> void:
	pose = Node3D.new()
	pose.name = "Pose"
	add_child(pose)
	gadget_tip = Node3D.new()
	add_child(gadget_tip)
	gadget_tip.position = Vector3(0.3, 1.1, -0.3)


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


static func _mat(c: Color, rough := 0.75, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), rough, metal, glow]
	if not _mat_cache.has(key):
		var m := make_material(c, rough, metal, glow)
		m.rim_enabled = true
		m.rim = 0.25
		m.rim_tint = 0.6
		_mat_cache[key] = m
	return _mat_cache[key]


static func _scene(model_id: String) -> PackedScene:
	if not _scenes.has(model_id):
		_scenes[model_id] = load(MODEL_DIR + model_id + ".fbx")
	return _scenes[model_id]


# ── Modell ─────────────────────────────────────────────────
## Basismodell setzen (wird nur neu gebaut, wenn es sich ändert).
func set_model(model_id: String, keep_hair := false) -> void:
	if model_id == model_name and model:
		return
	if gadget_tip.get_parent() != self:
		gadget_tip.get_parent().remove_child(gadget_tip)
		add_child(gadget_tip)
	if model:
		model.queue_free()
	_attachments.clear()
	_extras.clear()
	model_name = model_id
	model = _scene(model_id).instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	model.rotation.y = PI # Modelle schauen nach +Z, das Spiel nach −Z
	pose.add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false)
	anim = model.find_child("AnimationPlayer", true, false)
	if not anim.has_animation_library(&"ual"):
		anim.add_animation_library(&"ual", ANIMS)
	for a in ["CharacterArmature|Idle", "CharacterArmature|Walk"]:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	body_mesh = skeleton.find_children("*", "MeshInstance3D", false, false)[0]
	# Eigene Haare/Hüte entfernen, wenn die Frisur aus dem Item kommt
	var drop: Array = HAT_SURFACES.duplicate()
	if not keep_hair:
		drop.append_array(HAIR_SURFACES)
	body_mesh.mesh = _mesh_without(model_id, body_mesh.mesh, drop)
	_bounds(model_id)


static func _mesh_without(model_id: String, mesh: Mesh, drop: Array) -> ArrayMesh:
	var key := "%s|-%s" % [model_id, ",".join(drop)]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		var sname := mat.resource_name if mat else ""
		if sname in drop:
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s))
		out.surface_set_material(out.get_surface_count() - 1, mat)
		out.surface_set_name(out.get_surface_count() - 1, sname)
	_mesh_cache[key] = out
	return out


## Nur bestimmte Oberflächen eines Spender-Modells (z. B. Haare) als eigenes Skin-Mesh.
func _donor_part(donor_id: String, surfaces: Array, color: Color) -> void:
	var key := "%s|+%s" % [donor_id, ",".join(surfaces)]
	var donor := _scene(donor_id).instantiate()
	var donor_mi: MeshInstance3D = donor.find_child("Skeleton3D", true, false).find_children("*", "MeshInstance3D", false, false)[0]
	if not _mesh_cache.has(key):
		var part := ArrayMesh.new()
		var src := donor_mi.mesh
		for s in src.get_surface_count():
			var mat := src.surface_get_material(s)
			if mat and mat.resource_name in surfaces:
				part.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
				part.surface_set_name(part.get_surface_count() - 1, mat.resource_name)
		_mesh_cache[key] = part
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_cache[key]
	mi.skin = donor_mi.skin
	mi.transform = donor_mi.transform
	for s in mi.mesh.get_surface_count():
		mi.set_surface_override_material(s, _mat(color, 0.85))
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	donor.free()
	_extras.append(mi)


## Begrenzungsboxen von Kopf, Füßen und Händen (Modellraum, unskaliert) – für Accessoires.
func _bounds(model_id: String) -> Dictionary:
	if _bounds_cache.has(model_id):
		return _bounds_cache[model_id]
	var bones := {"Head": -1, "Foot.L": -1, "Foot.R": -1, "Fist.R": -1, "Torso": -1}
	for b in bones:
		bones[b] = skeleton.find_bone(b)
	var boxes := {}
	var to_model := model.transform.affine_inverse() * _skeleton_to_model_root()
	var mesh := body_mesh.mesh
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var vb = arr[Mesh.ARRAY_BONES]
		var vw = arr[Mesh.ARRAY_WEIGHTS]
		if vb == null or vw == null:
			continue
		var per := (vb as PackedInt32Array).size() / verts.size()
		for v in verts.size():
			var best := 0
			for k in range(1, per):
				if vw[v * per + k] > vw[v * per + best]:
					best = k
			var bone: int = vb[v * per + best]
			for b in bones:
				if bones[b] == bone:
					var p := to_model * (body_mesh.transform * verts[v])
					boxes[b] = (boxes[b] as AABB).expand(p) if boxes.has(b) else AABB(p, Vector3.ZERO)
	_bounds_cache[model_id] = boxes
	return boxes


## Transform Skelettraum → Modell-Wurzel (inkl. Armature-Skalierung/-Drehung).
func _skeleton_to_model_root() -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = skeleton
	while n and n != model:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return model.transform * t


## Halter an einem Knochen: Achsen wie das Modell (Y hoch), Maßstab in Modellmetern,
## Ursprung am Knochen. Folgt der Animation.
func _holder(bone: String) -> Node3D:
	if _attachments.has(bone):
		return _attachments[bone]
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	var holder := Node3D.new()
	ba.add_child(holder)
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	var skel_to_model := model.transform.affine_inverse() * _skeleton_to_model_root()
	holder.transform = rest.affine_inverse() * Transform3D(skel_to_model.basis.inverse(), rest.origin)
	_attachments[bone] = holder
	return holder


## Box relativ zum Knochenursprung (Modellraum).
func _local_box(bone: String) -> AABB:
	var boxes := _bounds(model_name)
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	var skel_to_model := model.transform.affine_inverse() * _skeleton_to_model_root()
	var origin := skel_to_model * rest.origin
	var box: AABB = boxes.get(bone, AABB(origin, Vector3(0.3, 0.3, 0.3)))
	return AABB(box.position - origin, box.size)


func _add(holder: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	holder.add_child(mi)
	_extras.append(mi)
	return mi


# ── Aussehen ───────────────────────────────────────────────
## look: Slot -> ItemDef (oder null)
func apply_look(look: Dictionary) -> void:
	var outfit: ItemDef = look.get(&"outfit")
	var bodies: Array = BODIES.get(outfit.variant if outfit else &"tee", BODIES[&"tee"])
	var previous := model_name
	set_model(bodies[clampi(body_type, 0, 1)])
	if previous == model_name:
		for e in _extras:
			if is_instance_valid(e):
				e.queue_free()
		_extras.clear()
	var skin: ItemDef = look.get(&"skin")
	var skin_color := skin.color if skin else Color("e0ac8a")
	var skin_mat := _mat(skin_color, 0.6, 0.85 if skin and skin.variant == &"metal" else 0.0, 1.2 if skin and skin.variant == &"glow" else 0.0)
	var primary := outfit.color if outfit else Color("60a5fa")
	var secondary := outfit.accent_color if outfit else Color("374151")
	_paint(skin_mat, primary, secondary)
	_build_hair(look.get(&"hair"))
	_build_shoes(look.get(&"shoes"))
	_build_accessory(look.get(&"accessory"))
	_build_gadget(look.get(&"gadget"))


## Zufälliger Passant: Modell behält Haare/Hut, Farben leicht variiert.
func apply_npc(model_id: String, rng: RandomNumberGenerator) -> void:
	set_model(model_id, true)
	var tones := [Color("f1c7a5"), Color("e0ac8a"), Color("c68863"), Color("8d5a3b"), Color("5b3a29")]
	var skin_mat := _mat(tones[rng.randi() % tones.size()], 0.6)
	var primary := Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.7), rng.randf_range(0.45, 0.9))
	var secondary := Color.from_hsv(rng.randf(), rng.randf_range(0.1, 0.4), rng.randf_range(0.15, 0.5))
	_paint(skin_mat, primary, secondary, model_id.begins_with("Suit") or model_id.begins_with("Chef") or model_id.begins_with("Doctor"))
	_build_shoes(null)


func _paint(skin_mat: Material, primary: Color, secondary: Color, keep_clothes := false) -> void:
	var mesh := body_mesh.mesh
	for s in mesh.get_surface_count():
		var sname: String = (mesh as ArrayMesh).surface_get_name(s)
		var mat: Material = null
		if sname == "Skin":
			mat = skin_mat
		elif keep_clothes:
			mat = null
		elif sname in PRIMARY:
			# Anzug: „Black“ ist der Anzug, „Shirt“ bleibt hell
			if model_name.begins_with("Suit") and sname == "Shirt":
				mat = _mat(Color("f1f5f9"))
			else:
				mat = _mat(primary, 0.8)
		elif sname in SECONDARY:
			mat = _mat(secondary, 0.85)
		body_mesh.set_surface_override_material(s, mat)


func _build_hair(item: ItemDef) -> void:
	var variant: StringName = item.variant if item else &"short"
	var color := item.color if item else Color("2b1b0e")
	if HAIR_DONORS.has(variant):
		_donor_part(HAIR_DONORS[variant], HAIR_SURFACES, color)
		return
	var head := _local_box("Head")
	var h := _holder("Head")
	var top := Vector3(head.get_center().x, head.end.y, head.get_center().z)
	var mat := _mat(color, 0.9)
	match variant:
		&"afro":
			var s := SphereMesh.new()
			s.radius = head.size.x * 0.62
			s.height = head.size.y * 0.95
			_add(h, s, mat, top - Vector3(0, head.size.y * 0.22, 0.02))
		&"mohawk":
			for i in 5:
				var b := BoxMesh.new()
				b.size = Vector3(0.06, 0.14 + 0.05 * (2 - absi(i - 2)), 0.1)
				_add(h, b, mat, top + Vector3(0, 0.02, -head.size.z * 0.35 + i * head.size.z * 0.17), Vector3(-0.2 + i * 0.1, 0, 0))
			var cap := SphereMesh.new()
			cap.radius = head.size.x * 0.5
			cap.height = head.size.y * 0.5
			_add(h, cap, _mat(color.darkened(0.3), 0.9), top - Vector3(0, head.size.y * 0.2, 0))


func _build_shoes(item: ItemDef) -> void:
	var color := item.color if item else Color("1f2937")
	var sole := item.accent_color if item else Color("e5e7eb")
	var high := item != null and item.variant == &"hightop"
	for side in ["Foot.L", "Foot.R"]:
		var foot := _local_box(side)
		var h := _holder(side)
		var c := foot.get_center()
		# abgerundeter Schuh, der den Fuß umschließt (statt Klotz darunter)
		var shoe := CapsuleMesh.new()
		shoe.radius = maxf(foot.size.x, foot.size.y) * 0.62
		shoe.height = maxf(foot.size.z * 1.25, shoe.radius * 2.2)
		shoe.radial_segments = 12
		shoe.rings = 4
		_add(h, shoe, _mat(color, 0.55), c + Vector3(0, foot.size.y * 0.05, foot.size.z * 0.06), Vector3(PI / 2, 0, 0))
		var sole_mesh := CylinderMesh.new()
		sole_mesh.top_radius = shoe.radius * 1.02
		sole_mesh.bottom_radius = shoe.radius * 1.05
		sole_mesh.height = shoe.height * 0.98
		sole_mesh.radial_segments = 12
		var sole_mi := _add(h, sole_mesh, _mat(sole, 0.5), Vector3(c.x, foot.position.y + 0.02, c.z + foot.size.z * 0.06), Vector3(PI / 2, 0, 0))
		sole_mi.scale = Vector3(1.0, 1.0, 0.18) # flache Sohle
		if high:
			var cuff := CylinderMesh.new()
			cuff.top_radius = shoe.radius * 0.85
			cuff.bottom_radius = shoe.radius * 0.95
			cuff.height = foot.size.y * 0.9
			_add(h, cuff, _mat(color.darkened(0.15), 0.55), Vector3(c.x, foot.end.y + cuff.height * 0.3, c.z - foot.size.z * 0.15))


func _build_accessory(item: ItemDef) -> void:
	if item == null:
		return
	var head := _local_box("Head")
	var h := _holder("Head")
	var c := head.get_center()
	var top := Vector3(c.x, head.end.y, c.z)
	var front := head.end.z # Modelle schauen nach +Z
	var col := _mat(item.color, 0.5)
	var acc := _mat(item.accent_color, 0.4)
	match item.variant:
		&"cap":
			var dome := SphereMesh.new()
			dome.radius = head.size.x * 0.54
			dome.height = head.size.y * 0.55
			_add(h, dome, col, top - Vector3(0, head.size.y * 0.12, 0))
			var brim := BoxMesh.new()
			brim.size = Vector3(head.size.x * 0.75, 0.025, head.size.z * 0.45)
			_add(h, brim, acc, Vector3(c.x, top.y - head.size.y * 0.13, front - head.size.z * 0.02))
		&"shades":
			for side: float in [-1.0, 1.0]:
				var lens := BoxMesh.new()
				lens.size = Vector3(head.size.x * 0.3, head.size.y * 0.13, 0.02)
				_add(h, lens, _mat(Color("0f172a"), 0.1, 0.6), Vector3(c.x + side * head.size.x * 0.2, c.y + head.size.y * 0.02, front + 0.01))
			var bridge := BoxMesh.new()
			bridge.size = Vector3(head.size.x * 0.9, 0.025, 0.02)
			_add(h, bridge, acc, Vector3(c.x, c.y + head.size.y * 0.07, front + 0.012))
		&"chain":
			var torso := _local_box("Torso")
			var th := _holder("Torso")
			var ring := TorusMesh.new()
			ring.inner_radius = torso.size.x * 0.28
			ring.outer_radius = torso.size.x * 0.31
			_add(th, ring, _mat(item.color, 0.2, 1.0), Vector3(torso.get_center().x, torso.end.y - 0.03, torso.get_center().z + 0.03), Vector3(0.5, 0, 0))
			var pendant := SphereMesh.new()
			pendant.radius = 0.035
			pendant.height = 0.07
			_add(th, pendant, _mat(item.accent_color, 0.2, 0.0, 1.5), Vector3(torso.get_center().x, torso.end.y - torso.size.y * 0.35, torso.end.z + 0.02))
		&"crown":
			var band := CylinderMesh.new()
			band.top_radius = head.size.x * 0.33
			band.bottom_radius = head.size.x * 0.3
			band.height = 0.08
			var gold := _mat(item.color, 0.25, 1.0, 0.3)
			_add(h, band, gold, top + Vector3(0, 0.01, 0))
			for i in 6:
				var a := i * TAU / 6.0
				var spike := CylinderMesh.new()
				spike.top_radius = 0.0
				spike.bottom_radius = 0.025
				spike.height = 0.08
				_add(h, spike, gold, top + Vector3(cos(a) * head.size.x * 0.31, 0.09, sin(a) * head.size.x * 0.31))
		&"halo":
			var halo := TorusMesh.new()
			halo.inner_radius = head.size.x * 0.32
			halo.outer_radius = head.size.x * 0.38
			_add(h, halo, _mat(item.color, 0.2, 0.0, 2.5), top + Vector3(0, 0.12, 0))
		&"headphones":
			var band2 := TorusMesh.new()
			band2.inner_radius = head.size.x * 0.52
			band2.outer_radius = head.size.x * 0.57
			_add(h, band2, col, Vector3(c.x, c.y + head.size.y * 0.05, c.z), Vector3(0, 0, PI / 2))
			for side: float in [-1.0, 1.0]:
				var cup := CylinderMesh.new()
				cup.top_radius = head.size.y * 0.16
				cup.bottom_radius = head.size.y * 0.16
				cup.height = 0.06
				_add(h, cup, acc, Vector3(c.x + side * head.size.x * 0.53, c.y, c.z), Vector3(0, 0, PI / 2))
		&"horns":
			for side: float in [-1.0, 1.0]:
				var horn := CylinderMesh.new()
				horn.top_radius = 0.0
				horn.bottom_radius = 0.045
				horn.height = 0.18
				_add(h, horn, col, top + Vector3(side * head.size.x * 0.28, 0.02, 0), Vector3(0, 0, -side * 0.45))


func _build_gadget(item: ItemDef) -> void:
	var hand := _local_box("Fist.R")
	var h := _holder("Fist.R")
	var c := hand.get_center() + Vector3(0, 0, hand.size.z * 0.3)
	var tip_offset := Vector3(0, 0.12, 0)
	if item:
		var col := _mat(item.color, 0.35, 0.3)
		var glow := _mat(item.accent_color, 0.3, 0.0, 2.2)
		match item.variant:
			&"pen", &"wand":
				var body := CylinderMesh.new()
				body.top_radius = 0.018
				body.bottom_radius = 0.022
				body.height = 0.2 if item.variant == &"pen" else 0.3
				_add(h, body, col, c + Vector3(0, body.height * 0.4, 0))
				var tip := SphereMesh.new()
				tip.radius = 0.025
				tip.height = 0.05
				_add(h, tip, glow, c + Vector3(0, body.height * 0.9, 0))
				tip_offset = Vector3(0, body.height * 0.9, 0)
			&"box":
				var b := BoxMesh.new()
				b.size = Vector3(0.08, 0.13, 0.05)
				_add(h, b, col, c + Vector3(0, 0.05, 0))
				var screen := BoxMesh.new()
				screen.size = Vector3(0.06, 0.05, 0.005)
				_add(h, screen, glow, c + Vector3(0, 0.08, 0.026))
				tip_offset = Vector3(0, 0.13, 0)
			&"orb":
				var orb := SphereMesh.new()
				orb.radius = 0.06
				orb.height = 0.12
				_add(h, orb, glow, c + Vector3(0, 0.08, 0))
				tip_offset = Vector3(0, 0.1, 0)
	# Ursprung für Effekte an der Gadget-Spitze
	if gadget_tip.get_parent():
		gadget_tip.get_parent().remove_child(gadget_tip)
	h.add_child(gadget_tip)
	gadget_tip.position = c + tip_offset

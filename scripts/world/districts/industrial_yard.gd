class_name IndustrialYard
extends RefCounted
## GRAFFITI YARD (Westen): Lagerhallen, Schornsteine, Gleise, Graffiti-Wände, harte Challenges.

const CENTER := Vector3(-330, 0, 0)


static func build(root: Node3D) -> void:
	var c := CENTER
	WorldKit.box(root, Vector3(130, 0.04, 140), c + Vector3(0, 0.02, 0), WorldKit.surface(&"concrete", Color(0.6, 0.6, 0.62)), false)
	WorldKit.district_area(root, &"industrial", c + Vector3(0, 10, 0), Vector3(130, 24, 140))
	DistrictBuilder.gate(root, Vector3(-262, 0, 0), PI / 2, "Graffiti Yard", 4)
	WorldKit.sign_text(root, c + Vector3(0, 16, -62), "GRAFFITI YARD", Color("a3e635"), 320)
	# Lagerhallen
	for i in 6:
		var side := -1 if i < 3 else 1
		var p := c + Vector3(-40 + (i % 3) * 40, 0, side * 46)
		WorldKit.building(root, p, Vector3(30, randf_range(12, 18), 22), Color("52525b"))
	# Schornsteine mit Rauch
	for i in 3:
		var p := c + Vector3(-45 + i * 45, 0, -62)
		WorldKit.cylinder(root, 2.0, 34, p + Vector3(0, 17, 0), WorldKit.mat(Color("7f1d1d"), 0.9))
		var smoke := CPUParticles3D.new()
		smoke.position = p + Vector3(0, 35, 0)
		smoke.amount = 16
		smoke.lifetime = 6.0
		smoke.direction = Vector3(0.3, 1, 0)
		smoke.spread = 20.0
		smoke.initial_velocity_min = 1.5
		smoke.initial_velocity_max = 2.5
		smoke.scale_amount_min = 3.0
		smoke.scale_amount_max = 6.0
		smoke.gravity = Vector3.ZERO
		var puff := SphereMesh.new()
		puff.radius = 0.5
		puff.height = 1.0
		puff.radial_segments = 6
		puff.rings = 3
		smoke.mesh = puff
		smoke.material_override = WorldKit.mat(Color(0.55, 0.55, 0.58), 1.0)
		root.add_child(smoke)
	# Gleise quer durchs Gelände
	var steel := WorldKit.mat(Color("9ca3af"), 0.3, 1.0)
	for z: float in [-0.75, 0.75]:
		WorldKit.box(root, Vector3(130, 0.15, 0.12), c + Vector3(0, 0.1, 22 + z), steel, false)
	for i in 33:
		WorldKit.box(root, Vector3(0.5, 0.1, 2.4), c + Vector3(-64 + i * 4, 0.05, 22), WorldKit.mat(Color("57534e")), false)
	# Graffiti-Wände (Parkour-Mauern in Stufen)
	var tags := ["AURA!", "NO NPC", "SIGMA", "CLOUD KINGZ", "STAY GLOWING"]
	var tag_cols := [Color("a3e635"), Color("f472b6"), Color("22d3ee"), Color("facc15"), Color("fb923c")]
	for i in tags.size():
		var w := c + Vector3(-36 + i * 18, 0, -10)
		var h := 1.0 + i * 0.8
		WorldKit.box(root, Vector3(14, h, 1.2), w + Vector3(0, h / 2.0, 0), WorldKit.mat(Color("71717a")))
		WorldKit.sign_text(root, w + Vector3(0, h * 0.5, 0.7), tags[i], tag_cols[i], 140)
	DistrictBuilder.secret_shard(root, &"secret_yard_wall", c + Vector3(-36 + 4 * 18, 1.0 + 4 * 0.8, -10))
	for i in 10:
		WorldKit.street_light(root, c + Vector3(-60 + i * 13, 0, 8), Color("fef08a"))
	DistrictBuilder.shop(root, "Yard Supply", c + Vector3(-10, 0, 4), 3, 5, Color("a3e635"))
	DistrictBuilder.challenge(root, c + Vector3(10, 0, 4), "Graffiti-Run", "score", 12000, 55.0, 12000, Color("a3e635"))
	DistrictBuilder.challenge(root, c + Vector3(28, 0, 4), "Schicht-Combo", "combo", 9, 45.0, 11000, Color("f472b6"))
	DistrictBuilder.challenge(root, c + Vector3(46, 0, 4), "Stahl-Präzision", "perfects", 9, 55.0, 12000, Color("22d3ee"))
	for i in 4:
		DistrictBuilder.npc(root, ["Spray Sam", "Rusty", "Bolt", "Neon Nico"][i], c + Vector3(randf_range(-30, 30), 0, randf_range(-6, 18)), PackedStringArray(["Die Mauern werden immer höher – ganz oben liegt was.", "Yard Supply verkauft Epic bis Mythic.", "Hier zählt nur Präzision."]), 14.0, &"work")
	DistrictBuilder.shards(root, "yard", c + Vector3(0, 0, 8), 7, 24.0, 400)
	DistrictBuilder.teleporter(root, c + Vector3(55, 0, 14), "Spawn City", Vector3(0, 1, 26))

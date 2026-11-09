class_name LuxuryDistrict
extends RefCounted
## LUXURY DISTRICT: Marmor, Gold, Türme, Exklusiv-Shop und High-End-Challenges.

const CENTER := Vector3(0, 0, -130)


static func build(root: Node3D) -> void:
	var c := CENTER
	WorldKit.box(root, Vector3(76, 0.04, 76), c + Vector3(0, 0.02, 0), WorldKit.mat(Color("f5f5f4"), 0.25, 0.1), false)
	WorldKit.district_area(root, &"luxury", c + Vector3(0, 5, 0), Vector3(80, 14, 80))
	DistrictBuilder.gate(root, Vector3(0, 0, -62), 0.0, "Luxury District", 3)
	WorldKit.sign_text(root, c + Vector3(0, 14, -32), "LUXURY DISTRICT", Color("fbbf24"), 320)
	var gold := WorldKit.mat(Color("fbbf24"), 0.2, 1.0, 0.2)
	# Goldener Brunnen
	WorldKit.cylinder(root, 5.0, 0.8, c + Vector3(0, 0.4, 0), WorldKit.mat(Color("e7e5e4"), 0.2))
	WorldKit.cylinder(root, 0.7, 4.0, c + Vector3(0, 2.4, 0), gold)
	WorldKit.cylinder(root, 1.6, 0.3, c + Vector3(0, 4.5, 0), gold, false)
	# Türme
	for i in 6:
		var side := -1 if i < 3 else 1
		var p := c + Vector3(-24 + (i % 3) * 24, 0, side * 27)
		WorldKit.building(root, p, Vector3(10, randf_range(30, 46), 10), Color("e7e5e4"), Color("fde68a"))
		WorldKit.box(root, Vector3(10.6, 0.5, 10.6), p + Vector3(0, 1.5, 0), gold, false)
	for i in 8:
		WorldKit.street_light(root, c + Vector3(-28 + i * 8, 0, -14), Color("fde68a"))
		WorldKit.tree(root, c + Vector3(-28 + i * 8, 0, 14), 0.9)
	DistrictBuilder.shop(root, "Maison Aura", c + Vector3(-12, 0, -8), 4, 5, Color("fbbf24"))
	DistrictBuilder.challenge(root, c + Vector3(12, 0, -8), "Champagner-Combo", "combo", 10, 45.0, 25000, Color("fbbf24"))
	DistrictBuilder.challenge(root, c + Vector3(12, 0, 8), "Elite-Score", "score", 20000, 60.0, 30000, Color("fde68a"))
	for i in 4:
		DistrictBuilder.npc(root, ["Lady Lux", "Mr. Money", "Gold Gigi", "Baron B."][i], c + Vector3(randf_range(-18, 18), 0, randf_range(-12, 12)), PackedStringArray(["Darling, ohne Legendary-Fit lass ich dich nicht rein.", "Maison Aura führt nur das Beste.", "Godlike? Davon träumen hier alle."]), 12.0)
	DistrictBuilder.shards(root, "luxury", c, 5, 26.0, 300)
	DistrictBuilder.teleporter(root, c + Vector3(0, 0, 30), "Spawn City", Vector3(0, 1, 26))

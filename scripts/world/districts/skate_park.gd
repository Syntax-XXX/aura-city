class_name SkatePark
extends RefCounted
## SKATE PARK: Rampen, Rails, Funbox, drei Trick-Challenges.

const CENTER := Vector3(120, 0, 0)


static func build(root: Node3D) -> void:
	var c := CENTER
	var concrete := WorldKit.mat(Color("a8a29e"), 0.95)
	WorldKit.box(root, Vector3(76, 0.04, 76), c + Vector3(0, 0.02, 0), concrete, false)
	WorldKit.district_area(root, &"skate", c + Vector3(0, 5, 0), Vector3(80, 14, 80))
	WorldKit.sign_text(root, c + Vector3(0, 9, -30), "SKATE PARK", Color("f97316"), 300)
	var ramp_mat := WorldKit.mat(Color("d6d3d1"), 0.7)
	var edge := WorldKit.mat(Color("f97316"), 0.4, 0.3, 0.6)
	# Quarterpipes (schräge Boxen) an beiden Seiten
	for side in [-1, 1]:
		for i in 3:
			var p := c + Vector3(side * 26, 1.6, -14 + i * 14)
			WorldKit.box(root, Vector3(6, 0.4, 10), p, ramp_mat, true, Vector3(0, 0, side * 0.55))
			WorldKit.box(root, Vector3(0.3, 0.3, 10), p + Vector3(side * 2.6, 1.6, 0), edge, false)
	# Kicker-Rampen
	for i in 4:
		var p := c + Vector3(-12 + i * 8, 0.6, 10)
		WorldKit.box(root, Vector3(3, 0.3, 4), p, ramp_mat, true, Vector3(0.32, 0, 0))
	# Rails
	for i in 3:
		var p := c + Vector3(-10 + i * 10, 0.7, -6)
		WorldKit.box(root, Vector3(0.14, 0.14, 9), p, WorldKit.mat(Color("cbd5e1"), 0.2, 1.0), true)
		for z in [-4.0, 4.0]:
			WorldKit.box(root, Vector3(0.1, 0.7, 0.1), p + Vector3(0, -0.35, z), WorldKit.mat(Color("475569")), false)
	# Funbox in der Mitte
	WorldKit.box(root, Vector3(8, 1.0, 6), c + Vector3(0, 0.5, -18), ramp_mat)
	WorldKit.box(root, Vector3(3, 0.3, 6), c + Vector3(-5.2, 0.45, -18), ramp_mat, true, Vector3(0, 0, 0.35))
	WorldKit.box(root, Vector3(3, 0.3, 6), c + Vector3(5.2, 0.45, -18), ramp_mat, true, Vector3(0, 0, -0.35))
	for i in 8:
		WorldKit.street_light(root, c + Vector3(-32 + i * 9, 0, 32))
	DistrictBuilder.challenge(root, c + Vector3(-14, 0, 22), "Kickflip-Kette", "combo", 4, 30.0, 900, Color("f97316"))
	DistrictBuilder.challenge(root, c + Vector3(0, 0, 22), "Highscore-Run", "score", 1500, 45.0, 1200, Color("facc15"))
	DistrictBuilder.challenge(root, c + Vector3(14, 0, 22), "Präzision", "perfects", 4, 40.0, 1400, Color("22d3ee"))
	for i in 4:
		DistrictBuilder.npc(root, ["Skater Sky", "Rail Ray", "Ollie Olli", "Kick Kim"][i], c + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20)), PackedStringArray(["Combo-Ketten bringen hier am meisten.", "Die Präzisions-Challenge ist brutal.", "Perfect-Landungen geben 50 % mehr!"]), 16.0)
	DistrictBuilder.shards(root, "skate", c, 6, 30.0, 60)
	DistrictBuilder.info(root, c + Vector3(-20, 0, 28), "Skate-Regeln", PackedStringArray(["Starte eine Challenge im leuchtenden Ring mit [E].", "Während einer Challenge gibt jeder Trick ×1,5 Aura.", "Kombiniere Tricks für Ketten-Boni – siehe Trickbuch [K]."]))
	DistrictBuilder.teleporter(root, c + Vector3(0, 0, 30), "Spawn City", Vector3(0, 1, 26))

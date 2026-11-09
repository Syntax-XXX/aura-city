class_name Harbor
extends RefCounted
## HAFEN (Süden): Container-Labyrinth zum Klettern, Kräne, Leuchtturm, Boote, Kletterturm mit Geheimnis.

const CENTER := Vector3(0, 0, 300)


static func build(root: Node3D) -> void:
	var c := CENTER
	WorldKit.box(root, Vector3(150, 0.04, 84), c + Vector3(0, 0.02, -10), WorldKit.surface(&"concrete", Color(0.8, 0.82, 0.85)), false)
	WorldKit.district_area(root, &"harbor", c + Vector3(0, 8, -8), Vector3(150, 20, 90))
	WorldKit.sign_text(root, c + Vector3(0, 13, -50), "HAFEN", Color("38bdf8"), 320)
	# Wasser, Kaimauer und unsichtbare Kante
	WorldKit.box(root, Vector3(440, 0.2, 120), c + Vector3(0, 0.06, 92), WorldKit.water(), false)
	WorldKit.box(root, Vector3(150, 1.0, 1.2), c + Vector3(0, 0.5, 32), WorldKit.mat(Color("44403c")))
	WorldKit.invisible_wall(root, Vector3(440, 12, 1), c + Vector3(0, 6, 33.2))
	for i in 15:
		WorldKit.cylinder(root, 0.35, 0.8, c + Vector3(-70 + i * 10, 1.4, 31.4), WorldKit.mat(Color("1c1917")), false)
	# Container-Labyrinth (1–3 hoch) – oben liegen Splitter
	var cols := [Color("dc2626"), Color("2563eb"), Color("16a34a"), Color("ea580c"), Color("7c3aed"), Color("0891b2")]
	for row in 3:
		for i in 7:
			var p := c + Vector3(-54 + i * 18, 0, -42 + row * 11)
			var h := 1 + (i + row) % 3
			for level in h:
				WorldKit.box(root, Vector3(12, 2.6, 4.8), p + Vector3(0, 1.3 + level * 2.6, 0), WorldKit.mat(cols[(i * 3 + row + level) % cols.size()], 0.6, 0.4))
	# Kräne
	var yellow := WorldKit.mat(Color("facc15"), 0.5, 0.5)
	for x: float in [-40.0, 40.0]:
		WorldKit.box(root, Vector3(2, 26, 2), c + Vector3(x, 13, 22), yellow)
		WorldKit.box(root, Vector3(2, 2, 34), c + Vector3(x, 26, 30), yellow, false)
		WorldKit.box(root, Vector3(0.2, 12, 0.2), c + Vector3(x, 19, 44), WorldKit.mat(Color("1f2937")), false)
	# Kletterturm (Wendeltreppe) neben dem Kran – oben ein geheimer Splitter
	var tower := c + Vector3(55, 0, 8)
	WorldKit.cylinder(root, 1.4, 12.0, tower + Vector3(0, 6, 0), WorldKit.mat(Color("57534e")))
	var top := WorldKit.spiral_stairs(root, tower, 13, 0.85, 3.4, WorldKit.mat(Color("78716c"), 0.9))
	DistrictBuilder.secret_shard(root, &"secret_harbor_tower", top + Vector3(0, 0.1, 0))
	# Leuchtturm + Boote
	var light_pos := c + Vector3(-66, 0, 24)
	WorldKit.cylinder(root, 2.2, 18, light_pos + Vector3(0, 9, 0), WorldKit.mat(Color("f8fafc")))
	WorldKit.cylinder(root, 2.3, 2.0, light_pos + Vector3(0, 6, 0), WorldKit.mat(Color("dc2626")), false)
	WorldKit.cylinder(root, 1.4, 2.0, light_pos + Vector3(0, 19, 0), WorldKit.mat(Color("fde68a"), 0.2, 0.0, 3.0), false)
	for i in 3:
		var b := c + Vector3(-30 + i * 30, 0.6, 52 + (i % 2) * 14)
		WorldKit.box(root, Vector3(5, 1.6, 14), b, WorldKit.mat([Color("f8fafc"), Color("1e3a8a"), Color("b91c1c")][i], 0.5), false)
		WorldKit.box(root, Vector3(3.6, 2.4, 4), b + Vector3(0, 1.9, -2), WorldKit.mat(Color("e5e7eb")), false)
	for i in 10:
		WorldKit.street_light(root, c + Vector3(-63 + i * 14, 0, 26), Color("bae6fd"))
	DistrictBuilder.shop(root, "Dock Deals", c + Vector3(-20, 0, 10), 1, 3, Color("38bdf8"))
	DistrictBuilder.challenge(root, c + Vector3(0, 0, 12), "Container-Combo", "combo", 7, 40.0, 6000, Color("ea580c"))
	DistrictBuilder.challenge(root, c + Vector3(16, 0, 12), "Hafen-Highscore", "score", 8000, 50.0, 7000, Color("38bdf8"))
	DistrictBuilder.challenge(root, c + Vector3(32, 0, 12), "Möwen-Präzision", "perfects", 7, 45.0, 6500, Color("f8fafc"))
	for i in 4:
		DistrictBuilder.npc(root, ["Kapitän Kai", "Docker Dana", "Fischer Fritz", "Möwen-Mia"][i], c + Vector3(-30 + i * 18, 0, 0), PackedStringArray(["Oben auf den Containern liegt mehr als Rost.", "Der Turm am Kran? Nur für Schwindelfreie.", "Bei Dock Deals gibt's solide Fits für wenig Aura."]), 14.0)
	DistrictBuilder.shards(root, "harbor", c + Vector3(0, 0, 8), 6, 22.0, 150)
	# Splitter auf drei Containerstapeln, jeweils mit Kistentreppe daneben (Belohnung fürs Klettern)
	var crate := WorldKit.mat(Color("a16207"), 0.9)
	for i in 3:
		var col_i := i * 2 + 1
		var stack := c + Vector3(-54 + col_i * 18, 0, -31)
		var height := 2.6 * (1 + (col_i + 1) % 3)
		var steps := ceili(height / 0.85)
		for k in steps:
			var h := minf(0.85 * (k + 1), height)
			WorldKit.box(root, Vector3(1.2, h, 1.8), stack + Vector3(-5.4 + k * 1.15, h / 2.0, 3.5), crate)
		var shard := Collectible.new()
		shard.collectible_id = StringName("harbor_top_%d" % i)
		shard.reward = 300
		DistrictBuilder.place(root, shard, stack + Vector3(3, height, 0))
	DistrictBuilder.info(root, c + Vector3(-36, 0, 14), "Hafenordnung", PackedStringArray(["Betreten der Container auf eigene Gefahr.", "Kistentreppen führen auf manche Container.", "Rückfahrt zum Spawn: Teleporter am Kai."]))
	DistrictBuilder.teleporter(root, c + Vector3(-50, 0, 12), "Spawn City", Vector3(0, 1, 26))

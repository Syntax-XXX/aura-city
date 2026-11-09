class_name SunsetBeach
extends RefCounted
## SUNSET BEACH (Osten): Sand, Meer, Palmen, Boardwalk, Rettungsturm, Beach-Shop.

const CENTER := Vector3(330, 0, 0)


static func build(root: Node3D) -> void:
	var c := CENTER
	WorldKit.box(root, Vector3(110, 0.05, 160), c + Vector3(10, 0.03, 0), WorldKit.surface(&"sand"), false)
	WorldKit.district_area(root, &"beach", c + Vector3(0, 8, 0), Vector3(120, 20, 160))
	DistrictBuilder.gate(root, Vector3(262, 0, 0), PI / 2, "Sunset Beach", 2)
	WorldKit.sign_text(root, c + Vector3(-20, 12, -60), "SUNSET BEACH", Color("fb923c"), 320)
	# Meer im Osten (nicht begehbar)
	WorldKit.box(root, Vector3(60, 0.2, 440), c + Vector3(80, 0.07, 0), WorldKit.water(), false)
	WorldKit.invisible_wall(root, Vector3(1, 12, 440), c + Vector3(51, 6, 0))
	# Boardwalk aus Holz mit Geländer
	var wood := WorldKit.surface(&"wood")
	WorldKit.box(root, Vector3(8, 0.5, 150), c + Vector3(-36, 0.25, 0), wood)
	for i in 16:
		WorldKit.street_light(root, c + Vector3(-39, 0.5, -70 + i * 9.5), Color("fdba74"))
	# Palmen, Schirme, Liegen
	for i in 18:
		WorldKit.palm(root, c + Vector3(randf_range(-25, 40), 0, -70 + i * 8.0), randf_range(0.8, 1.2))
	var umbrella_cols := [Color("ef4444"), Color("3b82f6"), Color("22c55e"), Color("eab308"), Color("ec4899")]
	for i in 10:
		var u := c + Vector3(randf_range(5, 40), 0, -60 + i * 12)
		WorldKit.cylinder(root, 0.06, 2.6, u + Vector3(0, 1.3, 0), WorldKit.mat(Color("e5e7eb")), false)
		WorldKit.cylinder(root, 1.8, 0.15, u + Vector3(0, 2.6, 0), WorldKit.mat(umbrella_cols[i % umbrella_cols.size()]), false)
		WorldKit.box(root, Vector3(0.8, 0.25, 2.0), u + Vector3(1.4, 0.3, 0), WorldKit.mat(Color("f8fafc")))
	# Rettungsturm (begehbar über Treppe) – oben ein geheimer Splitter
	var tower := c + Vector3(20, 0, 30)
	for x: float in [-1.5, 1.5]:
		for z: float in [-1.5, 1.5]:
			WorldKit.box(root, Vector3(0.3, 5, 0.3), tower + Vector3(x, 2.5, z), wood, false)
	WorldKit.box(root, Vector3(4, 0.3, 4), tower + Vector3(0, 5, 0), wood)
	WorldKit.box(root, Vector3(4, 2.2, 0.15), tower + Vector3(0, 6.2, -2), WorldKit.mat(Color("dc2626")), false)
	for k in 6:
		WorldKit.box(root, Vector3(1.4, 0.85 * (k + 1), 1.0), tower + Vector3(-2.7, 0.425 * (k + 1), 2.6 - k * 1.0), wood)
	DistrictBuilder.secret_shard(root, &"secret_beach_tower", tower + Vector3(0, 5.2, 0))
	# Volleyballnetz
	WorldKit.box(root, Vector3(0.1, 1.0, 9), c + Vector3(20, 2.0, -30), WorldKit.mat(Color("f8fafc"), 0.9), false)
	for z: float in [-4.5, 4.5]:
		WorldKit.cylinder(root, 0.08, 2.6, c + Vector3(20, 1.3, -30 + z), WorldKit.mat(Color("6b7280")))
	DistrictBuilder.shop(root, "Beach Drip", c + Vector3(-25, 0, -20), 1, 3, Color("fb923c"))
	DistrictBuilder.challenge(root, c + Vector3(-20, 0, 10), "Sunset-Session", "combo", 8, 45.0, 8000, Color("fb923c"))
	DistrictBuilder.challenge(root, c + Vector3(-20, 0, 30), "Strand-Perfekt", "perfects", 8, 50.0, 8000, Color("fde047"))
	DistrictBuilder.challenge(root, c + Vector3(-20, 0, 50), "Wellenreiter", "score", 10000, 55.0, 9000, Color("38bdf8"))
	for i in 5:
		DistrictBuilder.npc(root, ["Surfer Sam", "Lifeguard Lia", "DJ Wave", "Coco", "Sunny"][i], c + Vector3(randf_range(-15, 30), 0, randf_range(-50, 50)), PackedStringArray(["Sonnenuntergang = beste Aura.", "Der Rettungsturm hat oben was Glitzerndes.", "Beach Drip hat die chilligsten Fits."]), 18.0)
	DistrictBuilder.shards(root, "beach", c + Vector3(-5, 0, 0), 8, 40.0, 200)
	DistrictBuilder.teleporter(root, c + Vector3(-28, 0, -40), "Spawn City", Vector3(0, 1, 26))

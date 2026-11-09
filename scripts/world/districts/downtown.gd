class_name Downtown
extends RefCounted
## DOWNTOWN SKYLINE (Norden): Wolkenkratzer-Raster, Aura-Statue, Treppenturm mit Dach-Geheimnis.

const CENTER := Vector3(0, 0, -330)


static func build(root: Node3D) -> void:
	var c := CENTER
	WorldKit.box(root, Vector3(150, 0.04, 140), c + Vector3(0, 0.02, 0), WorldKit.mat(Color("1f2937"), 0.6), false)
	WorldKit.district_area(root, &"downtown", c + Vector3(0, 12, 0), Vector3(150, 30, 140))
	DistrictBuilder.gate(root, Vector3(0, 0, -262), 0.0, "Downtown Skyline", 5)
	WorldKit.sign_text(root, c + Vector3(0, 20, -66), "DOWNTOWN SKYLINE", Color("22d3ee"), 340)
	# Wolkenkratzer im Raster mit Straßen dazwischen
	var glass := [Color("1e3a5f"), Color("334155"), Color("0f172a"), Color("3b0764")]
	for gx in 5:
		for gz in 4:
			if gx == 2 and gz in [1, 2]:
				continue # Platz in der Mitte frei
			var p := c + Vector3(-56 + gx * 28, 0, -48 + gz * 30)
			WorldKit.building(root, p, Vector3(16, randf_range(40, 90), 16), glass[(gx + gz) % glass.size()], Color("67e8f9") if (gx + gz) % 2 == 0 else Color.TRANSPARENT)
	# Plaza mit Aura-Statue
	var gold := WorldKit.mat(Color("fbbf24"), 0.2, 1.0, 0.4)
	WorldKit.cylinder(root, 7.0, 0.6, c + Vector3(0, 0.3, 0), WorldKit.mat(Color("e5e7eb"), 0.3))
	WorldKit.box(root, Vector3(1.6, 6.0, 1.6), c + Vector3(0, 3.6, 0), gold)
	var halo := TorusMesh.new()
	halo.inner_radius = 2.4
	halo.outer_radius = 2.8
	var halo_mi := MeshInstance3D.new()
	halo_mi.mesh = halo
	halo_mi.material_override = WorldKit.mat(Color("22d3ee"), 0.2, 0.0, 3.0)
	halo_mi.position = c + Vector3(0, 8.0, 0)
	halo_mi.rotation.x = PI / 2
	root.add_child(halo_mi)
	# Treppenturm aufs Dach (Wendeltreppe), oben ein geheimer Splitter mit Aussicht
	var tower := c + Vector3(42, 0, 15)
	WorldKit.cylinder(root, 2.0, 22.0, tower + Vector3(0, 11, 0), WorldKit.mat(Color("475569")))
	var top := WorldKit.spiral_stairs(root, tower, 26, 0.85, 4.2, WorldKit.mat(Color("94a3b8"), 0.6, 0.3))
	DistrictBuilder.secret_shard(root, &"secret_skyline_roof", top + Vector3(0, 0.1, 0))
	for i in 12:
		WorldKit.street_light(root, c + Vector3(-66 + i * 12, 0, 22), Color("a5f3fc"))
	DistrictBuilder.shop(root, "Skyline Atelier", c + Vector3(-12, 0, 12), 4, 5, Color("22d3ee"))
	DistrictBuilder.challenge(root, c + Vector3(12, 0, 12), "Skyline-Combo", "combo", 12, 60.0, 60000, Color("22d3ee"))
	DistrictBuilder.challenge(root, c + Vector3(-12, 0, -12), "Wolkenkratzer-Score", "score", 50000, 70.0, 70000, Color("fbbf24"))
	DistrictBuilder.challenge(root, c + Vector3(12, 0, -12), "Elite-Präzision", "perfects", 12, 70.0, 65000, Color("e879f9"))
	for i in 5:
		DistrictBuilder.npc(root, ["Broker Ben", "CEO Cleo", "Influencer Ivy", "Max Mogul", "Skyler"][i], c + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)), PackedStringArray(["Hier oben zählt nur Sigma-Aura.", "Vom Treppenturm sieht man die ganze Stadt.", "Das Skyline Atelier führt Legendary und Mythic."]), 10.0)
	# Splitter auf den Straßen zwischen den Hochhäusern (nicht in Gebäuden)
	for i in 8:
		var shard := Collectible.new()
		shard.collectible_id = StringName("downtown_%d" % i)
		shard.reward = 800
		DistrictBuilder.place(root, shard, c + Vector3([-42.0, -14.0, 14.0, 42.0][i % 4], 0, -40.0 + floorf(i / 4.0) * 70.0))
	DistrictBuilder.teleporter(root, c + Vector3(0, 0, 24), "Spawn City", Vector3(0, 1, 26))

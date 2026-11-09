class_name NeonDistrict
extends RefCounted
## NEON DISTRICT: Nacht-Atmosphäre, Neonschilder, Premium-Shop, schwere Challenges, versteckte Gasse.

const CENTER := Vector3(-120, 0, 0)


static func build(root: Node3D) -> void:
	var c := CENTER
	WorldKit.box(root, Vector3(76, 0.04, 76), c + Vector3(0, 0.02, 0), WorldKit.mat(Color("18181b"), 0.4, 0.2), false)
	WorldKit.district_area(root, &"neon", c + Vector3(0, 5, 0), Vector3(80, 14, 80))
	DistrictBuilder.gate(root, Vector3(-62, 0, 0), PI / 2, "Neon District", 1)
	WorldKit.sign_text(root, c + Vector3(0, 12, -32), "NEON DISTRICT", Color("f472b6"), 320)
	var neons := [Color("f472b6"), Color("22d3ee"), Color("a855f7"), Color("4ade80"), Color("facc15")]
	for i in 10:
		var side := -1 if i < 5 else 1
		var p := c + Vector3(-28 + (i % 5) * 14, 0, side * 28)
		WorldKit.building(root, p, Vector3(10, randf_range(14, 30), 8), Color("1e1b2e"), neons[i % neons.size()])
	# Neon-Linien auf dem Boden + farbige Lichter (wenige, wegen Performance)
	for i in 6:
		WorldKit.box(root, Vector3(70, 0.03, 0.2), c + Vector3(0, 0.05, -15 + i * 6), WorldKit.mat(neons[i % neons.size()], 0.3, 0.0, 2.5), false)
	for i in 4:
		var light := OmniLight3D.new()
		light.position = c + Vector3(-22 + i * 15, 5, 0)
		light.light_color = neons[i]
		light.light_energy = 2.0
		light.omni_range = 16.0
		root.add_child(light)
	var signs := ["AURA BAR", "NEON NOODLES", "24/7", "CLOUD CLUB"]
	for i in signs.size():
		WorldKit.sign_text(root, c + Vector3(-24 + i * 16, 7, -23.5), signs[i], neons[i], 140)
	DistrictBuilder.shop(root, "Neon Boutique", c + Vector3(-8, 0, -14), 2, 4, Color("f472b6"))
	DistrictBuilder.challenge(root, c + Vector3(-18, 0, 8), "Neon-Rausch", "combo", 6, 35.0, 3500, Color("f472b6"))
	DistrictBuilder.challenge(root, c + Vector3(0, 0, 8), "Lichtgeschwindigkeit", "perfects", 6, 45.0, 4000, Color("22d3ee"))
	DistrictBuilder.challenge(root, c + Vector3(18, 0, 8), "Nachtschicht", "score", 5000, 50.0, 4500, Color("a855f7"))
	for i in 5:
		DistrictBuilder.npc(root, ["DJ Volt", "Nova", "Pixel", "Glitch", "Synth"][i], c + Vector3(randf_range(-20, 20), 0, randf_range(-18, 18)), PackedStringArray(["Nachts ist hier am meisten los.", "Die Boutique hat Epic- und Legendary-Fits.", "In der Gasse hinten soll's was Seltenes geben …"]), 15.0)
	DistrictBuilder.shards(root, "neon", c, 6, 28.0, 120)
	# Versteckte Gasse: geheimer Splitter + zweites Portal
	WorldKit.box(root, Vector3(4, 6, 0.4), c + Vector3(-34, 3, 18), WorldKit.mat(Color("27272a")))
	DistrictBuilder.secret_shard(root, &"secret_neon_alley", c + Vector3(-35.5, 0, 21))
	DistrictBuilder.teleporter(root, c + Vector3(-35.5, 0, 24), "", SecretDimension.CENTER + Vector3(0, 1.5, 12), 0, true)
	DistrictBuilder.teleporter(root, c + Vector3(26, 0, 0), "Spawn City", Vector3(0, 1, 26))

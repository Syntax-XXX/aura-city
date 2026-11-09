class_name SpawnCity
extends RefCounted
## SPAWN CITY: Startplatz, Tutorial, Starter-Shop, Bestenliste, Tagesbelohnung, Garderobe.

const CENTER := Vector3.ZERO


static func build(root: Node3D) -> void:
	WorldKit.box(root, Vector3(84, 0.04, 84), Vector3(0, 0.02, 0), WorldKit.surface(&"plaza", Color(0.85, 0.85, 0.88)), false)
	WorldKit.district_area(root, &"spawn", Vector3(0, 5, 0), Vector3(90, 14, 90))
	# Brunnen mit Statue (dahinter versteckt: Portal in die geheime Dimension)
	WorldKit.cylinder(root, 6.0, 0.8, Vector3(0, 0.4, 0), WorldKit.mat(Color("94a3b8"), 0.6))
	WorldKit.cylinder(root, 5.4, 0.12, Vector3(0, 0.82, 0), WorldKit.mat(Color("38bdf8"), 0.05, 0.3, 0.3), false)
	WorldKit.box(root, Vector3(1.2, 4.0, 1.2), Vector3(0, 2.8, 0), WorldKit.mat(Color("e2e8f0"), 0.4))
	var orb := WorldKit.cylinder(root, 0.8, 0.8, Vector3(0, 5.3, 0), WorldKit.mat(Color("c084fc"), 0.2, 0.0, 2.5), false)
	orb.rotation.x = PI / 2
	WorldKit.sign_text(root, Vector3(0, 8.5, 0), "AURA CITY", Color("c084fc"), 260, 0.0, true)
	WorldKit.box(root, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, -6.8), WorldKit.mat(Color("312e81"), 0.3, 0.0, 0.8), false)
	DistrictBuilder.teleporter(root, Vector3(0, 0, -7.1), "", SecretDimension.CENTER + Vector3(0, 1.5, 12), 0, true)
	# Gebäude rundum
	var colors := [Color("e5d3b3"), Color("c7b8a3"), Color("9fb4c7"), Color("d4a59a"), Color("b8c4a8")]
	for i in 8:
		var a := float(i) / 8.0 * TAU + PI / 8.0
		var p := Vector3(cos(a) * 36, 0, sin(a) * 36)
		if absf(p.x) < 12.0 or absf(p.z) < 12.0:
			continue
		WorldKit.building(root, p, Vector3(10, randf_range(9, 18), 10), colors[i % colors.size()])
	for i in 12:
		var a := float(i) / 12.0 * TAU
		WorldKit.street_light(root, Vector3(cos(a) * 14, 0, sin(a) * 14))
		if i % 3 == 0:
			WorldKit.bench(root, Vector3(cos(a + 0.25) * 11, 0, sin(a + 0.25) * 11), -a + PI / 2)
		if i % 2 == 0:
			WorldKit.tree(root, Vector3(cos(a + 0.5) * 22, 0, sin(a + 0.5) * 22), randf_range(0.8, 1.2))
	# Stationen
	DistrictBuilder.shop(root, "Starter Shop", Vector3(-18, 0, -16), 0, 2, Color("4ade80"))
	DistrictBuilder.station(root, &"leaderboard", "Bestenliste", Vector3(18, 0, -16), Color("facc15"))
	var board := LeaderboardBoard.new()
	DistrictBuilder.place(root, board, Vector3(18, 0, -19))
	DistrictBuilder.station(root, &"daily", "Tagesbelohnung", Vector3(-6, 0, 18), Color("f472b6"), true)
	DistrictBuilder.station(root, &"customize", "Garderobe", Vector3(6, 0, 18), Color("38bdf8"))
	DistrictBuilder.station(root, &"trickbook", "Trickbuch", Vector3(18, 0, 16), Color("c084fc"))
	DistrictBuilder.station(root, &"quests", "Quest-Board", Vector3(-18, 0, 16), Color("4ade80"))
	# Tutorial-Guide
	DistrictBuilder.npc(root, "Guide Gabi", Vector3(3, 0, 10), PackedStringArray([
		"Willkommen in AURA CITY! Hier zählt nur eins: Aura.",
		"Drück 1–4 für einen Trick. Dann läuft die Timing-Leiste – klick (oder F), wenn die Nadel in der Mitte ist.",
		"Mitte = PERFECT, grüne Zone = GOOD. Mehrere Tricks hintereinander = Combo-Multiplikator!",
		"Mit Aura kaufst du Kosmetik im Shop [B] und steigst im Rang auf. Höhere Ränge öffnen neue Distrikte.",
		"Tipp: Hinter dem Brunnen soll es manchmal seltsam leuchten …",
	]), 3.0)
	for i in 5:
		DistrictBuilder.npc(root, ["Lea", "Mo", "Sophie", "Jonas", "Emre"][i], Vector3(randf_range(-25, 25), 0, randf_range(-25, 25)), PackedStringArray(["Hast du schon die Skate-Park-Challenges probiert?", "Im Neon District gibt's die besseren Fits.", "Ich hab gehört, Godlike-Ränge leuchten richtig."]), 14.0)
	DistrictBuilder.challenge(root, Vector3(-10, 0, -4), "Erste Schritte", "perfects", 2, 40.0, 300, Color("4ade80"))
	DistrictBuilder.shards(root, "spawn", Vector3.ZERO, 6, 30.0)
	DistrictBuilder.info(root, Vector3(10, 0, 30), "Wegweiser", PackedStringArray(["Osten: Skate Park (offen) – weiter östlich Sunset Beach (ab Main Character)", "Westen: Neon District (ab Beginner) – dahinter Graffiti Yard (ab Aura Master)", "Norden: Luxury District (ab Street Legend) – dahinter Downtown Skyline (ab Sigma)", "Süden: Hafen (offen)", "Alle Ziele auch per Teleporter hier am Platz."]), PI)
	# Teleporter
	DistrictBuilder.teleporter(root, Vector3(-8, 0, 30), "Skate Park", SkatePark.CENTER + Vector3(0, 1, 24))
	DistrictBuilder.teleporter(root, Vector3(0, 0, 32), "Neon District", NeonDistrict.CENTER + Vector3(24, 1, 0), 1)
	DistrictBuilder.teleporter(root, Vector3(8, 0, 30), "Luxury District", LuxuryDistrict.ARRIVAL, 3)
	DistrictBuilder.teleporter(root, Vector3(-12, 0, 38), "Hafen", Harbor.CENTER + Vector3(-50, 1, 6))
	DistrictBuilder.teleporter(root, Vector3(-4, 0, 40), "Sunset Beach", SunsetBeach.CENTER + Vector3(-28, 1, -34), 2)
	DistrictBuilder.teleporter(root, Vector3(4, 0, 40), "Graffiti Yard", IndustrialYard.CENTER + Vector3(55, 1, 8), 4)
	DistrictBuilder.teleporter(root, Vector3(12, 0, 38), "Downtown Skyline", Downtown.CENTER + Vector3(0, 1, 18), 5)

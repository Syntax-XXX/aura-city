class_name SecretDimension
extends RefCounted
## SECRET DIMENSION: schwebende Plattformen im Nichts, geheime Splitter, geheimer Shop.
## Nur über versteckte Portale erreichbar (hinter dem Brunnen, Gasse im Neon District).

const CENTER := Vector3(0, 0, 420)


static func build(root: Node3D) -> void:
	var c := CENTER
	var void_mat := WorldKit.mat(Color("1e1b4b"), 0.3, 0.0, 0.6)
	var glow := WorldKit.mat(Color("a855f7"), 0.2, 0.0, 2.5)
	WorldKit.ground(root, Vector2(30, 30), c, void_mat)
	WorldKit.box(root, Vector3(30.4, 0.1, 30.4), c + Vector3(0, -0.6, 0), glow, false)
	WorldKit.district_area(root, &"secret", c + Vector3(0, 5, 0), Vector3(90, 30, 90))
	# Schwebende Plattformen mit Sprüngen
	var platforms := [Vector3(20, 2, 0), Vector3(28, 4, 10), Vector3(22, 6, 22), Vector3(8, 8, 28), Vector3(-8, 6, 26), Vector3(-22, 4, 14), Vector3(-20, 2, -2)]
	for p in platforms:
		WorldKit.ground(root, Vector2(6, 6), c + p, void_mat, 0.6)
		WorldKit.box(root, Vector3(6.2, 0.08, 6.2), c + p + Vector3(0, -0.35, 0), glow, false)
	WorldKit.sign_text(root, c + Vector3(0, 10, -14), "? ? ?", Color("e9d5ff"), 360, 0.0, true)
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var crystal := WorldKit.box(root, Vector3(0.8, 4, 0.8), c + Vector3(cos(a) * 12, 2, sin(a) * 12), glow, false)
		crystal.rotation = Vector3(0.3, a, 0.2)
	DistrictBuilder.secret_shard(root, &"secret_void_1", c + platforms[3] + Vector3(0, 0, 0))
	DistrictBuilder.secret_shard(root, &"secret_void_2", c + platforms[1])
	DistrictBuilder.secret_shard(root, &"secret_void_3", c + platforms[5])
	DistrictBuilder.shop(root, "Void Vendor", c + Vector3(0, 0, -6), 6, 6, Color("a855f7"))
	DistrictBuilder.npc(root, "The Watcher", c + Vector3(4, 0, 2), PackedStringArray(["Du hast den Weg gefunden.", "Wer hier war, trägt die Leere für immer bei sich.", "Der Void Vendor verkauft nur an Eingeweihte."]), 2.0)
	DistrictBuilder.teleporter(root, c + Vector3(0, 0, 10), "Spawn City", Vector3(0, 1, 26))
	# Unsichtbare Grenze, damit man nicht sofort ins Nichts fällt
	for side in [-1, 1]:
		WorldKit.box(root, Vector3(70, 30, 1), c + Vector3(0, 10, side * 36), StandardMaterial3D.new(), true).get_child(1).visible = false
		WorldKit.box(root, Vector3(1, 30, 70), c + Vector3(side * 36, 10, 0), StandardMaterial3D.new(), true).get_child(1).visible = false

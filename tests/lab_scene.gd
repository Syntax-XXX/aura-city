class_name LabScene
extends RefCounted
## Kleine Vorzeige-Szene mit allen neuen Materialien (schnell im Software-Rendering):
##   godot -- --lab <ordner>   (unter xvfb-run)

static func run(main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var tree := main.get_tree()
	var w := WorldRoot.new()
	w.lab_mode = true
	main.add_child(w)
	Settings.day_night_cycle = false
	# Straße, Gehweg, Platz, Sand, Wasser
	WorldKit.box(w, Vector3(60, 0.03, 9), Vector3(0, 0.015, 6), WorldKit.surface(&"asphalt"), false)
	WorldKit.box(w, Vector3(60, 0.12, 2.2), Vector3(0, 0.06, 11.6), WorldKit.surface(&"sidewalk"), false)
	WorldKit.box(w, Vector3(24, 0.04, 14), Vector3(-6, 0.02, -6), WorldKit.surface(&"plaza", Color(0.85, 0.85, 0.88)), false)
	WorldKit.box(w, Vector3(20, 0.05, 14), Vector3(20, 0.03, -6), WorldKit.surface(&"sand"), false)
	WorldKit.box(w, Vector3(40, 0.2, 30), Vector3(40, 0.06, -25), WorldKit.water(), false)
	WorldKit.building(w, Vector3(-18, 0, -22), Vector3(14, 30, 12), Color("334155"), Color("67e8f9"))
	WorldKit.building(w, Vector3(-2, 0, -26), Vector3(12, 18, 10), Color("e7e5e4"))
	for i in 3:
		WorldKit.tree(w, Vector3(8 + i * 5, 0, -14), 1.2)
	WorldKit.bush(w, Vector3(4, 0, -10), 1.2)
	WorldKit.street_light(w, Vector3(-6, 0, 12))
	WorldKit.parked_car(w, Vector3(6, 0, 8.5), PI / 2)
	WorldKit.palm(w, Vector3(24, 0, -8))
	DistrictBuilder.kiosk(w, Vector3(-12, 0, 0), 0.0)
	# Figuren: Spieler-Look + NPCs
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var models := ["Casual2_Female", "Suit_Male", "Worker_Female", "Pirate_Male"]
	for i in models.size():
		var v := CharacterVisual.new()
		w.add_child(v)
		v.position = Vector3(-3 + i * 1.6, 0, 2)
		v.rotation.y = PI
		v.apply_npc(models[i], rng)
		var a := CharacterAnimator.new()
		a.visual = v
		w.add_child(a)
	var me := CharacterVisual.new()
	w.add_child(me)
	me.position = Vector3(3.6, 0, 2)
	me.rotation.y = PI
	var look := {}
	for slot in Inventory.SLOTS:
		look[slot] = Inventory.equipped_item(slot)
	look[&"accessory"] = ItemDB.get_item(&"acc_cap") if ItemDB.get_item(&"acc_cap") else null
	me.apply_look(look)
	var ma := CharacterAnimator.new()
	ma.visual = me
	w.add_child(ma)
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.position = Vector3(1, 2.4, 9)
	cam.look_at(Vector3(1, 1.4, 0))
	cam.current = true
	var times := [[0.42, "lab_day"], [0.72, "lab_sunset"], [0.92, "lab_night"]]
	if OS.get_environment("LAB_ONLY") != "":
		times = times.filter(func(t): return OS.get_environment("LAB_ONLY").contains(t[1]))
	for t in times:
		w.day_night.time_of_day = t[0]
		w.day_night.apply()
		for i in 4:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_jpg("%s/%s.jpg" % [dir, t[1]], 0.85)
		print("[lab] ", t[1])
	FX.cloud(w, Vector3(1, 1.6, 4), Vector3(0, 0.4, 1), Color("a855f7"), 2.0)
	w.day_night.time_of_day = 0.45
	w.day_night.apply()
	for i in 10:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_jpg("%s/lab_cloud.jpg" % dir, 0.85)
	print("[lab] lab_cloud")

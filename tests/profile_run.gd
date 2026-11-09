class_name ProfileRun
extends RefCounted
## Zeitmessung des Aufbaus mit echtem Renderer:  godot -- --prof

static func run(main: Node) -> void:
	var tree := main.get_tree()
	await tree.process_frame
	var t := Time.get_ticks_msec()
	var v := CharacterVisual.new()
	main.add_child(v)
	var rng := RandomNumberGenerator.new()
	v.apply_npc("Casual_Male", rng)
	print("[prof] NPC 1: ", Time.get_ticks_msec() - t, " ms")
	t = Time.get_ticks_msec()
	var v2 := CharacterVisual.new()
	main.add_child(v2)
	v2.apply_npc("Casual_Male", rng)
	print("[prof] NPC 2 (Cache): ", Time.get_ticks_msec() - t, " ms")
	t = Time.get_ticks_msec()
	var look := {}
	for slot in Inventory.SLOTS:
		look[slot] = Inventory.equipped_item(slot)
	v2.apply_look(look)
	print("[prof] Spieler-Look: ", Time.get_ticks_msec() - t, " ms")
	t = Time.get_ticks_msec()
	var w := WorldRoot.new()
	main.add_child(w)
	print("[prof] Welt: ", Time.get_ticks_msec() - t, " ms")
	t = Time.get_ticks_msec()
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3, 30)
	cam.far = 900.0
	w.add_child(cam)
	cam.current = true
	# Stufenweise teurer: keine Schatten → Schatten → Nacht (Laternen an)
	w.sun.shadow_enabled = false
	main.get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	for step in ["ohne Schatten", "mit Schatten", "Nacht (Laternen)"]:
		if step == "mit Schatten":
			w.sun.shadow_enabled = true
		if step == "Nacht (Laternen)":
			w.day_night.time_of_day = 0.9
			w.day_night.apply()
		for i in 3:
			t = Time.get_ticks_msec()
			await tree.process_frame
			print("[prof] %s Frame %d: %d ms" % [step, i, Time.get_ticks_msec() - t])

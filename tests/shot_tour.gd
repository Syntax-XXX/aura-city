class_name ShotTour
extends RefCounted
## Visuelle Prüfung: godot -- --shot <ordner>   (unter xvfb-run, Software-Rendering)
## Fotografiert Menü + alle Distrikte (Tag/Nacht) und misst die Bildzeit beim Wolken-Stresstest.

static var only: PackedStringArray = []


static func run(main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var tree := main.get_tree()
	# SHOTS=01,16 → nur diese Aufnahmen (Software-Rendering ist teuer)
	if OS.get_environment("SHOTS") != "":
		only = OS.get_environment("SHOTS").split(",")
	Settings.day_night_cycle = false
	await _frames(tree, 6)
	await _save(main, dir, "00_menu")
	Net.disconnect_profile()
	await main.call("start_game")
	var player: PlayerController = main.get("player")
	var world: WorldRoot = main.get("world")
	var ui: UIRoot = main.get("ui")
	if is_instance_valid(ui.tutorial):
		ui.tutorial.queue_free()
	# name, Spielerposition, Kamera-Yaw, Kamera-Pitch, Tageszeit
	var views := [
		["01_spawn_day", Vector3(0, 1, 26), 0.0, -0.2, 0.38],
		["02_spawn_night", Vector3(0, 1, 26), 0.0, -0.2, 0.9],
		["03_skate", SkatePark.CENTER + Vector3(0, 1, 26), 0.0, -0.25, 0.45],
		["04_neon_night", NeonDistrict.CENTER + Vector3(24, 1, 0), PI / 2, -0.15, 0.92],
		["05_luxury", LuxuryDistrict.ARRIVAL, -PI / 2, -0.15, 0.55],
		["06_harbor", Harbor.CENTER + Vector3(-50, 1, 6), PI * 0.8, -0.2, 0.68],
		["07_beach_sunset", SunsetBeach.CENTER + Vector3(-28, 1, -34), -PI / 2.2, -0.15, 0.72],
		["08_yard", IndustrialYard.CENTER + Vector3(55, 1, 8), PI / 2, -0.2, 0.42],
		["09_downtown", Downtown.CENTER + Vector3(0, 1, 18), 0.0, 0.25, 0.5],
		["10_suburbs", Vector3(150, 1, 150), PI / 4, -0.1, 0.36],
		["11_secret", SecretDimension.CENTER + Vector3(0, 1.5, 12), 0.0, -0.2, 0.5],
	]
	main.get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	for v in views:
		if not _wanted(v[0]):
			continue
		player.teleport(v[1])
		player.camera_rig.yaw = v[2]
		player.camera_rig.pitch = v[3]
		world.day_night.time_of_day = v[4]
		world.day_night.apply()
		await _frames(tree, 6)
		await _save(main, dir, v[0])
	# Wolken-Stresstest: 3 legendäre Wolken direkt hintereinander vor der Kamera
	player.teleport(Vector3(0, 1, 26))
	player.camera_rig.yaw = 0.0
	player.camera_rig.pitch = -0.2
	world.day_night.time_of_day = 0.4
	world.day_night.apply()
	await _frames(tree, 6)
	var base := await _avg_ms(tree, 30)
	for i in 3:
		FX.cloud(world, player.global_position + Vector3(0, 1.5, 0), Vector3(0, 0.3, 1), Color("a855f7"), 3.4)
		await _frames(tree, 4)
	await _frames(tree, 6)
	await _save(main, dir, "12_clouds")
	var clouds := await _avg_ms(tree, 30)
	print("[shot] Bildzeit ohne Wolken %.1f ms, mit 3 Wolken %.1f ms (Software-Rendering)" % [base, clouds])
	# Spielerfigur von vorn, dann ein Trick mitten in der Bewegung
	var arm: SpringArm3D = player.camera_rig.get_child(0)
	arm.spring_length = 3.0
	player.camera_rig.yaw = PI
	player.camera_rig.pitch = -0.12
	world.day_night.time_of_day = 0.45
	world.day_night.apply()
	await _frames(tree, 6)
	await _save(main, dir, "16_player_front")
	Economy.earn(400000, "Test")
	TrickDB.set_loadout_slot(0, &"double_spin")
	player.tricks.perform(&"double_spin")
	await _frames(tree, 9)
	await _save(main, dir, "17_trick_mid")
	arm.spring_length = player.camera_rig.distance
	player.camera_rig.yaw = 0.0
	# UI-Shots
	ui.open(&"shop")
	await _frames(tree, 5)
	await _save(main, dir, "13_shop")
	ui.close_current()
	ui.open(&"trickbook")
	await _frames(tree, 5)
	await _save(main, dir, "14_trickbook")
	ui.close_current()
	await _frames(tree, 10)
	player.tricks.start_inhale()
	player.tricks.push_key("D")
	await _frames(tree, 8)
	await _save(main, dir, "15_hud_timing")


static func _wanted(shot: String) -> bool:
	if only.is_empty():
		return true
	for o in only:
		if shot.begins_with(o):
			return true
	return false


static func _frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame


static func _avg_ms(tree: SceneTree, n: int) -> float:
	var t0 := Time.get_ticks_usec()
	await _frames(tree, n)
	return (Time.get_ticks_usec() - t0) / 1000.0 / n


static func _save(main: Node, dir: String, file_name: String) -> void:
	if not _wanted(file_name):
		return
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.save_jpg("%s/%s.jpg" % [dir, file_name], 0.85)
	print("[shot] ", file_name)

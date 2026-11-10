class_name CpuProbe
extends RefCounted
## CPU-Kosten pro Frame nach Systemen:  godot --headless --fixed-fps 60 -- --cpu

## Wandzeit pro Frame (headless, ohne Bildbremse = reine CPU-Kosten von Skripten + Physik + Engine).
static func _measure(tree: SceneTree, frames := 120) -> Array:
	await tree.physics_frame
	var t0 := Time.get_ticks_usec()
	var worst := 0
	var last := t0
	for i in frames:
		await tree.physics_frame
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
	return [(last - t0) / 1000.0 / frames, worst / 1000.0]


static func run(main: Node) -> void:
	var tree := main.get_tree()
	var world: WorldRoot = main.get("world")
	for i in 900:
		await tree.physics_frame
	var groups := {
		"NPCs": world.find_children("*", "Npc", true, false),
		"CPU-Partikel": world.find_children("*", "CPUParticles3D", true, false),
		"Verkehr": world.find_children("*", "Traffic", true, false),
		"Animationen": world.find_children("*", "AnimationPlayer", true, false),
		"Area3D": world.find_children("*", "Area3D", true, false),
	}
	for k in groups:
		print("[cpu] %s: %d Knoten" % [k, groups[k].size()])
	var player: PlayerController = main.get("player")
	player.teleport(Vector3(-300, 0.5, 4))
	player.camera_rig.yaw = -PI / 2.0
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for i in 60:
		await tree.physics_frame
	var base: Array = await _measure(tree)
	print("[cpu] alles an: Ø %.2f ms/Frame, Spitze %.2f ms" % base)
	for k in groups:
		for n: Node in groups[k]:
			n.process_mode = Node.PROCESS_MODE_DISABLED
		var r: Array = await _measure(tree)
		print("[cpu] ohne %s: Ø %.2f ms/Frame, Spitze %.2f ms" % [k, r[0], r[1]])
		for n: Node in groups[k]:
			n.process_mode = Node.PROCESS_MODE_INHERIT
		print("[cpu]   wieder alles an: Ø %.2f ms/Frame, Spitze %.2f ms" % await _measure(tree))
	player.process_mode = Node.PROCESS_MODE_DISABLED
	print("[cpu] ohne Spieler: Ø %.2f ms/Frame, Spitze %.2f ms" % await _measure(tree))
	player.process_mode = Node.PROCESS_MODE_INHERIT
	var ui: Node = main.get("ui")
	ui.process_mode = Node.PROCESS_MODE_DISABLED
	print("[cpu] ohne UI: Ø %.2f ms/Frame, Spitze %.2f ms" % await _measure(tree))
	ui.process_mode = Node.PROCESS_MODE_INHERIT
	world.process_mode = Node.PROCESS_MODE_DISABLED
	print("[cpu] ohne Welt (nur Spieler/UI): Ø %.2f ms/Frame, Spitze %.2f ms" % await _measure(tree))

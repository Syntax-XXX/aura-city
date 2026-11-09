class_name CountRun
extends RefCounted
## Zählt Render-Objekte der Welt (Draw-Call-Abschätzung):  godot --headless -- --count

static func run(main: Node) -> void:
	var w := WorldRoot.new()
	main.add_child(w)
	await main.get_tree().process_frame
	var meshes := 0
	var near := 0
	var labels := 0
	var lights := 0
	var bodies := 0
	var center := Vector3(0, 0, 12)
	for n in w.find_children("*", "", true, false):
		if n is MeshInstance3D:
			meshes += 1
			if (n as Node3D).global_position.distance_to(center) < 150.0:
				near += 1
		elif n is Label3D:
			labels += 1
		elif n is OmniLight3D:
			lights += 1
		elif n is CollisionObject3D:
			bodies += 1
	print("[count] Meshes gesamt %d, im Umkreis 150 m vom Spawn %d, Label3D %d, Lichter %d, Kollisionskörper %d" % [meshes, near, labels, lights, bodies])

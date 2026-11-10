class_name PlayTest
extends RefCounted
## Automatischer Spieltest über die ganze Map:  godot --headless --fixed-fps 60 -- --play
##  - läuft an ~50 Punkten (Straßen, Ring, alle Distrikte) je 6 s mit Sprint in Blickrichtung
##  - meldet: durch den Boden gefallen, hängengeblieben, Skript-Fehler
##  - misst je Punkt die CPU-Zeit pro Frame (Skripte + Physik) und wie viele Objekte im Bild wären
##  - dampft unterwegs echte Kombos (ziehen → Pfeile → loslassen) inkl. Husten
## Straßenpunkte laufen entlang der Straße (Richtung Mitte), Distrikte geradeaus.
## Rendering selbst misst das nicht (headless ohne GPU) – dafür ist die FPS-Anzeige im Spiel da.

const WALK_SECONDS := 6.0


static func run(main: Node) -> void:
	var tree := main.get_tree()
	var player: PlayerController = main.get("player")
	var world: WorldRoot = main.get("world")
	for i in 60:
		await tree.physics_frame
	var points: Array = []
	# Straßennetz: Hauptachsen + Ringe
	for x in range(-360, 361, 90):
		points.append([Vector3(x, 0.5, 4.0), -PI / 2.0 if x < 0 else PI / 2.0, "Hauptachse x=%d" % x])
	for z in range(-380, 261, 80):
		points.append([Vector3(4.0, 0.5, z), PI if z < 0 else 0.0, "Nord-Süd z=%d" % z])
	for side: float in [-1.0, 1.0]:
		for t in range(-160, 161, 80):
			points.append([Vector3(t, 0.5, side * 200 + 3.0), -PI / 2.0 if t < 0 else PI / 2.0, "Ring z=%d x=%d" % [side * 200, t]])
			points.append([Vector3(side * 200 + 3.0, 0.5, t), PI if t < 0 else 0.0, "Ring x=%d z=%d" % [side * 200, t]])
	# Alle Distrikte (Mittelpunkt der Bezirks-Zone)
	for d: DistrictArea in world.find_children("*", "DistrictArea", true, false):
		points.append([d.global_position + Vector3(0, 0.5, 0), 0.0, "Distrikt " + DistrictArea.NAMES.get(d.district_id, String(d.district_id))])
	var problems: Array[String] = []
	var worst := []
	var combos := 0
	var coughs := 0
	Events.trick_failed.connect(func(_id): coughs += 1)
	for i in points.size():
		var p: Array = points[i]
		player.teleport(_ground(world, p[0]))
		player.camera_rig.yaw = p[1]
		for k in 10:
			await tree.physics_frame
		var start := player.global_position
		var frames := 0
		var t0 := Time.get_ticks_usec()
		var t := 0.0
		var stuck_for := 0.0
		var last := start
		Input.action_press("move_forward")
		Input.action_press("sprint")
		# unterwegs dampfen: jede zweite Station eine Kombo
		if i % 2 == 0 and not player.tricks.is_busy():
			player.tricks.start_inhale()
		while t < WALK_SECONDS:
			await tree.physics_frame
			t += 1.0 / 60.0
			frames += 1
			if player.tricks.is_inhaling():
				if frames == 20:
					player.tricks.push_key("D")
				elif frames == 30:
					player.tricks.push_key("U")
				elif player.tricks.charge >= 55.0:
					player.tricks.release()
					combos += 1
			# hängt fest? → springen, sonst nach 2 s melden
			if player.global_position.distance_to(last) < 0.05:
				stuck_for += 1.0 / 60.0
				if stuck_for > 0.4:
					player._jump_buffer = player.jump_buffer
			else:
				stuck_for = 0.0
			last = player.global_position
			if player.global_position.y < -5.0 and not "Secret" in p[2]:
				break
		Input.action_release("move_forward")
		Input.action_release("sprint")
		var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
		var seen := _visible_objects(player.camera_rig.camera, world)
		# Wandzeit pro Frame (headless ohne Bildbremse = CPU-Kosten von Skripten, Physik, Engine)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / maxf(1.0, frames)
		var line := "%-34s %5.1f m gelaufen · CPU %.2f ms/Frame · %4d Objekte im Bild" % [p[2], moved, ms, seen]
		print("[play] ", line)
		worst.append([seen, ms, p[2]])
		if player.global_position.y < -5.0 and not "Secret" in p[2]:
			problems.append("DURCHGEFALLEN bei " + p[2])
		elif moved < 15.0:
			problems.append("hängt fest bei %s (nur %.1f m in %d s)" % [p[2], moved, WALK_SECONDS])
	worst.sort_custom(func(a, b): return a[0] > b[0])
	print("[play] --- meiste Objekte im Bild ---")
	for w in worst.slice(0, 5):
		print("[play]   %4d Objekte · %s" % [w[0], w[2]])
	var cpu := worst.map(func(w): return w[1])
	cpu.sort()
	print("[play] CPU pro Frame: Median %.2f ms, Max %.2f ms (60 FPS = 16,7 ms Budget inkl. Rendering)" % [cpu[cpu.size() / 2], cpu[-1]])
	print("[play] Kombos geblasen: %d, Husten/Fails: %d, Aura: %s" % [combos, coughs, Economy.aura])
	print("[play] Probleme: %d" % problems.size())
	for pr in problems:
		print("[play]   ✗ ", pr)
	print("[play] FERTIG")


## Bodenhöhe per Raycast (Startpunkt über Dächern/Treppen).
static func _ground(world: Node3D, p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 60.0, p + Vector3.DOWN * 20.0, 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] + Vector3.UP * 0.3) if hit else p


## Grobe Draw-Call-Schätzung: sichtbare Meshes im Sichtkegel und innerhalb ihrer Sichtweite.
static func _visible_objects(cam: Camera3D, world: Node) -> int:
	var n := 0
	var cp := cam.global_position
	for m: GeometryInstance3D in world.find_children("*", "GeometryInstance3D", true, false):
		if not m.is_visible_in_tree():
			continue
		var pos := m.global_position
		var d := pos.distance_to(cp)
		if d > cam.far or (m.visibility_range_end > 0.0 and d > m.visibility_range_end):
			continue
		if d > 3.0 and not cam.is_position_in_frustum(pos):
			continue
		n += 1
	return n

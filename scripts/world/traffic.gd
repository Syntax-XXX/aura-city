class_name Traffic
extends Node3D
## Straßenverkehr: Autos fahren Rundkurse (Ringstraße) bzw. Hauptachsen ab.
## AnimatableBody3D → schiebt den Spieler physikalisch, statt durch ihn durchzufahren.
## Bremst, wenn der Spieler vor dem Auto steht. Weit entfernt: kein Update.

const MODELS := ["BasicCar", "Taxi", "SimpleCarShort", "CopCar", "BasicCar", "RaceCar"]

var _cars: Array[Dictionary] = []


## Rundkurs aus Eckpunkten anlegen, `count` Autos gleichmäßig verteilt.
func add_loop(points: PackedVector3Array, count: int, speed: float) -> void:
	var length := 0.0
	for i in points.size():
		length += points[i].distance_to(points[(i + 1) % points.size()])
	for k in count:
		_spawn(points, length, length * k / count, speed * randf_range(0.85, 1.1))


func _spawn(points: PackedVector3Array, length: float, start: float, speed: float) -> void:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.5, 4.1)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.75, 0)
	body.add_child(col)
	add_child(body)
	# Automodelle schauen nach +Z; _place() richtet +Z in Fahrtrichtung aus
	WorldKit.prop(body, MODELS[randi() % MODELS.size()], Vector3.ZERO, 0.0, 4.3)
	_cars.append({"body": body, "points": points, "length": length, "s": start, "speed": speed, "cur": speed})
	_place(_cars[-1])


func _point_at(car: Dictionary, s: float) -> Array:
	var pts: PackedVector3Array = car["points"]
	s = fposmod(s, car["length"])
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var seg := a.distance_to(b)
		if s <= seg:
			return [a.lerp(b, s / seg), (b - a).normalized()]
		s -= seg
	return [pts[0], (pts[1] - pts[0]).normalized()]


func _place(car: Dictionary) -> void:
	var p: Array = _point_at(car, car["s"])
	var body: AnimatableBody3D = car["body"]
	var dir: Vector3 = p[1]
	body.global_transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), p[0])


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	for car in _cars:
		var body: AnimatableBody3D = car["body"]
		var far := player != null and player.global_position.distance_to(body.global_position) > 160.0
		var want: float = car["speed"]
		if player and not far:
			# vor dem Auto? → bremsen
			var to := player.global_position - body.global_position
			var fwd := body.global_transform.basis.z
			var ahead := to.dot(fwd)
			if ahead > 0.0 and ahead < 9.0 and absf(to.dot(body.global_transform.basis.x)) < 1.6:
				want = 0.0
		car["cur"] = move_toward(car["cur"], want, delta * (14.0 if want < car["cur"] else 4.0))
		car["s"] = car["s"] + car["cur"] * delta
		if far:
			continue
		_place(car)

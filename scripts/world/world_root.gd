class_name WorldRoot
extends Node3D
## Baut die komplette Stadt: Umgebung, Licht, Boden, Straßen, Grenzen, alle Distrikte,
## Tag/Nacht und den „Director“ für zufällige Aura-Rush-Events.

const SPAWN_POINT := Vector3(0, 1, 12)

var day_night: DayNight
var _event_timer := 0.0


func _ready() -> void:
	_build_environment()
	_build_base()
	SpawnCity.build(self)
	SkatePark.build(self)
	NeonDistrict.build(self)
	LuxuryDistrict.build(self)
	SecretDimension.build(self)
	_event_timer = randf_range(180.0, 300.0)


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_density = 0.004
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	day_night = DayNight.new()
	day_night.sun = sun
	day_night.environment = env
	day_night.sky_material = sky_mat
	add_child(day_night)
	day_night.apply()


func _build_base() -> void:
	# Grundfläche (Gras) mit Kollision
	var grass := WorldKit.mat(Color("4d7c3f"), 1.0)
	WorldKit.ground(self, Vector2(420, 420), Vector3.ZERO, grass, 2.0)
	# Straßen zu den Distrikten
	var asphalt := WorldKit.mat(Color("334155"), 0.95)
	var stripe := WorldKit.mat(Color("f8fafc"), 0.6)
	WorldKit.box(self, Vector3(170, 0.03, 9), Vector3(0, 0.015, 0), asphalt, false)
	WorldKit.box(self, Vector3(9, 0.03, 100), Vector3(0, 0.015, -60), asphalt, false)
	for i in 34:
		WorldKit.box(self, Vector3(2.0, 0.035, 0.25), Vector3(-82 + i * 5, 0.02, 0), stripe, false)
	# Unsichtbare Weltgrenze
	for side in [-1, 1]:
		_wall(Vector3(0, 15, side * 205), Vector3(420, 40, 2))
		_wall(Vector3(side * 205, 15, 0), Vector3(2, 40, 420))
	# Bäume außerhalb der Distrikte
	for i in 60:
		var p := Vector3(randf_range(-190, 190), 0, randf_range(-190, 190))
		var free := absf(p.z) > 45.0 or (absf(p.x) > 45.0 and absf(p.x - 120) > 42.0 and absf(p.x + 120) > 42.0)
		var in_lux := absf(p.x) < 42.0 and absf(p.z + 130) < 42.0
		var on_road := absf(p.z) < 7.0 or (absf(p.x) < 7.0 and p.z < 0.0 and p.z > -100.0)
		if free and not in_lux and not on_road:
			WorldKit.tree(self, p, randf_range(0.8, 1.4))


func _wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _process(delta: float) -> void:
	_event_timer -= delta
	if _event_timer <= 0.0:
		_event_timer = randf_range(240.0, 420.0)
		Economy.start_event(2.0, 45.0)
		Events.toast.emit("AURA RUSH! 45 Sekunden doppelte Aura!", Color("facc15"))
		Audio.play(&"rank_up")

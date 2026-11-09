class_name WorldRoot
extends Node3D
## Baut die komplette Stadt: Umgebung, Licht, Boden, Straßen, Grenzen, alle Distrikte,
## Tag/Nacht und den Aura Rush. Der Rush folgt einem festen Zeitplan (Unix-Zeit), damit
## Server und alle Clients ohne Abstimmung dieselben Rush-Fenster kennen.

const SPAWN_POINT := Vector3(0, 1, 12)
const WORLD_HALF := 450.0
## Distrikt-Rechtecke (Mitte x/z, halbe Breite/Tiefe) – hier wird nichts zufällig platziert
const ZONES := [
	[Vector2(0, 0), Vector2(52, 52)], [Vector2(120, 0), Vector2(44, 44)], [Vector2(-120, 0), Vector2(44, 44)],
	[Vector2(0, -130), Vector2(44, 44)], [Vector2(0, 300), Vector2(90, 70)], [Vector2(330, 0), Vector2(80, 90)],
	[Vector2(-330, 0), Vector2(72, 76)], [Vector2(0, -330), Vector2(82, 76)],
]
const RUSH_PERIOD := 300.0
const RUSH_LENGTH := 45.0
const RUSH_MULTIPLIER := 2.0

var day_night: DayNight


func _ready() -> void:
	_build_environment()
	_build_base()
	SpawnCity.build(self)
	SkatePark.build(self)
	NeonDistrict.build(self)
	LuxuryDistrict.build(self)
	SecretDimension.build(self)
	Harbor.build(self)
	SunsetBeach.build(self)
	IndustrialYard.build(self)
	Downtown.build(self)
	_build_suburbs()
	_limit_view_distance(self)
	Events.aura_rewarded.connect(_on_aura_rewarded)


## Sekunden, die der Rush zur Unix-Zeit `unix` noch läuft (0 = kein Rush).
static func rush_left(unix: float) -> float:
	var p := fmod(unix, RUSH_PERIOD)
	return RUSH_LENGTH - p if p < RUSH_LENGTH else 0.0


func _on_aura_rewarded(amount: float, _reason: String, pos: Vector3) -> void:
	if pos != Vector3.ZERO and amount > 0.0:
		FX.floating_text(self, pos, "+%s ✦" % UIFormat.number(amount), Color("facc15"))


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
	env.fog_density = 0.0065
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
	WorldKit.ground(self, Vector2(WORLD_HALF * 2.0, WORLD_HALF * 2.0), Vector3.ZERO, WorldKit.mat(Color("4d7c3f"), 1.0), 2.0)
	# Straßennetz: Hauptachsen durch alle Distrikte + Ring um die Innenstadt
	_road(Vector3(0, 0, 0), Vector3(800, 0, 10))
	_road(Vector3(0, 0, -70), Vector3(10, 0, 660))
	for side: float in [-1.0, 1.0]:
		_road(Vector3(0, 0, side * 200), Vector3(410, 0, 9))
		_road(Vector3(side * 200, 0, 0), Vector3(9, 0, 410))
	# Laternen entlang der Hauptachsen (außerhalb der Distrikte)
	for i in range(-13, 14):
		for p: Vector3 in [Vector3(i * 30, 0, 7), Vector3(7, 0, i * 30 - 70)]:
			if not _in_zone(p, 2.0):
				WorldKit.street_light(self, p)
	# Unsichtbare Weltgrenze
	for side in [-1, 1]:
		_wall(Vector3(0, 15, side * (WORLD_HALF - 5)), Vector3(WORLD_HALF * 2, 40, 2))
		_wall(Vector3(side * (WORLD_HALF - 5), 15, 0), Vector3(2, 40, WORLD_HALF * 2))


func _road(center: Vector3, size: Vector3) -> void:
	WorldKit.box(self, Vector3(size.x, 0.03, size.z), center + Vector3(0, 0.015, 0), WorldKit.mat(Color("334155"), 0.95), false)
	var line := Vector3(size.x - 2.0, 0.035, 0.25) if size.x > size.z else Vector3(0.25, 0.035, size.z - 2.0)
	WorldKit.box(self, line, center + Vector3(0, 0.02, 0), WorldKit.mat(Color("facc15"), 0.6), false)


## Liegt p in einem Distrikt oder auf einer Straße?
func _in_zone(p: Vector3, margin := 0.0) -> bool:
	for z in ZONES:
		var c: Vector2 = z[0]
		var h: Vector2 = z[1]
		if absf(p.x - c.x) < h.x + margin and absf(p.z - c.y) < h.y + margin:
			return true
	var on_road := absf(p.z) < 9.0 or (absf(p.x) < 9.0 and p.z < 260.0)
	var on_ring := (absf(absf(p.z) - 200.0) < 9.0 and absf(p.x) < 210.0) or (absf(absf(p.x) - 200.0) < 9.0 and absf(p.z) < 210.0)
	return on_road or on_ring


## Vororte, Parks und Bäume zwischen den Distrikten.
func _build_suburbs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 # gleiche Stadt bei jedem Start
	seed(4242)
	var placed := 0
	for gx in range(-16, 17):
		for gz in range(-16, 17):
			var p := Vector3(gx * 26.0 + rng.randf_range(-5, 5), 0, gz * 26.0 + rng.randf_range(-5, 5))
			if absf(p.x) > WORLD_HALF - 20.0 or absf(p.z) > WORLD_HALF - 20.0 or _in_zone(p, 10.0):
				continue
			var roll := rng.randf()
			if roll < 0.32:
				WorldKit.house(self, p, rng.randi_range(0, 3) * PI / 2.0)
				placed += 1
			elif roll < 0.8:
				WorldKit.tree(self, p, rng.randf_range(0.8, 1.5))
				if rng.randf() < 0.5:
					WorldKit.tree(self, p + Vector3(rng.randf_range(4, 8), 0, rng.randf_range(-6, 6)), rng.randf_range(0.7, 1.2))
	randomize()


## Kleine Objekte nur in der Nähe rendern (große Map → konstante Bildrate). Nebel verdeckt den Übergang.
static func _limit_view_distance(node: Node) -> void:
	var gi := node as GeometryInstance3D
	if gi and not gi is Label3D:
		var aabb := gi.get_aabb()
		var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		if longest < 8.0:
			gi.visibility_range_end = 140.0
		elif longest < 40.0:
			gi.visibility_range_end = 320.0
	elif node is Label3D:
		(node as Label3D).visibility_range_end = 260.0
	for c in node.get_children():
		_limit_view_distance(c)


func _wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _process(_delta: float) -> void:
	var left := rush_left(Net.now())
	if left > 0.5 and Economy.event_seconds_left() <= 0.0:
		Economy.start_event(RUSH_MULTIPLIER, left)
		Events.toast.emit("AURA RUSH! %d Sekunden doppelte Aura!" % ceili(left), Color("facc15"))
		Audio.play(&"rank_up")

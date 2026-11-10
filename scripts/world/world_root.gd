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
var sky_dome: MeshInstance3D
var weather: Weather
var sun: DirectionalLight3D
var _env: Environment
var _applied_view_quality := -1.0


## Nur Umgebung + Boden (für die Lab-Szene in tests/lab_scene.gd)
var lab_mode := false


func _ready() -> void:
	_build_environment()
	if lab_mode:
		WorldKit.ground(self, Vector2(200, 200), Vector3.ZERO, WorldKit.surface(&"grass", Color(0.85, 0.95, 0.8)), 2.0)
		return
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
	# Aura-Battles gegen NPC-Rivalen (Score-Challenges, serverseitig geprüft)
	for r in [["Rivalin Rina", Vector3(-30, 0, 20), 800, 40.0, 600, &"default"],
			["Kickflip Kai", SkatePark.CENTER + Vector3(30, 0, 14), 2500, 45.0, 2000, &"street"],
			["Neon Nina", NeonDistrict.CENTER + Vector3(-22, 0, 22), 6000, 50.0, 5000, &"street"],
			["Käpt'n Krass", Harbor.CENTER + Vector3(40, 0, 20), 9000, 50.0, 7500, &"harbor"],
			["Wellen-Wanda", SunsetBeach.CENTER + Vector3(-15, 0, 60), 12000, 55.0, 10000, &"default"],
			["Spray King", IndustrialYard.CENTER + Vector3(30, 0, 20), 18000, 55.0, 15000, &"work"],
			["Baron von Aura", LuxuryDistrict.CENTER + Vector3(-20, 0, 8), 30000, 60.0, 28000, &"business"],
			["Sigma Sigrid", Downtown.CENTER + Vector3(-14, 0, 24), 60000, 70.0, 60000, &"business"]]:
		DistrictBuilder.rival(self, r[0], r[1], r[2], r[3], r[4], r[5], Color("f43f5e"))
	# Aura-Kioske (Drinks) – einer pro Distrikt
	for k in [[Vector3(24, 0, 4), -PI / 2], [SkatePark.CENTER + Vector3(30, 0, -30), 0.0], [NeonDistrict.CENTER + Vector3(-26, 0, -8), PI / 2],
			[LuxuryDistrict.CENTER + Vector3(30, 0, 4), -PI / 2], [Harbor.CENTER + Vector3(-8, 0, 20), PI], [SunsetBeach.CENTER + Vector3(-24, 0, -6), PI / 2],
			[IndustrialYard.CENTER + Vector3(-20, 0, 4), 0.0], [Downtown.CENTER + Vector3(14, 0, -3), -PI / 2]]:
		DistrictBuilder.kiosk(self, k[0], k[1])
	_build_suburbs()
	apply_quality()
	Events.aura_rewarded.connect(_on_aura_rewarded)


## Sekunden, die der Rush zur Unix-Zeit `unix` noch läuft (0 = kein Rush).
static func rush_left(unix: float) -> float:
	var p := fmod(unix, RUSH_PERIOD)
	return RUSH_LENGTH - p if p < RUSH_LENGTH else 0.0


func _on_aura_rewarded(amount: float, _reason: String, pos: Vector3) -> void:
	if pos != Vector3.ZERO and amount > 0.0:
		FX.floating_text(self, pos, "+%s ✦" % UIFormat.number(amount), Color("facc15"))
	elif pos != Vector3.ZERO and amount < 0.0:
		FX.floating_text(self, pos, "−%s ✦" % UIFormat.number(-amount), Color("f87171"))


func _build_environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://assets/shaders/sky_dome.gdshader")
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 800.0
	dome_mesh.height = 1600.0
	dome_mesh.radial_segments = 32
	dome_mesh.rings = 16
	sky_dome = MeshInstance3D.new()
	sky_dome.mesh = dome_mesh
	sky_dome.material_override = sky_mat
	sky_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_dome.extra_cull_margin = 16384.0
	add_child(sky_dome)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b0a1f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_density = 0.0055
	env.fog_sky_affect = 0.35
	# Glow nur für wirklich helle (emissive) Flächen
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	day_night = DayNight.new()
	day_night.sun = sun
	day_night.environment = env
	day_night.sky_material = sky_mat
	add_child(day_night)
	day_night.apply()
	if not lab_mode:
		weather = Weather.new()
		weather.day_night = day_night
		add_child(weather)
	Events.settings_changed.connect(apply_quality)


## Grafikstufe anwenden: Schatten, Kantenglättung, Renderauflösung, Sichtweite, Glow.
func apply_quality() -> void:
	var q := Settings.graphics_quality
	sun.shadow_enabled = Settings.shadows
	sun.directional_shadow_max_distance = [40.0, 60.0, 90.0][q]
	_env.glow_enabled = q >= 1
	# kürzere Sichtweite → dichterer Nebel verdeckt den Übergang
	_env.fog_density = lerpf(0.0095, 0.0055, inverse_lerp(0.4, 1.0, Settings.view_distance))
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][Settings.msaa]
		vp.scaling_3d_scale = Settings.render_scale
	if not is_equal_approx(Settings.view_distance, _applied_view_quality):
		_applied_view_quality = Settings.view_distance
		_limit_view_distance(self, Settings.view_distance)


func _build_base() -> void:
	# Grundfläche (Gras) mit Kollision
	WorldKit.ground(self, Vector2(WORLD_HALF * 2.0, WORLD_HALF * 2.0), Vector3.ZERO, WorldKit.surface(&"grass", Color(0.85, 0.95, 0.8)), 2.0)
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
	WorldKit.box(self, Vector3(size.x, 0.03, size.z), center + Vector3(0, 0.015, 0), WorldKit.surface(&"asphalt"), false)
	# Gehwege beidseitig
	var walk := Vector3(size.x, 0.12, 2.2) if size.x > size.z else Vector3(2.2, 0.12, size.z)
	var off := Vector3(0, 0.06, size.z / 2.0 + 1.1) if size.x > size.z else Vector3(size.x / 2.0 + 1.1, 0.06, 0)
	WorldKit.box(self, walk, center + off, WorldKit.surface(&"sidewalk"), false)
	WorldKit.box(self, walk, center - off + Vector3(0, 0.12, 0), WorldKit.surface(&"sidewalk"), false)
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
			if roll < 0.3:
				var house_yaw := rng.randi_range(0, 3) * PI / 2.0
				WorldKit.house(self, p, house_yaw)
				if rng.randf() < 0.35:
					WorldKit.parked_car(self, p + Vector3(cos(house_yaw), 0, -sin(house_yaw)) * 7.5, house_yaw + PI / 2.0)
				WorldKit.bush(self, p + Vector3(rng.randf_range(-7, 7), 0, 6.5), rng.randf_range(0.8, 1.3))
			elif roll < 0.72:
				WorldKit.tree(self, p, rng.randf_range(0.9, 1.4))
				if rng.randf() < 0.5:
					WorldKit.tree(self, p + Vector3(rng.randf_range(4, 8), 0, rng.randf_range(-6, 6)), rng.randf_range(0.8, 1.2))
				WorldKit.bush(self, p + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), rng.randf_range(0.7, 1.2))
			elif roll < 0.82:
				WorldKit.rock(self, p, rng.randf_range(0.8, 1.6))
				WorldKit.bush(self, p + Vector3(2.5, 0, 1.0), 1.0)
	_spawn_pedestrians()
	# Verkehr auf der Ringstraße (zwei Fahrspuren, gegenläufig)
	var traffic := Traffic.new()
	add_child(traffic)
	var inner := 197.8
	var outer := 202.2
	traffic.add_loop(PackedVector3Array([Vector3(-inner, 0, -inner), Vector3(inner, 0, -inner), Vector3(inner, 0, inner), Vector3(-inner, 0, inner)]), 7, 11.0)
	traffic.add_loop(PackedVector3Array([Vector3(-outer, 0, outer), Vector3(outer, 0, outer), Vector3(outer, 0, -outer), Vector3(-outer, 0, -outer)]), 7, 11.0)
	randomize()


## Passanten, die auf den Gehwegen der Hauptstraßen hin und her laufen.
func _spawn_pedestrians() -> void:
	var names := ["Alex", "Sam", "Mira", "Tom", "Nele", "Ali", "Jana", "Luca", "Emma", "Ben", "Zoe", "Finn", "Lina", "Noah", "Mia", "Elias", "Ida", "Paul", "Lea", "Jonas", "Sara", "Tim", "Nora", "Max"]
	var lines := PackedStringArray(["Unterwegs zum Hafen.", "Die Stadt ist riesig, oder?", "Nimm die Teleporter am Spawn, spart Zeit.", "Heute Abend ist Aura Rush, hab ich gehört."])
	var styles := [&"default", &"business", &"work", &"street"]
	for i in names.size():
		var on_x := i % 2 == 0
		var lane := 9.7 if i % 4 < 2 else -9.7
		var start := -380.0 + fmod(i * 31.0, 700.0)
		var a := Vector3(start, 0.2, lane) if on_x else Vector3(lane, 0.2, start * 0.85 - 40.0)
		var b := a + (Vector3(70, 0, 0) if on_x else Vector3(0, 0, 70))
		var n := Npc.new()
		n.npc_name = names[i]
		n.lines = lines
		n.style = styles[i % styles.size()]
		n.patrol_a = a
		n.patrol_b = b
		n.walk_speed = randf_range(1.2, 1.8)
		n.position = a
		add_child(n)


## Kleine Objekte nur in der Nähe rendern (große Map → konstante Bildrate). Nebel verdeckt den Übergang.
static func _limit_view_distance(node: Node, mult := 1.0) -> void:
	var gi := node as GeometryInstance3D
	if gi and not gi is Label3D:
		var aabb := gi.get_aabb()
		var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		# Flaches/Kleines wirft keinen Schatten (Straßen, Linien, Deko) → spart Schatten-Draw-Calls
		var height := aabb.size.y * (gi as Node3D).global_transform.basis.get_scale().y if gi.is_inside_tree() else aabb.size.y
		if height < 1.2 or longest < 0.8:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if longest < 8.0:
			gi.visibility_range_end = 150.0 * mult
		elif longest < 40.0:
			gi.visibility_range_end = 340.0 * mult
	elif node is Label3D and not node.has_meta(&"keep_range"):
		var lbl := node as Label3D
		lbl.visibility_range_end = (260.0 if lbl.font_size > 120 else 90.0) * mult
		lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_limit_view_distance(c, mult)


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
	var cam := get_viewport().get_camera_3d()
	if cam and sky_dome:
		sky_dome.global_position = cam.global_position # Kuppel wandert mit
	var left := rush_left(Net.now())
	if left > 0.5 and Economy.event_seconds_left() <= 0.0:
		Economy.start_event(RUSH_MULTIPLIER, left)
		Events.toast.emit("AURA RUSH! %d Sekunden doppelte Aura!" % ceili(left), Color("facc15"))
		Audio.play(&"rank_up")

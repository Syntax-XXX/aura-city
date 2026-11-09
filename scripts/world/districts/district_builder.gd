class_name DistrictBuilder
extends RefCounted
## Gemeinsame Helfer zum Bestücken eines Distrikts.


static func place(parent: Node3D, node: Node3D, pos: Vector3) -> Node3D:
	node.position = pos
	parent.add_child(node)
	return node


static func npc(parent: Node3D, npc_name: String, pos: Vector3, lines: PackedStringArray, radius := 10.0, style: StringName = &"default") -> Npc:
	var n := Npc.new()
	n.style = style
	n.npc_name = npc_name
	n.lines = lines
	n.wander_center = pos
	n.wander_radius = radius
	place(parent, n, pos + Vector3(0, 0.1, 0))
	return n


static func shards(parent: Node3D, prefix: String, center: Vector3, count: int, spread: float, reward := 40) -> void:
	for i in count:
		var a := float(i) / count * TAU + 0.3
		var r := spread * (0.45 + 0.55 * fmod(i * 0.618, 1.0))
		var c := Collectible.new()
		c.collectible_id = StringName("%s_%d" % [prefix, i])
		c.reward = reward
		place(parent, c, center + Vector3(cos(a) * r, 0, sin(a) * r))


static func secret_shard(parent: Node3D, id: StringName, pos: Vector3) -> void:
	var c := Collectible.new()
	c.collectible_id = id
	c.secret = true
	c.reward = 100
	place(parent, c, pos)


## NPC-Rivale mit Aura-Battle: in der Zeit mehr Aura farmen als der Rivale (Score-Challenge).
static func rival(parent: Node3D, rival_name: String, pos: Vector3, score: int, seconds: float, reward: int, style: StringName, color: Color) -> void:
	var n := npc(parent, rival_name, pos, PackedStringArray([
		"Du willst Aura? Dann zeig's mir.",
		"Schaffst du %s Aura in %d Sekunden? Ich schon." % [UIFormat.number(score), int(seconds)],
		"Tritt in den Ring neben mir, wenn du bereit bist.",
	]), 1.5, style)
	challenge(parent, pos + Vector3(3.2, 0, 0), "Battle: " + rival_name, "score", score, seconds, reward, color)


static func shop(parent: Node3D, shop_name: String, pos: Vector3, min_r: int, max_r: int, color: Color) -> void:
	WorldKit.box(parent, Vector3(2.2, 1.2, 1.0), pos + Vector3(0, 0.6, 0), WorldKit.mat(Color("1f1235"), 0.4, 0.4))
	WorldKit.box(parent, Vector3(1.8, 0.9, 0.06), pos + Vector3(0, 1.75, -0.2), WorldKit.mat(color, 0.3, 0.0, 2.0), false)
	WorldKit.sign_text(parent, pos + Vector3(0, 3.0, 0), shop_name, color, 96, 0.0, true)
	var t := ShopTerminal.new()
	t.shop_name = shop_name
	t.min_rarity = min_r
	t.max_rarity = max_r
	place(parent, t, pos + Vector3(0, 0, 1.0))


static func station(parent: Node3D, screen: StringName, label: String, pos: Vector3, color: Color, daily := false) -> void:
	WorldKit.cylinder(parent, 0.6, 1.4, pos + Vector3(0, 0.7, 0), WorldKit.mat(Color("1f1235"), 0.4, 0.4))
	WorldKit.cylinder(parent, 0.45, 0.25, pos + Vector3(0, 1.55, 0), WorldKit.mat(color, 0.3, 0.0, 2.5), false)
	WorldKit.sign_text(parent, pos + Vector3(0, 2.6, 0), label, color, 80, 0.0, true)
	var s := ScreenStation.new()
	s.screen = screen
	s.prompt = label
	s.only_when_daily_available = daily
	place(parent, s, pos)


## Getränkeautomat „Aura-Kiosk“ (öffnet die Drink-Auswahl).
static func kiosk(parent: Node3D, pos: Vector3, yaw := 0.0) -> void:
	var k := Node3D.new()
	k.rotation.y = yaw
	place(parent, k, pos)
	WorldKit.box(k, Vector3(1.3, 2.1, 0.8), Vector3(0, 1.05, 0), WorldKit.mat(Color("1e1b4b"), 0.35, 0.5))
	WorldKit.box(k, Vector3(1.0, 1.3, 0.05), Vector3(0, 1.25, 0.41), WorldKit.mat(Color("22d3ee"), 0.2, 0.0, 1.6), false)
	for i in 3:
		WorldKit.box(k, Vector3(0.22, 0.32, 0.06), Vector3(-0.3 + i * 0.3, 1.25, 0.45), WorldKit.mat([Color("a3e635"), Color("fbbf24"), Color("f9a8d4")][i], 0.3, 0.0, 1.2), false)
	WorldKit.sign_text(k, Vector3(0, 2.6, 0), "Aura-Kiosk", Color("67e8f9"), 64, 0.0, true)
	var s := ScreenStation.new()
	s.screen = &"drinks"
	s.prompt = "Aura-Kiosk"
	place(k, s, Vector3(0, 0, 0.9))


static func info(parent: Node3D, pos: Vector3, title: String, lines: PackedStringArray, yaw := 0.0) -> void:
	WorldKit.box(parent, Vector3(0.15, 2.0, 0.15), pos + Vector3(0, 1.0, 0), WorldKit.mat(Color("374151")))
	var board := WorldKit.box(parent, Vector3(1.6, 0.9, 0.08), pos + Vector3(0, 2.2, 0), WorldKit.mat(Color("312e81"), 0.4, 0.0, 0.4), false)
	board.rotation.y = yaw
	var l := WorldKit.sign_text(parent, pos + Vector3(0, 2.2, 0), title, Color("e9d5ff"), 48, yaw)
	l.position += Vector3(sin(yaw), 0, cos(yaw)) * 0.06
	var s := InfoSign.new()
	s.speaker = title
	s.lines = lines
	s.prompt = "Lesen: " + title
	place(parent, s, pos)


static func teleporter(parent: Node3D, pos: Vector3, destination: String, target: Vector3, rank := 0, secret := false) -> void:
	if not secret:
		WorldKit.cylinder(parent, 1.2, 0.15, pos + Vector3(0, 0.075, 0), WorldKit.mat(Color("22d3ee"), 0.3, 0.0, 1.8))
		WorldKit.sign_text(parent, pos + Vector3(0, 2.2, 0), "⇄ " + destination, Color("67e8f9"), 72, 0.0, true)
	var t := Teleporter.new()
	t.destination_name = destination if not secret else "???"
	t.target = target
	t.required_rank = rank
	t.secret = secret
	place(parent, t, pos)


static func challenge(parent: Node3D, pos: Vector3, title: String, kind: String, goal: int, seconds: float, reward: int, color: Color) -> void:
	var c := ChallengeZone.new()
	c.challenge_name = title
	c.kind = kind
	c.goal = goal
	c.seconds = seconds
	c.reward = reward
	c.color = color
	place(parent, c, pos)


static func gate(parent: Node3D, pos: Vector3, yaw: float, district_name: String, rank: int) -> void:
	var g := DistrictGate.new()
	g.district_name = district_name
	g.required_rank = rank
	g.rotation.y = yaw
	place(parent, g, pos)

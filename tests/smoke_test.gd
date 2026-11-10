class_name SmokeTest
extends RefCounted
## Startet das echte Spiel (Menü → Welt), spielt Trick/Combo und öffnet jedes Menü.

static func run(main: Node) -> void:
	var tree := main.get_tree()
	var player: PlayerController = main.get("player")
	var ui: UIRoot = main.get("ui")
	for i in 90:
		await tree.physics_frame
	print("[smoke] Spieler bei ", player.global_position, " Boden=", player.is_on_floor())
	var before := Economy.aura
	print("[smoke] Trick-Start: '", player.tricks.start_slot(0), "'")
	player.tricks.needle = 0.5
	player.tricks.land()
	print("[smoke] Aura +", Economy.aura - before, " Combo ", player.tricks.combo)
	for key: StringName in ui.screens:
		ui.open(key)
		await tree.process_frame
		await tree.process_frame
		print("[smoke] Menü ", key, " sichtbar=", ui.current != null and ui.current.visible)
		ui.close_current()
		await tree.process_frame
	Events.dialogue_requested.emit("Test", PackedStringArray(["Hallo", "Tschüss"]))
	print("[smoke] Dialog offen=", ui.dialogue.visible, " Eingabe gesperrt=", not player.input_enabled)
	ui.dialogue.advance()
	ui.dialogue.advance()
	ui.dialogue.advance()
	ui.dialogue.advance()
	print("[smoke] Dialog zu=", not ui.dialogue.visible, " Eingabe frei=", player.input_enabled)
	print("[smoke] Interaktionen: ", tree.get_nodes_in_group(&"interactables").size())
	# Hoverboard + Board-Trick
	for i in 40:
		await tree.physics_frame
	player.toggle_board()
	print("[smoke] Hoverboard aktiv=", player.boarding, " Tempo=", player.board_speed())
	var before_board := Economy.aura
	for i in 10:
		await tree.physics_frame
	player.tricks._cooldowns.clear()
	print("[smoke] Board-Trick-Start: '", player.tricks.start_slot(1), "'")
	player.tricks.needle = 0.5
	player.tricks.land()
	print("[smoke] Board-Trick Aura +", Economy.aura - before_board)
	for i in 60:
		await tree.process_frame
	player.toggle_board()
	print("[smoke] Hoverboard aus=", not player.boarding)
	# Touch-Steuerung (Handy): echte Touch-Events auf die Buttons
	var tc := TouchControls.new()
	tc.player = player
	ui._root.add_child(tc)
	await tree.process_frame
	player.tricks._cooldowns.clear()
	var c_before := player.tricks.combo
	while player.tricks.is_busy():
		await tree.process_frame
	await _tap(tree, tc, "trick_2")
	print("[smoke] Touch: Trick gestartet=", player.tricks.phase == TrickSystem.Phase.TIMING)
	player.tricks.needle = 0.5
	await _tap(tree, tc, "trick_land")
	print("[smoke] Touch: gelandet=", player.tricks.combo > c_before or player.tricks.phase != TrickSystem.Phase.TIMING)
	var pos0 := player.global_position
	_touch(tc, 5, Vector2(tc.size.x * 0.15, tc.size.y * 0.75), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 5
	drag.position = _win(tc, Vector2(tc.size.x * 0.15, tc.size.y * 0.75 - 100))
	Input.parse_input_event(drag)
	for i in 30:
		await tree.physics_frame
	_touch(tc, 5, Vector2(tc.size.x * 0.15, tc.size.y * 0.75 - 100), false)
	print("[smoke] Touch: Stick bewegt=", player.global_position.distance_to(pos0) > 0.5)
	await _tap(tree, tc, "open_shop")
	print("[smoke] Touch: Shop offen=", ui.current == ui.screens[&"shop"])
	ui.close_current()
	await _tap(tree, tc, "pause")
	print("[smoke] Touch: Menü offen=", ui.current == ui.screens[&"pause"])
	ui.close_current()
	tc.queue_free()
	await tree.process_frame
	# Foto-Modus an/aus
	ui.photo.toggle()
	print("[smoke] Foto-Modus=", ui.photo.active, " Zeit=", Engine.time_scale, " UI versteckt=", not ui._root.visible)
	ui.photo.toggle()
	print("[smoke] Foto-Modus aus=", not ui.photo.active, " Zeit=", Engine.time_scale)
	print("[smoke] OK")


## Viewport-Koordinaten → Fensterkoordinaten (so liefert ein echtes Gerät die Touches)
static func _win(tc: Control, pos: Vector2) -> Vector2:
	return tc.get_viewport().get_final_transform() * pos


static func _touch(tc: TouchControls, index: int, pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.position = _win(tc, pos)
	t.pressed = pressed
	Input.parse_input_event(t)


static func _tap(tree: SceneTree, tc: TouchControls, action: String) -> void:
	for b in tc._buttons:
		if b["action"] == action:
			_touch(tc, 3, b["c"], true)
			await tree.process_frame
			await tree.process_frame
			_touch(tc, 3, b["c"], false)
			await tree.process_frame
			return

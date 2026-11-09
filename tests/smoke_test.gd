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
	# Foto-Modus an/aus
	ui.photo.toggle()
	print("[smoke] Foto-Modus=", ui.photo.active, " Zeit=", Engine.time_scale, " UI versteckt=", not ui._root.visible)
	ui.photo.toggle()
	print("[smoke] Foto-Modus aus=", not ui.photo.active, " Zeit=", Engine.time_scale)
	print("[smoke] OK")

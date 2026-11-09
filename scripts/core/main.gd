extends Node
## Spielablauf: Hauptmenü → Ladebildschirm → Welt + Spieler + UI → zurück ins Menü.
## Startargumente (nach „--“): --tests  führt die Testsuite aus,
##                             --smoke  startet das Spiel automatisch und beendet nach einer Probe.

var world: WorldRoot
var player: PlayerController
var ui: UIRoot
var menu: MainMenu
var loading: LoadingScreen


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var ei := args.find("--export-data")
	if ei >= 0:
		get_tree().quit(0 if DataExport.run(self, args[ei + 1]) else 1)
		return
	var oi := args.find("--online-test")
	if oi >= 0:
		var failed_online: int = await OnlineTest.new().run(self, args[oi + 1])
		get_tree().quit(1 if failed_online > 0 else 0)
		return
	if "--prof" in args:
		await ProfileRun.run(self)
		get_tree().quit()
		return
	if "--tests" in args:
		var failed: int = await TestRunner.new().run(self)
		get_tree().quit(1 if failed > 0 else 0)
		return
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var theme_root := Control.new()
	theme_root.theme = UITheme.get_theme()
	theme_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(theme_root)
	menu = MainMenu.new()
	theme_root.add_child(menu)
	menu.play_pressed.connect(start_game)
	loading = LoadingScreen.new()
	theme_root.add_child(loading)
	var si := args.find("--shot")
	if si >= 0:
		await ShotTour.run(self, args[si + 1])
		get_tree().quit()
		return
	if "--smoke" in args:
		await start_game()
		await SmokeTest.run(self)
		get_tree().quit()


func start_game() -> void:
	menu.visible = false
	loading.visible = true
	loading.set_progress(0.1, "Lade Spielstand …")
	await get_tree().process_frame
	loading.set_progress(0.3, "Baue die Stadt …")
	await get_tree().process_frame
	world = WorldRoot.new()
	add_child(world)
	loading.set_progress(0.8, "Spawne Spieler …")
	await get_tree().process_frame
	player = PlayerController.new()
	world.add_child(player)
	player.teleport(WorldRoot.SPAWN_POINT)
	ui = UIRoot.new()
	ui.player = player
	ui.world = world
	add_child(ui)
	ui.quit_to_menu.connect(back_to_menu)
	loading.set_progress(0.92, "Bereite Effekte vor …")
	# Shader einmal hinter dem Ladebildschirm zeichnen → kein Ruckler beim ersten Trick/Wolken-Effekt
	var front := player.global_position + Vector3(0, 1.5, -2.5)
	FX.cloud(world, front, Vector3.UP, Color.WHITE, 1.0)
	FX.sparkles(world, front, Color.WHITE, 8)
	FX.ring(world, front, Color.WHITE, 1.0)
	FX.floating_text(world, front, "+1", Color.WHITE)
	for i in 3:
		await get_tree().process_frame
	loading.set_progress(1.0, "Los geht's!")
	await get_tree().process_frame
	loading.visible = false
	Audio.start_world_audio()
	if not SaveSystem.tutorial_done:
		ui.start_tutorial()


func back_to_menu() -> void:
	SaveSystem.save_game()
	if Net.online:
		await Net.wait_flushed()
		Net.disconnect_profile()
		SaveSystem.load_game() # Menü zeigt wieder das lokale Profil
	Audio.stop_world_audio()
	ui.queue_free()
	world.queue_free()
	ui = null
	world = null
	player = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.visible = true
	menu.refresh()

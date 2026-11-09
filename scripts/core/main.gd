extends Node
## Spielablauf: Hauptmenü → Ladebildschirm → Welt + Spieler + UI → zurück ins Menü.
## Startargumente (nach „--“): --tests  führt die Testsuite aus,
##                             --smoke  startet das Spiel automatisch und beendet nach einer Probe.

var world: WorldRoot
var player: PlayerController
var ui: UIRoot
var menu: MainMenu
var loading: LoadingScreen
var menu_camera: Camera3D
var _orbit := 0.0


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
	var li := args.find("--lab")
	if li >= 0:
		await LabScene.run(self, args[li + 1])
		get_tree().quit()
		return
	if "--count" in args:
		await CountRun.run(self)
		get_tree().quit()
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
	# Stadt einmal bauen: Hintergrund des Hauptmenüs und Spielwelt zugleich
	menu.visible = false
	loading.visible = true
	loading.set_progress(0.2, "Baue die Stadt …")
	await get_tree().process_frame
	await get_tree().process_frame
	_build_world()
	loading.set_progress(1.0, "Fertig")
	await get_tree().process_frame
	loading.visible = false
	menu.visible = true
	var si := args.find("--shot")
	if si >= 0:
		await ShotTour.run(self, args[si + 1])
		get_tree().quit()
		return
	if "--smoke" in args:
		await start_game()
		await SmokeTest.run(self)
		get_tree().quit()


func _build_world() -> void:
	world = WorldRoot.new()
	add_child(world)
	menu_camera = Camera3D.new()
	menu_camera.far = 900.0
	menu_camera.fov = 60.0
	world.add_child(menu_camera)
	menu_camera.current = true


## Langsame Kamerafahrt über die Stadt hinter dem Hauptmenü.
func _process(delta: float) -> void:
	if menu_camera and menu_camera.current and is_instance_valid(menu_camera):
		_orbit += delta * 0.05
		menu_camera.position = Vector3(cos(_orbit) * 75.0, 28.0 + sin(_orbit * 0.7) * 6.0, sin(_orbit) * 75.0)
		menu_camera.look_at(Vector3(0, 6, 0))


func start_game() -> void:
	menu.visible = false
	loading.visible = true
	loading.set_progress(0.3, "Lade Spielstand …")
	await get_tree().process_frame
	loading.set_progress(0.7, "Spawne Spieler …")
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
	player.queue_free()
	ui = null
	player = null
	menu_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.visible = true
	menu.refresh()

class_name UIRoot
extends CanvasLayer
## Verwaltet alle Spiel-Oberflächen: HUD, Menüs, Dialoge, Toasts, Tutorial.
## Zuständig für Hotkeys, Maus-Modus und das Sperren der Spieler-Eingabe.

signal quit_to_menu

const HOTKEYS := {
	"open_shop": &"shop", "open_inventory": &"inventory", "open_customize": &"customize",
	"open_trickbook": &"trickbook", "open_quests": &"quests", "open_achievements": &"achievements",
	"open_leaderboard": &"leaderboard",
}

var player: PlayerController
var world: WorldRoot
var hud: HUD
var confirm: UIConfirm
var dialogue: DialogueBox
var tutorial: TutorialOverlay
var screens: Dictionary = {} # StringName -> UIScreen
var current: UIScreen
var photo: PhotoMode
var touch: TouchControls
var _root: Control


func _ready() -> void:
	layer = 1
	_root = Control.new()
	_root.theme = UITheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	hud = HUD.new()
	hud.player = player
	hud.world = world
	_root.add_child(hud)
	_root.add_child(ToastStack.new())
	if TouchControls.wanted():
		touch = TouchControls.new()
		touch.player = player
		_root.add_child(touch)
	screens = {
		&"shop": ShopScreen.new(), &"inventory": InventoryScreen.new(), &"customize": CustomizeScreen.new(),
		&"trickbook": TrickbookScreen.new(), &"quests": QuestScreen.new(), &"achievements": AchievementScreen.new(),
		&"leaderboard": LeaderboardScreen.new(), &"settings": SettingsScreen.new(), &"daily": DailyScreen.new(),
		&"pause": PauseScreen.new(),
	}
	for key: StringName in screens:
		_root.add_child(screens[key])
		(screens[key] as UIScreen).closed.connect(_on_closed.bind(key))
	dialogue = DialogueBox.new()
	_root.add_child(dialogue)
	dialogue.finished.connect(_update_mouse)
	confirm = UIConfirm.new()
	_root.add_child(confirm)
	(screens[&"shop"] as ShopScreen).confirm = confirm
	(screens[&"settings"] as SettingsScreen).confirm = confirm
	var pause := screens[&"pause"] as PauseScreen
	pause.navigate.connect(open)
	pause.quit_to_menu.connect(_on_quit_to_menu)
	pause.skip_tutorial.connect(_skip_tutorial)
	photo = PhotoMode.new()
	photo.ui_root = _root
	add_child(photo)
	photo.toggled.connect(func(_on): _update_mouse())
	Events.open_screen.connect(open)
	Events.shop_requested.connect(open_shop)
	Events.dialogue_requested.connect(_on_dialogue)
	_update_mouse()


func start_tutorial() -> void:
	tutorial = TutorialOverlay.new()
	tutorial.player = player
	_root.add_child(tutorial)
	_root.move_child(tutorial, 1)


func _skip_tutorial() -> void:
	if is_instance_valid(tutorial):
		tutorial.finish()
	else:
		SaveSystem.tutorial_done = true
	(screens[&"pause"] as UIScreen).close()


func open(screen_name: StringName) -> void:
	if screen_name == &"shop":
		ShopScreen.next_category = &"gadget" # Shop öffnet bei den Vapes
		open_shop("Aura Katalog", ItemDef.Rarity.COMMON, ItemDef.Rarity.SECRET)
		return
	_show(screens.get(screen_name), screen_name)


func open_shop(shop_name: String, min_rarity: int, max_rarity: int) -> void:
	var shop := screens[&"shop"] as ShopScreen
	shop.set_shop(shop_name, min_rarity, max_rarity)
	_show(shop, &"shop")


func _show(s: UIScreen, screen_name: StringName) -> void:
	if s == null:
		return
	if current and current != s:
		current.visible = false # direkter Wechsel ohne „geschlossen“-Signal
	current = s
	s.open()
	if is_instance_valid(tutorial):
		tutorial.notify_screen(screen_name)
	_update_mouse()


func close_current() -> void:
	if current:
		current.close()


func _on_closed(key: StringName) -> void:
	if current == screens[key]:
		current = null
	_update_mouse()


func _on_dialogue(speaker: String, lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	dialogue.start(speaker, lines)
	_update_mouse()


func _on_quit_to_menu() -> void:
	current = null
	quit_to_menu.emit()


func is_ui_open() -> bool:
	return current != null or dialogue.visible or confirm.visible or (photo != null and photo.active)


func _update_mouse() -> void:
	var open_ui := is_ui_open()
	player.input_enabled = not open_ui
	if touch:
		touch.visible = not open_ui
	if DisplayServer.get_name() == "headless" or (photo != null and photo.active):
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open_ui else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventAction) or not event.is_pressed() or event.is_echo():
		return
	if dialogue.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("pause"):
			if event.is_action_pressed("pause"):
				dialogue.hide()
			else:
				dialogue.advance()
			_update_mouse()
			get_viewport().set_input_as_handled()
		return
	if photo.active:
		return
	if event.is_action_pressed("photo_mode") and current == null:
		photo.toggle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if confirm.visible:
			confirm.hide()
		elif current:
			current.close()
		else:
			open(&"pause")
		get_viewport().set_input_as_handled()
		return
	for action: String in HOTKEYS:
		if event.is_action_pressed(action):
			var target: StringName = HOTKEYS[action]
			if current and current == screens.get(target):
				current.close()
			elif not confirm.visible:
				open(target)
			get_viewport().set_input_as_handled()
			return

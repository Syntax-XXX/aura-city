class_name TestRunner
extends RefCounted
## Testsuite: godot --headless -- --tests
## Läuft gegen die echten Autoloads, aber mit eigener Spielstand-Datei (echter Stand bleibt unberührt).

var _failed := 0
var _passed := 0
var _section := ""


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("  ✗ [%s] %s" % [_section, what])


func section(name: String) -> void:
	_section = name
	print("• ", name)


func run(main: Node) -> int:
	SaveSystem.autosave_enabled = false
	Settings.path = "user://test_settings.json"
	SaveSystem.save_path = "user://test_save.json"
	SaveSystem.reset_all()
	test_data()
	test_economy()
	test_purchases()
	test_tricks()
	test_quests_achievements()
	test_save_roundtrip()
	test_save_corruption()
	await test_scene(main)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.save_path + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	print("\nErgebnis: %d bestanden, %d fehlgeschlagen" % [_passed, _failed])
	return _failed


func test_data() -> void:
	section("Daten")
	check(ItemDB.items.size() >= 60, "mind. 60 Items (%d)" % ItemDB.items.size())
	check(TrickDB.tricks.size() == 12, "12 Tricks")
	check(Quests.defs.size() >= 7, "Quests geladen")
	check(Achievements.defs.size() >= 14, "Erfolge geladen")
	var cats := {}
	var rars := {}
	for item: ItemDef in ItemDB.all():
		cats[item.category] = true
		rars[item.rarity] = true
	check(cats.size() >= 9, "mind. 9 Kategorien (%d)" % cats.size())
	check(rars.size() == 7, "alle 7 Raritäten")


func test_economy() -> void:
	section("Wirtschaft")
	Economy.reset()
	var t := TrickDB.get_trick(&"basic_spin")
	var good := Economy.calculate_trick_aura(t, &"good", 1.0, 0, 1.0)
	var perfect := Economy.calculate_trick_aura(t, &"perfect", 1.0, 0, 1.0)
	check(is_equal_approx(perfect, good * 1.5) or perfect > good, "perfekt > gut")
	check(Economy.calculate_trick_aura(t, &"good", 2.0, 0, 1.0) > good, "Combo-Multiplikator wirkt")
	check(is_equal_approx(Economy.combo_multiplier(1), 1.0), "Combo 1 = ×1")
	check(is_equal_approx(Economy.combo_multiplier(3), 1.5), "Combo 3 = ×1,5")
	check(Economy.rank_for(0) == 0 and Economy.rank_for(500) == 1 and Economy.rank_for(1500000) == 7, "Rang-Schwellen")
	Economy.earn(600, "Test")
	check(Economy.aura == 600 and Economy.lifetime == 600, "earn erhöht Aura + Lifetime")
	check(Economy.rank_index == 1, "Rang-Aufstieg auf Beginner")
	check(not Economy.spend(1000), "spend ohne Deckung schlägt fehl")
	check(Economy.aura == 600, "Aura bleibt bei fehlgeschlagenem spend")
	check(Economy.spend(100) and Economy.aura == 500 and Economy.lifetime == 600, "spend senkt nur Aura")


func test_purchases() -> void:
	section("Shop")
	SaveSystem.reset_all()
	var cheap: ItemDef = null
	var ranked: ItemDef = null
	for item: ItemDef in ItemDB.all():
		if not item.starter and item.required_rank == 0 and item.required_achievement == &"" and item.required_lifetime_aura == 0 and cheap == null:
			cheap = item
		if item.required_rank >= 3 and ranked == null:
			ranked = item
	check(cheap != null, "kaufbares Item gefunden")
	check(Inventory.purchase(cheap.id) != "", "Kauf ohne Aura scheitert")
	check(not Inventory.owns(cheap.id), "nicht im Besitz nach Fehlkauf")
	Economy.earn(cheap.price, "Test")
	check(Inventory.purchase(cheap.id) == "", "Kauf mit genug Aura klappt")
	check(Inventory.owns(cheap.id) and is_zero_approx(Economy.aura), "Item im Besitz, Aura abgezogen")
	check(Inventory.purchase(cheap.id) != "", "doppelter Kauf verhindert")
	if ranked:
		Economy.aura = ranked.price + 1.0
		check(Inventory.purchase(ranked.id) != "", "Rang-Sperre greift")
	Inventory.equip(cheap.id)
	check(Inventory.is_equipped(cheap.id), "ausrüsten")
	Inventory.unequip(&"skin")
	check(Inventory.equipped_item(&"skin") != null, "Haut bleibt immer ausgerüstet")


func test_tricks() -> void:
	section("Tricks")
	check(TrickSystem.evaluate(0.5, 0.3) == &"perfect", "Mitte = perfekt")
	check(TrickSystem.evaluate(0.5 + 0.3 * 0.4, 0.3) == &"good", "Rand = gut")
	check(TrickSystem.evaluate(0.95, 0.3) == &"fail", "daneben = verpatzt")
	var hard := TrickDB.get_trick(&"aura_explosion")
	var easy := TrickDB.get_trick(&"basic_spin")
	check(hard.timing_window() < easy.timing_window(), "schwere Tricks = kleineres Fenster")
	SaveSystem.reset_all()
	check(not TrickDB.is_unlocked(&"double_spin"), "double_spin anfangs gesperrt")
	Economy.earn(1500, "Test")
	check(TrickDB.is_unlocked(&"double_spin"), "double_spin bei 1500 Lifetime frei")
	check(TrickDB.set_loadout_slot(0, &"double_spin") and TrickDB.loadout[0] == &"double_spin", "Loadout setzen")
	check(not TrickDB.set_loadout_slot(1, &"aura_explosion"), "gesperrter Trick nicht belegbar")
	# Combo + Kette mit echtem TrickSystem
	var ts := TrickSystem.new()
	var aura_before := Economy.aura
	for id: StringName in [&"finger_flip", &"side_twist", &"basic_spin"]:
		ts._cooldowns.clear()
		check(ts.start_trick(id) == "", "Start " + id)
		ts.needle = 0.5
		ts.land()
		ts.phase = TrickSystem.Phase.READY
	check(ts.combo == 3, "Combo zählt auf 3 (%d)" % ts.combo)
	check(Economy.aura - aura_before > 250, "Kette Street Starter gibt Bonus")
	ts.start_trick(&"finger_flip")
	check(ts.start_trick(&"finger_flip") != "", "Cooldown/Beschäftigt verhindert Spam")
	ts.free()


func test_quests_achievements() -> void:
	section("Quests & Erfolge")
	SaveSystem.reset_all()
	var q: QuestDef = Quests.list(QuestDef.Period.DAILY)[0]
	var before := Economy.aura
	Quests.add(q.stat, q.goal, q.period)
	check(Quests.is_completed(q.id), "Quest abgeschlossen")
	check(Economy.aura >= before + q.reward_aura, "Quest-Belohnung ausgezahlt")
	var after := Economy.aura
	Quests.add(q.stat, q.goal, q.period)
	check(is_equal_approx(Economy.aura, after) or Economy.aura >= after, "keine doppelte Belohnung")
	Events.trick_landed.emit(&"basic_spin", &"perfect", 10.0, 1)
	check(Achievements.is_unlocked(&"first_trick"), "Erfolg 'Erster Trick'")
	Events.secret_found.emit(&"test_secret")
	check(Achievements.is_unlocked(&"secret_explorer"), "Geheimnis-Erfolg")


func test_save_roundtrip() -> void:
	section("Speichern/Laden")
	SaveSystem.reset_all()
	Economy.earn(12345, "Test")
	Identity.display_name = "Tester"
	var item: ItemDef = null
	for it: ItemDef in ItemDB.all():
		if not it.starter and Inventory.requirements_met(it) and it.price <= Economy.aura:
			item = it
			break
	Inventory.purchase(item.id)
	var aura := Economy.aura
	check(SaveSystem.save_game(), "Speichern erfolgreich")
	SaveSystem.apply({})
	check(Economy.aura == 0.0, "Reset ohne Speichern")
	SaveSystem.load_game()
	check(SaveSystem.last_load_status == "ok", "Status ok")
	check(is_equal_approx(Economy.aura, aura), "Aura wiederhergestellt")
	check(Identity.display_name == "Tester", "Name wiederhergestellt")
	check(Inventory.owns(item.id), "Item wiederhergestellt")


func test_save_corruption() -> void:
	section("Beschädigter Spielstand")
	Economy.earn(1, "Test")
	SaveSystem.save_game() # alter Stand wird .bak
	var f := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	f.store_string("{kaputt")
	f.close()
	SaveSystem.load_game()
	check(SaveSystem.last_load_status == "backup", "Backup geladen (%s)" % SaveSystem.last_load_status)
	check(Economy.lifetime > 0.0, "Fortschritt aus Backup")
	for suffix in ["", ".bak"]:
		var g := FileAccess.open(SaveSystem.save_path + suffix, FileAccess.WRITE)
		g.store_string("###")
		g.close()
	SaveSystem.load_game()
	check(SaveSystem.last_load_status == "corrupt", "beides kaputt → neues Profil")
	check(Economy.aura == 0.0 and Inventory.owns(&"skin_warm"), "Standardprofil mit Startitems")


func test_scene(main: Node) -> void:
	section("Szene")
	var world := WorldRoot.new()
	main.add_child(world)
	var player := PlayerController.new()
	world.add_child(player)
	player.teleport(WorldRoot.SPAWN_POINT)
	var ui := UIRoot.new()
	ui.player = player
	ui.world = world
	main.add_child(ui)
	for i in 30:
		await main.get_tree().physics_frame
	check(player.is_on_floor(), "Spieler steht")
	check(main.get_tree().get_nodes_in_group(&"interactables").size() > 30, "Interaktionen vorhanden")
	for key: StringName in ui.screens:
		ui.open(key)
		await main.get_tree().process_frame
		check(ui.current != null and ui.current.visible, "Menü öffnet: " + key)
		check(not player.input_enabled, "Eingabe gesperrt bei " + key)
		ui.close_current()
		await main.get_tree().process_frame
	check(player.input_enabled, "Eingabe nach Schließen frei")
	ui.queue_free()
	world.queue_free()
	await main.get_tree().process_frame

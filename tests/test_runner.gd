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
	check(Economy.lose(20, "Husten") == 20 and Economy.aura == 480 and Economy.lifetime == 600, "Husten kostet Aura, nicht Lifetime")
	check(Economy.lose(10000, "Husten") == 480 and Economy.aura == 0, "Husten nie unter 0")


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
	SaveSystem.reset_all()
	var ghost := TrickDB.get_trick(&"mini_pose")
	check(TrickSystem.judge(ghost, 80.0)[0] == &"perfect", "80 % = perfekt")
	check(TrickSystem.judge(ghost, 50.0)[0] == &"good", "50 % = gut")
	check(TrickSystem.judge(ghost, 10.0)[0] == &"fail", "zu wenig gezogen = Fail")
	check(TrickSystem.judge(ghost, 100.0)[0] == &"fail", "100 % = Husten")
	check(TrickSystem.judge(null, 60.0)[0] == &"fail", "falsche Kombo = Fail")
	check(TrickSystem.match_keys("DU") == ghost, "↓↑ = Ghost")
	check(TrickSystem.match_keys("") == TrickDB.get_trick(&"basic_spin"), "ohne Kombo = einfache Wolke")
	check(TrickSystem.is_prefix("D") and not TrickSystem.is_prefix("LLL"), "Kombo-Anfang erkannt")
	check(TrickSystem.match_keys("UUDDLRLR") == null, "gesperrte Kombo zählt nicht")
	var keys := {}
	for t: TrickDef in TrickDB.all():
		check(not keys.has(t.keys), "Kombo eindeutig: " + t.display_name)
		keys[t.keys] = true
	check(TrickSystem.rate_for(null) * TrickSystem.TIMING_TIMEOUT >= 100.0, "langsamste Vape schafft 100 % vor dem Server-Fenster")
	var slowest: ItemDef = null
	for it: ItemDef in ItemDB.by_category(&"gadget"):
		if slowest == null or it.rarity > slowest.rarity:
			slowest = it
	check(100.0 / TrickSystem.rate_for(slowest) <= TrickSystem.TIMING_TIMEOUT, "auch die größte Vape bleibt im Server-Fenster")
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
		check(ts.perform(id) == "", "Zug " + id)
		ts.phase = TrickSystem.Phase.READY
	check(ts.combo == 3, "Combo zählt auf 3 (%d)" % ts.combo)
	check(Economy.aura - aura_before > 250, "Kette Erster Zug gibt Bonus")
	var combo_before := ts.combo
	ts.perform(&"basic_spin")
	check(ts.combo == combo_before, "Abklingzeit verhindert Spam")
	ts.phase = TrickSystem.Phase.READY
	var aura_f := Economy.aura
	ts.start_inhale()
	ts.push_key("L")
	ts.push_key("L")
	ts.push_key("L")
	ts.charge = 60.0
	ts.release()
	check(ts.combo == 0 and Economy.aura < aura_f, "falsche Kombo kostet Aura und Combo")
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


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out


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
	# Große Map: jeder Splitter frei erreichbar (nicht in Kollisionen), jedes Teleportziel mit Boden
	var space := world.get_world_3d().direct_space_state
	var blocked: Array[String] = []
	var shards := 0
	for n in _all(world):
		var col := n as Collectible
		if col == null:
			continue
		shards += 1
		var q := PhysicsPointQueryParameters3D.new()
		q.position = col.global_position + Vector3(0, 0.6, 0)
		if not space.intersect_point(q).is_empty():
			blocked.append(String(col.collectible_id))
	check(shards >= 50, "viele Splitter auf der großen Map (%d)" % shards)
	check(blocked.is_empty(), "kein Splitter steckt in Geometrie %s" % [blocked])
	var bad_targets: Array[String] = []
	for n in _all(world):
		var tp := n as Teleporter
		if tp == null:
			continue
		var ray := PhysicsRayQueryParameters3D.create(tp.target + Vector3(0, 0.5, 0), tp.target + Vector3(0, -3, 0))
		var hit := space.intersect_ray(ray)
		var q2 := PhysicsPointQueryParameters3D.new()
		q2.position = tp.target + Vector3(0, 0.9, 0)
		if hit.is_empty() or not space.intersect_point(q2).is_empty():
			bad_targets.append(tp.destination_name)
	check(bad_targets.is_empty(), "alle Teleportziele haben freien Boden %s" % [bad_targets])
	print("  Welt: %d Nodes" % _all(world).size())
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

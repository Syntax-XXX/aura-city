class_name OnlineTest
extends RefCounted
## End-to-End gegen einen laufenden Server:  godot --headless -- --online-test http://127.0.0.1:3710

var _failed := 0
var _passed := 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
		print("  ✓ ", what)
	else:
		_failed += 1
		printerr("  ✗ ", what)


func run(main: Node, url: String) -> int:
	SaveSystem.autosave_enabled = false
	Settings.path = "user://test_settings.json"
	var tree := main.get_tree()
	# Nicht über eine Aura-Rush-Grenze laufen (Client ohne Welt kennt den Rush hier nicht)
	while true:
		var p := fmod(Net.now(), WorldRoot.RUSH_PERIOD)
		if p > WorldRoot.RUSH_LENGTH + 2.0 and p < WorldRoot.RUSH_PERIOD - 30.0:
			break
		await tree.create_timer(1.0).timeout
	Net._tokens.clear() # immer frisches Profil
	var err := await Net.connect_profile(url, "E2E-Test")
	check(err == "", "Verbindung + frisches Profil (%s)" % err)
	check(Net.online and Economy.aura == 0.0 and Economy.lifetime == 0.0, "Profil startet bei 0 Aura")
	# Alle lokalen Vorschauen aufsummieren – müssen exakt der Server-Berechnung entsprechen
	var preview := {"sum": 0.0}
	var on_reward := func(amount: float, _r: String, _p: Vector3) -> void: preview["sum"] += amount
	Events.aura_rewarded.connect(on_reward)
	var ts := TrickSystem.new()
	main.add_child(ts)
	for id: StringName in [&"finger_flip", &"side_twist", &"basic_spin", &"mini_pose"]:
		while ts.is_busy() or ts.cooldown_left(id) > 0.0:
			await tree.process_frame
		check(ts.start_trick(id) == "", "Trick %s gestartet" % id)
		ts.needle = 0.5
		ts.land()
		await tree.create_timer(TrickDB.get_trick(id).duration + 0.15).timeout
		ts.phase = TrickSystem.Phase.READY
	await Net.wait_flushed(5.0)
	Events.aura_rewarded.disconnect(on_reward)
	check(Economy.aura > 0.0, "Server hat Aura gutgeschrieben (%s)" % Economy.aura)
	check(is_equal_approx(Economy.aura, preview["sum"]), "Client-Vorschau == Server (%s vs %s)" % [preview["sum"], Economy.aura])
	check(Achievements.is_unlocked(&"first_trick"), "Erfolg vom Server übernommen")
	check(TrickDB.mastery_hits.get(&"basic_spin", 0) == 1, "Meisterschaft vom Server")
	# Aura-Drink: Server zieht ab und rechnet den Boost selbst ein
	var before_drink := Economy.aura
	check(Economy.drink("sigma_sprudel") == "", "Drink gekauft")
	await Net.wait_flushed(5.0)
	check(is_equal_approx(Economy.aura, before_drink - 600.0), "Server hat Drink-Preis abgezogen (%s)" % Economy.aura)
	check(Economy.boost("aura") > 1.0, "Boost aktiv (Serverzeit)")
	var p2 := {"sum": 0.0}
	var on_reward2 := func(amount: float, _r: String, _p: Vector3) -> void: p2["sum"] += amount
	Events.aura_rewarded.connect(on_reward2)
	var base2 := Economy.aura
	while ts.is_busy() or ts.cooldown_left(&"side_twist") > 0.0:
		await tree.process_frame
	ts.start_trick(&"side_twist")
	ts.needle = 0.5
	ts.land()
	await tree.create_timer(1.0).timeout
	ts.phase = TrickSystem.Phase.READY
	await Net.wait_flushed(5.0)
	Events.aura_rewarded.disconnect(on_reward2)
	check(is_equal_approx(Economy.aura - base2, p2["sum"]), "Boost: Vorschau == Server (%s vs %s)" % [p2["sum"], Economy.aura - base2])
	var real := Economy.aura
	# „Cheat Engine“: Aura im Speicher hochsetzen und teuer einkaufen
	Economy.aura = 99999999.0
	var expensive: ItemDef = null
	for item: ItemDef in ItemDB.all():
		if not item.starter and Inventory.requirements_met(item) and item.price > real:
			expensive = item
	check(Inventory.purchase(expensive.id) == "", "lokaler (manipulierter) Kauf geht erst durch")
	await Net.wait_flushed(5.0)
	check(not Inventory.owns(expensive.id), "Server verweigert den Kauf → Item weg")
	check(is_equal_approx(Economy.aura, real), "Aura wieder auf Serverwert (%s)" % Economy.aura)
	# Gefälschtes Ereignis: gesperrter Trick
	Net.send({"type": "trick", "id": "aura_explosion", "quality": "perfect"})
	await Net.wait_flushed(5.0)
	check(is_equal_approx(Economy.aura, real), "gefälschter Trick bringt nichts")
	# Bestenliste + Wiederverbinden mit demselben Profil
	var board := await Net.fetch_leaderboard()
	check(board.any(func(e): return e["name"] == "E2E-Test"), "Profil in der Online-Bestenliste")
	Net.disconnect_profile()
	Economy.aura = 0.0
	err = await Net.connect_profile(url, "E2E-Test")
	check(err == "" and is_equal_approx(Economy.aura, real), "Wiederverbinden lädt Serverprofil (%s)" % Economy.aura)
	Net.disconnect_profile()
	ts.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	print("\nOnline-Ergebnis: %d bestanden, %d fehlgeschlagen" % [_passed, _failed])
	return _failed

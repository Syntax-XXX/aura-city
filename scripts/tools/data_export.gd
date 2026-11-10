class_name DataExport
extends RefCounted
## Exportiert alle spielrelevanten Regeln/Daten als JSON für den Server (eine Quelle der Wahrheit):
##   godot --headless -- --export-data server/data/gamedata.json

static func run(main: Node, path: String) -> bool:
	var data := {
		"version": 1,
		"constants": {
			"combo_window": TrickSystem.COMBO_WINDOW, "timing_timeout": TrickSystem.TIMING_TIMEOUT,
			"combo_cap": Economy.COMBO_CAP, "fail_loss": Economy.FAIL_LOSS, "daily_base": Economy.DAILY_REWARD_BASE,
			"quality_mult": {"perfect": Economy.QUALITY_MULT[&"perfect"], "good": Economy.QUALITY_MULT[&"good"]},
			"mastery_steps": TrickDB.MASTERY_STEPS, "challenge_mult": 1.5,
			"collectible_respawn": Collectible.RESPAWN_SECONDS, "secret_multiplier": 10,
			"rush": {"period": WorldRoot.RUSH_PERIOD, "length": WorldRoot.RUSH_LENGTH, "multiplier": WorldRoot.RUSH_MULTIPLIER},
		},
		"ranks": Economy.RANKS.map(func(r): return {"name": r["name"], "min": r["min"]}),
		"chains": TrickDB.CHAINS.map(func(c): return {"name": c["name"], "sequence": c["sequence"].map(func(s): return String(s)), "bonus": c["bonus"]}),
		"starter_loadout": ["basic_spin", "finger_flip", "mini_pose", "side_twist"],
		"slots": Inventory.SLOTS.map(func(s): return String(s)),
		"tricks": {}, "items": {}, "quests": {}, "achievements": {}, "challenges": {}, "collectibles": {},
		"districts": DistrictArea.NAMES.keys().map(func(k): return String(k)),
		"drinks": {},
	}
	for d in Drinks.LIST:
		data["drinks"][d["id"]] = {"name": d["name"], "price": d["price"], "rank": d["rank"], "seconds": d["seconds"], "aura": d["aura"]}
	for t: TrickDef in TrickDB.all():
		data["tricks"][String(t.id)] = {"name": t.display_name, "difficulty": t.difficulty, "base_aura": t.base_aura,
			"duration": t.duration, "cooldown": t.cooldown, "combo_bonus": t.combo_bonus, "unlock": t.unlock_lifetime_aura}
	for i: ItemDef in ItemDB.all():
		data["items"][String(i.id)] = {"name": i.display_name, "price": i.price, "rarity": i.rarity, "slot": String(i.slot()),
			"required_rank": i.required_rank, "required_lifetime": i.required_lifetime_aura,
			"required_achievement": String(i.required_achievement), "starter": i.starter}
	for q: QuestDef in Quests.defs.values():
		data["quests"][String(q.id)] = {"name": q.display_name, "period": q.period, "stat": String(q.stat), "goal": q.goal, "reward": q.reward_aura}
	for a: AchievementDef in Achievements.defs.values():
		data["achievements"][String(a.id)] = {"name": a.display_name, "stat": String(a.stat), "goal": a.goal, "reward": a.reward_aura}
	# Welt aufbauen, um Challenges und Splitter mit ihren echten Werten einzusammeln
	var world := WorldRoot.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	main.add_child(world)
	_collect(world, data)
	world.free()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("Export fehlgeschlagen: ", path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("Export: %d Tricks, %d Items, %d Challenges, %d Splitter → %s" % [data["tricks"].size(), data["items"].size(), data["challenges"].size(), data["collectibles"].size(), path])
	return true


static func _collect(node: Node, data: Dictionary) -> void:
	var cz := node as ChallengeZone
	if cz:
		assert(not data["challenges"].has(cz.challenge_name), "Challenge-Name doppelt: " + cz.challenge_name)
		data["challenges"][cz.challenge_name] = {"kind": cz.kind, "goal": cz.goal, "seconds": cz.seconds, "reward": cz.reward}
	var col := node as Collectible
	if col:
		assert(not data["collectibles"].has(String(col.collectible_id)), "Splitter-ID doppelt: " + col.collectible_id)
		data["collectibles"][String(col.collectible_id)] = {"secret": col.secret, "reward": col.reward}
	for c in node.get_children():
		_collect(c, data)

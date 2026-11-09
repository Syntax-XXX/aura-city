extends Node
## Globaler Signal-Bus. Systeme kennen sich nicht direkt, sie reden über diese Signale.

# Wirtschaft
signal aura_changed(current: float, delta: float)
signal rank_changed(rank_index: int)
signal aura_rewarded(amount: float, reason: String, world_position: Vector3)

# Tricks
signal trick_started(trick_id: StringName)
signal trick_landed(trick_id: StringName, quality: StringName, aura: float, combo: int)
signal trick_failed(trick_id: StringName)
signal combo_changed(combo: int, multiplier: float)
signal combo_ended(final_combo: int)
signal chain_completed(chain_name: String)
signal trick_unlocked(trick_id: StringName)
signal mastery_up(trick_id: StringName, level: int)

# Inventar / Shop
signal item_purchased(item_id: StringName)
signal item_unlocked(item_id: StringName)
signal item_equipped(slot: StringName, item_id: StringName)
signal purchase_failed(item_id: StringName, reason: String)

# Welt
signal district_entered(district_id: StringName)
signal collectible_found(collectible_id: StringName)
signal challenge_started(challenge_name: String)
signal challenge_completed(challenge_name: String, reward: float)
signal challenge_failed(challenge_name: String)
signal challenge_status(text: String)
signal interaction_prompt(text: String)
signal dialogue_requested(speaker: String, lines: PackedStringArray)
signal teleport_requested(target: Vector3)
signal aura_event_started(multiplier: float, seconds: float)
signal aura_event_ended

# Fortschritt
signal quest_progressed(quest_id: StringName, progress: int, goal: int)
signal quest_completed(quest_id: StringName)
signal achievement_unlocked(achievement_id: StringName)

# Oberfläche
signal toast(text: String, color: Color)
signal open_screen(screen_name: StringName)
signal shop_requested(shop_name: String, min_rarity: int, max_rarity: int)
signal secret_found(secret_id: StringName)
signal drink_used(drink_id: String)
signal settings_changed
signal game_saved

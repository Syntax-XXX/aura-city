extends Node
## Aura-Wirtschaft: aktueller Stand, Lifetime, Ränge, Level, Aura/Minute, Events, Tagesbelohnung.
## Gutschriften und Käufe laufen immer über `authority` (Grenze für späteren Server).

const RANKS := [
	{"name": "NPC", "min": 0, "color": Color("9ca3af"), "glow": 0.0},
	{"name": "Beginner", "min": 500, "color": Color("4ade80"), "glow": 0.0},
	{"name": "Main Character", "min": 2500, "color": Color("38bdf8"), "glow": 0.2},
	{"name": "Street Legend", "min": 10000, "color": Color("a855f7"), "glow": 0.35},
	{"name": "Aura Master", "min": 40000, "color": Color("f472b6"), "glow": 0.5},
	{"name": "Sigma", "min": 120000, "color": Color("f59e0b"), "glow": 0.7},
	{"name": "Godlike", "min": 400000, "color": Color("fde047"), "glow": 0.85},
	{"name": "Beyond Reality", "min": 1500000, "color": Color("22d3ee"), "glow": 1.0},
]
const QUALITY_MULT := {&"perfect": 1.5, &"good": 1.0}
const DAILY_REWARD_BASE := 250
const COMBO_CAP := 6.0

var aura := 0.0
var lifetime := 0.0
var rank_index := 0
var event_multiplier := 1.0
var authority: EconomyAuthority = EconomyAuthority.new()
var daily_last_claim := "" # JJJJ-MM-TT
var daily_streak := 0

var _event_left := 0.0
var _history: Array = [] # [sekunden, betrag]
var _clock := 0.0


func _process(delta: float) -> void:
	_clock += delta
	if _event_left > 0.0:
		_event_left -= delta
		if _event_left <= 0.0:
			event_multiplier = 1.0
			Events.aura_event_ended.emit()


func reset() -> void:
	aura = 0.0
	lifetime = 0.0
	rank_index = 0
	daily_last_claim = ""
	daily_streak = 0
	_history.clear()


## Aura gutschreiben. Liefert den tatsächlich gutgeschriebenen Betrag.
func earn(amount: float, reason: String, world_position := Vector3.ZERO) -> float:
	if amount <= 0.0:
		return 0.0
	if Net.online:
		# Online rechnet allein der Server (Net meldet das Ereignis); hier nur die Vorschau für Effekte.
		var preview := roundf(amount * event_multiplier)
		Events.aura_rewarded.emit(preview, reason, world_position)
		return preview
	var granted := roundf(authority.grant(amount * event_multiplier, reason))
	if granted <= 0.0:
		return 0.0
	aura += granted
	lifetime += granted
	_history.append([_clock, granted])
	Events.aura_changed.emit(aura, granted)
	Events.aura_rewarded.emit(granted, reason, world_position)
	_update_rank()
	TrickDB.check_unlocks(lifetime)
	return granted


## Bezahlen. false, wenn nicht genug Aura.
func spend(amount: float) -> bool:
	if amount < 0.0 or aura < amount:
		return false
	aura -= amount
	Events.aura_changed.emit(aura, -amount)
	return true


func can_afford(amount: float) -> bool:
	return aura >= amount


## Reine Berechnung (testbar): Basis × Schwierigkeit × Qualität × Combo × Meisterschaft × Challenge × Event.
func calculate_trick_aura(trick: TrickDef, quality: StringName, combo_multiplier: float, mastery_level: int, challenge_multiplier := 1.0) -> float:
	var difficulty_mult := 1.0 + trick.difficulty * 0.08
	var mastery_mult := 1.0 + mastery_level * 0.1
	var q: float = QUALITY_MULT.get(quality, 0.0)
	return roundf(trick.base_aura * difficulty_mult * q * clampf(combo_multiplier, 1.0, COMBO_CAP) * mastery_mult * challenge_multiplier)


func combo_multiplier(combo: int) -> float:
	return clampf(1.0 + (combo - 1) * 0.25, 1.0, COMBO_CAP)


func start_event(multiplier: float, seconds: float) -> void:
	event_multiplier = multiplier
	_event_left = seconds
	Events.aura_event_started.emit(multiplier, seconds)


func event_seconds_left() -> float:
	return maxf(0.0, _event_left)


## Aura pro Minute über die letzten 60 Sekunden.
func aura_per_minute() -> float:
	var sum := 0.0
	var keep: Array = []
	for e in _history:
		if _clock - float(e[0]) <= 60.0:
			sum += float(e[1])
			keep.append(e)
	_history = keep
	return sum


func level() -> int:
	return int(sqrt(lifetime / 100.0)) + 1


## Fortschritt im aktuellen Level (0–1).
func level_progress() -> float:
	var lv := level()
	var lo := pow(lv - 1, 2) * 100.0
	var hi := pow(lv, 2) * 100.0
	return clampf((lifetime - lo) / (hi - lo), 0.0, 1.0)


func rank_for(lifetime_aura: float) -> int:
	var idx := 0
	for i in RANKS.size():
		if lifetime_aura >= float(RANKS[i]["min"]):
			idx = i
	return idx


func rank_name(i := -1) -> String:
	return RANKS[rank_index if i < 0 else i]["name"]


func rank_color(i := -1) -> Color:
	return RANKS[rank_index if i < 0 else i]["color"]


## Anteil bis zum nächsten Rang (0–1) und dessen Name.
func next_rank_progress() -> Dictionary:
	if rank_index >= RANKS.size() - 1:
		return {"name": "", "progress": 1.0, "missing": 0.0}
	var cur: float = RANKS[rank_index]["min"]
	var nxt: float = RANKS[rank_index + 1]["min"]
	return {"name": RANKS[rank_index + 1]["name"], "progress": clampf((lifetime - cur) / (nxt - cur), 0.0, 1.0), "missing": nxt - lifetime}


func _update_rank() -> void:
	var r := rank_for(lifetime)
	if r != rank_index:
		var up := r > rank_index
		rank_index = r
		Events.rank_changed.emit(r)
		if up:
			Audio.play(&"rank_up")
			Events.toast.emit("Neuer Rang: %s" % rank_name(), rank_color())


# ── Tagesbelohnung ───────────────────────────────────────
func today() -> String:
	return Time.get_date_string_from_system()


func daily_available() -> bool:
	return daily_last_claim != today()


## Belohnung für heute (steigt mit der Serie, max. 7 Tage).
func daily_amount() -> int:
	var streak := daily_streak + 1 if _claimed_yesterday() else 1
	return DAILY_REWARD_BASE * mini(streak, 7)


func claim_daily() -> int:
	if not daily_available():
		return 0
	daily_streak = daily_streak + 1 if _claimed_yesterday() else 1
	daily_last_claim = today()
	var amount := DAILY_REWARD_BASE * mini(daily_streak, 7)
	earn(amount, "Tagesbelohnung")
	Net.send({"type": "daily"})
	return amount


func _claimed_yesterday() -> bool:
	if daily_last_claim == "":
		return false
	var y := Time.get_unix_time_from_system() - 86400
	return Time.get_date_string_from_unix_time(int(y)) == daily_last_claim


# ── Speichern ────────────────────────────────────────────
func to_dict() -> Dictionary:
	return {"aura": aura, "lifetime": lifetime, "daily_last_claim": daily_last_claim, "daily_streak": daily_streak}


## Stand vom Server übernehmen (Online-Modus): einzige Quelle für Aura und Lifetime.
func apply_server(d: Dictionary) -> void:
	var old := aura
	aura = maxf(0.0, float(d.get("aura", aura)))
	lifetime = maxf(aura, float(d.get("lifetime", lifetime)))
	daily_last_claim = str(d.get("daily_last_claim", daily_last_claim))
	daily_streak = maxi(0, int(d.get("daily_streak", daily_streak)))
	var delta := aura - old
	if delta != 0.0:
		if delta > 0.0:
			_history.append([_clock, delta])
		Events.aura_changed.emit(aura, delta)
	_update_rank()
	TrickDB.check_unlocks(lifetime)


func from_dict(d: Dictionary) -> void:
	aura = maxf(0.0, float(d.get("aura", 0.0)))
	lifetime = maxf(aura, float(d.get("lifetime", 0.0)))
	daily_last_claim = str(d.get("daily_last_claim", ""))
	daily_streak = maxi(0, int(d.get("daily_streak", 0)))
	rank_index = rank_for(lifetime)

class_name TrickDef
extends Resource
## Ein Dampf-Zug (Wolkenform). Liegt als .tres unter res://resources/tricks/ (IDs historisch, Server nutzt sie).

enum Tier { BEGINNER, ADVANCED, LEGENDARY }
const TIER_NAMES := ["Beginner", "Advanced", "Legendary"]

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var tier: Tier = Tier.BEGINNER
## 1–10: bestimmt Timing-Fenster, Nadeltempo und Bonus
@export_range(1, 10) var difficulty := 1
@export var base_aura := 50
## Animationsdauer in Sekunden
@export var duration := 0.8
@export var cooldown := 1.0
## Zusatz auf den Combo-Multiplikator, wenn dieser Trick in einer Kette landet
@export var combo_bonus := 0.25
## Name der prozeduralen Animation (siehe player_animator.gd)
@export var animation: StringName = &"spin"
@export var effect_color := Color("c084fc")
@export var sound_pitch := 1.0
## Freischaltung über Lifetime-Aura (0 = von Anfang an)
@export var unlock_lifetime_aura := 0
## Wolkenform beim Ausatmen (siehe FX.vape_cloud) und wie oft sie wiederholt wird
@export var cloud_shape: StringName = &"puff"
@export var cloud_count := 1
## Pfeil-Kombo beim Ziehen: U/D/L/R, leer = einfache Wolke ohne Kombo
@export var keys := ""
## So weit (0–100 %) muss mindestens gezogen sein
@export var min_charge := 0



## Kombo als Pfeile zum Anzeigen.
func arrows() -> String:
	return TrickDef.to_arrows(keys)


static func to_arrows(k: String) -> String:
	var out := PackedStringArray()
	for c in k:
		out.append({"U": "↑", "D": "↓", "L": "←", "R": "→"}.get(c, c))
	return " ".join(out)

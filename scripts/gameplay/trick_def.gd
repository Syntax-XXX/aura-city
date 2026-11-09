class_name TrickDef
extends Resource
## Ein Trick. Liegt als .tres unter res://resources/tricks/.

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


## Größe des Treffer-Fensters (0–1 der Leiste); schwierige Tricks sind enger.
func timing_window() -> float:
	return clampf(0.34 - difficulty * 0.022, 0.1, 0.34)


## Geschwindigkeit der Timing-Nadel (Durchläufe pro Sekunde).
func needle_speed() -> float:
	return 0.55 + difficulty * 0.09

class_name AchievementDef
extends Resource
## Ein Achievement. Liegt unter res://resources/achievements/.

@export var id: StringName
@export var display_name := ""
@export var description := ""
@export var icon_glyph := "★"
## Gezählte Größe: tricks, best_combo, lifetime_aura, legendary_items, secret_found, rank, collectibles, perfects, districts
@export var stat: StringName = &"tricks"
@export var goal := 1
@export var reward_aura := 100
## Versteckt, bis freigeschaltet
@export var secret := false

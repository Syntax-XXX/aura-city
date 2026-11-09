class_name QuestDef
extends Resource
## Tägliche oder wöchentliche Aufgabe. Liegt unter res://resources/quests/.

enum Period { DAILY, WEEKLY }

@export var id: StringName
@export var display_name := ""
@export var description := ""
@export var period: Period = Period.DAILY
## Welches Ereignis zählt: trick, combo, district, collectible, aura, challenge, unlock
@export var stat: StringName = &"trick"
@export var goal := 10
@export var reward_aura := 200

class_name ItemDef
extends Resource
## Ein kosmetisches Item. Liegt als .tres unter res://resources/items/.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC, SECRET }

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
const RARITY_COLORS := [Color("9ca3af"), Color("4ade80"), Color("38bdf8"), Color("a855f7"), Color("f59e0b"), Color("f43f5e"), Color("22d3ee")]
## Kategorie -> Ausrüstungs-Slot
const CATEGORY_SLOTS := {
	&"gadget": &"gadget", &"skin": &"skin", &"outfit": &"outfit", &"trail": &"trail",
	&"particle": &"particle", &"animation": &"animation", &"emote": &"emote", &"title": &"title",
	&"accessory": &"accessory", &"hair": &"hair", &"shoes": &"shoes", &"board": &"board",
}
const CATEGORY_NAMES := {
	&"gadget": "Cosmetic Gadgets", &"skin": "Skins", &"outfit": "Outfits", &"trail": "Trails",
	&"particle": "Particle Effects", &"animation": "Animations", &"emote": "Emotes", &"title": "Titles",
	&"accessory": "Accessories", &"hair": "Hair", &"shoes": "Shoes", &"board": "Hoverboards",
}

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var price := 0
@export var rarity: Rarity = Rarity.COMMON
@export var category: StringName = &"gadget"
## Symbol für das prozedurale Icon (ein Zeichen)
@export var icon_glyph := "?"
@export var icon: Texture2D
## Hauptfarbe (Kleidung, Partikel, Gadget …)
@export var color := Color.WHITE
@export var accent_color := Color.WHITE
## Variante für Modelle/Animationen (z. B. Frisur "spiky", Emote "wave")
@export var variant: StringName = &""
## Freischalt-Bedingungen: Rang-Index, Lifetime-Aura, Achievement
@export var required_rank := 0
@export var required_lifetime_aura := 0
@export var required_achievement: StringName = &""
## Nur im Shop sichtbar, wenn freigeschaltet (Secret-Items)
@export var hidden_until_unlocked := false
## Kostenlos von Anfang an im Besitz
@export var starter := false


func slot() -> StringName:
	return CATEGORY_SLOTS.get(category, category)


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func rarity_color() -> Color:
	return RARITY_COLORS[rarity]

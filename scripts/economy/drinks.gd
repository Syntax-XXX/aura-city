class_name Drinks
extends RefCounted
## Aura-Drinks: fiktive, harmlose Erfrischungen (Limo, Mate, Shakes) mit zeitlich begrenzten Boosts.
## Immer nur ein Drink aktiv, ein neuer ersetzt den alten. Höhere Stufen brauchen einen höheren Rang.
##  aura   – Aura-Multiplikator (auch serverseitig wirksam)
##  speed  – Lauf-/Sprinttempo
##  timing – Größe des Timing-Fensters bei Tricks

const LIST := [
	{"id": "sigma_sprudel", "name": "Sigma Sprudel", "desc": "Zitronige Limo. Ein guter Start.", "price": 600, "rank": 0, "seconds": 120, "aura": 1.25, "speed": 1.0, "timing": 1.0, "color": "a3e635", "glyph": "◍"},
	{"id": "mc_mate", "name": "Main-Character-Mate", "desc": "Spritziger Mate – schneller und präziser.", "price": 1500, "rank": 1, "seconds": 180, "aura": 1.1, "speed": 1.15, "timing": 1.25, "color": "fbbf24", "glyph": "◒"},
	{"id": "neon_cola", "name": "Neon Cola", "desc": "Leuchtet im Dunkeln. Mehr Aura, mehr Tempo.", "price": 5000, "rank": 2, "seconds": 180, "aura": 1.5, "speed": 1.1, "timing": 1.1, "color": "22d3ee", "glyph": "◉"},
	{"id": "cloud_shake", "name": "Cloud Shake", "desc": "Fluffiger Milchshake für lange Sessions.", "price": 15000, "rank": 3, "seconds": 240, "aura": 1.6, "speed": 1.2, "timing": 1.3, "color": "f9a8d4", "glyph": "◌"},
	{"id": "sigma_smoothie", "name": "Sigma Smoothie", "desc": "Grün, ehrlich, überraschend stark.", "price": 45000, "rank": 4, "seconds": 300, "aura": 1.8, "speed": 1.2, "timing": 1.35, "color": "4ade80", "glyph": "✿"},
	{"id": "godlike_juice", "name": "Godlike Juice", "desc": "Goldener Saft der Elite.", "price": 120000, "rank": 5, "seconds": 300, "aura": 2.0, "speed": 1.25, "timing": 1.4, "color": "fde047", "glyph": "✦"},
	{"id": "void_elixir", "name": "Void Elixir", "desc": "Schmeckt nach Sternenstaub. Nur für Godlike.", "price": 400000, "rank": 6, "seconds": 300, "aura": 3.0, "speed": 1.3, "timing": 1.5, "color": "a855f7", "glyph": "✺"},
]


static func get_drink(id: String) -> Dictionary:
	for d in LIST:
		if d["id"] == id:
			return d
	return {}

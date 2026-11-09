class_name LocalLeaderboard
extends RefCounted
## Lokale Bestenliste: der Spieler gegen feste NPC-Rivalen (klar als NPC gekennzeichnet).
## Für Online-Ranglisten wird diese Klasse durch einen Server-Client mit derselben entries()-Schnittstelle ersetzt.

const RIVALS := [
	["Neon Nina", 2400000], ["Kevin Cloud", 900000], ["Sigma Sam", 320000], ["Lea Loop", 95000],
	["Mo Mist", 30000], ["Finn Flip", 8000], ["Aylin Air", 2200], ["Ben Basic", 600],
]


static func entries() -> Array:
	var list: Array = []
	for r in RIVALS:
		list.append({"name": r[0], "score": float(r[1]), "is_player": false, "rank": Economy.rank_for(r[1])})
	list.append({"name": Identity.display_name, "score": Economy.lifetime, "is_player": true, "rank": Economy.rank_index})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	return list


static func player_position() -> int:
	var list := entries()
	for i in list.size():
		if list[i]["is_player"]:
			return i + 1
	return list.size()

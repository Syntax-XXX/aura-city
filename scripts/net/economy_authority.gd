class_name EconomyAuthority
extends RefCounted
## Grenze für server-autoritative Wirtschaft.
## Heute entscheidet LocalEconomyAuthority lokal. Für Multiplayer wird hier eine
## Implementierung eingesetzt, die Gutschriften und Käufe vom Server bestätigen lässt –
## Spiel und Oberfläche müssen dafür nicht geändert werden.


## Bestätigt eine Aura-Gutschrift und liefert den tatsächlich gutgeschriebenen Betrag.
func grant(amount: float, _reason: String) -> float:
	return maxf(0.0, amount)


## Prüft einen Kauf. Leerer String = erlaubt, sonst Fehlertext.
func approve_purchase(item: ItemDef, current_aura: float) -> String:
	if item.price < 0:
		return "Ungültiger Preis"
	if current_aura < item.price:
		return "Nicht genug Aura"
	return ""

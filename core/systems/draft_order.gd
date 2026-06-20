class_name DraftOrder
extends RefCounted
## Berechnet die Pick-Reihenfolge des Relic-Drafts aus den Spielern (reine Logik,
## ohne Seiteneffekte → leicht testbar). Pro Stage zieht jeder Spieler genau ein
## Relic; Rückstand (weniger VP) wählt zuerst. Der Modus (SNAKE/CATCHUP) beeinflusst
## nicht die Reihenfolge, sondern nur die Ring-Größe (siehe main._draw_relic_pool).

## players: Array[Player]. Liefert die Spieler-Slots in Pick-Reihenfolge (Rückstand zuerst).
static func build(players: Array) -> Array[int]:
	var sorted := players.duplicate()
	sorted.sort_custom(_compare_by_vp)
	var order: Array[int] = []
	for p in sorted:
		order.append(p.id)
	return order


## Weniger VP zuerst; bei Gleichstand kleinere id (deterministisch).
static func _compare_by_vp(a: Player, b: Player) -> bool:
	if a.victory_points == b.victory_points:
		return a.id < b.id
	return a.victory_points < b.victory_points

class_name RelicAggressive
extends Relic
## Aggressiv/Interaktiv-Relic: wirkt auf Gegner. Aktuell: zusätzliche Diebstähle,
## wenn der Besitzer bei einer 7 bestiehlt.

## Anzahl zusätzlicher gestohlener Karten pro 7 (zusätzlich zum normalen Diebstahl).
@export var extra_steals: int = 0


func extra_steal_on_seven(_player: Player) -> int:
	return extra_steals

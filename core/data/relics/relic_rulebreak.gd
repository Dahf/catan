class_name RelicRulebreak
extends Relic
## Regelbrecher-Relic: hebt einzelne Catan-Regeln für den Besitzer auf.

## Straßen ohne Anbindung an eigene Gebäude/Straßen bauen.
@export var disconnected_roads: bool = false
## Abstandsregel beim Siedlungsbau ignorieren.
@export var ignore_distance: bool = false
## Immun gegen den Räuber (wird nie bestohlen).
@export var robber_immune: bool = false
## 2:1-Seehandel überall (aktuell inert — kein Seehandels-System vorhanden).
@export var trade_two_to_one: bool = false


func allows_disconnected_roads(_player: Player) -> bool:
	return disconnected_roads


func ignores_settlement_distance(_player: Player) -> bool:
	return ignore_distance


func is_robber_immune(_player: Player) -> bool:
	return robber_immune


func trade_ratio(_player: Player) -> int:
	return 2 if trade_two_to_one else 4

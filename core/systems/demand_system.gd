class_name DemandSystem
extends RefCounted
## Bevölkerungs-Nachfrage: Konsum von Gütern, Wachstum/Verfall, Aufstiegsstufen.
## Reine Logik über GameState.

const MAX_POP_TIER := 3
const TIER_UP_STREAK := 3      # so viele Runden in Folge versorgt -> Aufstieg
const TIER_DOWN_STREAK := -3   # so viele Runden in Folge Mangel -> Abstieg
const PERIODIC_PERIOD := 3     # alle X Runden wird die periodische Nachfrage fällig

## Laufende Güter-Nachfrage je Bevölkerungsstufe (jede Runde fällig).
const BASE_DEMAND_BY_TIER := {
	1: {&"grain": 1},
	2: {&"grain": 1},
	3: {&"grain": 1},
}

## Periodische Güter-Nachfrage je Bevölkerungsstufe (nur alle PERIODIC_PERIOD
## Runden fällig) - Tier 1 hat keine, damit der Einstieg ohne Wald/Erz möglich ist.
## TODO: auf verarbeitete Güter (Brot/Werkzeug/Kleidung) umstellen, sobald
## entsprechende Recipes existieren - greift vorerst auf Rohstoffe zurück.
const PERIODIC_DEMAND_BY_TIER := {
	2: {&"wood": 1},
	3: {&"wood": 1, &"ore": 1},
}


## Bevölkerung konsumiert benötigte Güter aus dem Lager.
func consume_goods() -> void:
	for vertex in GameState.settlements:
		var settlement : Settlement = GameState.settlements[vertex]
		settlement.upkeep_timer += 1
		var due := is_periodic_due(settlement)
		var demand := current_total_demand(settlement)
		if demand.is_empty() or GameState.can_afford(demand):
			settlement.supplied_streak = max(settlement.supplied_streak, 0) + 1
			if not demand.is_empty():
				GameState.spend(demand)
			if due:
				settlement.upkeep_timer = 0
		else:
			settlement.supplied_streak = min(settlement.supplied_streak, 0) - 1
			# Timer NICHT zurücksetzen, falls die periodische Forderung nicht
			# leistbar war - sie bleibt fällig und wird nächste Runde erneut versucht.


## Passt Bevölkerung/Tier an, je nachdem ob die Nachfrage erfüllt wurde.
func update_population() -> void:
	for vertex in GameState.settlements:
		var settlement : Settlement = GameState.settlements[vertex]
		if settlement.supplied_streak >= TIER_UP_STREAK and settlement.pop_tier < MAX_POP_TIER:
			settlement.pop_tier += 1
			settlement.supplied_streak = 0
		elif settlement.supplied_streak <= TIER_DOWN_STREAK and settlement.pop_tier > 1:
			settlement.pop_tier -= 1
			settlement.supplied_streak = 0


## Gibt true zurück, wenn die periodische Nachfrage einer Siedlung diese Runde fällig ist.
func is_periodic_due(settlement: Settlement) -> bool:
	return not PERIODIC_DEMAND_BY_TIER.get(settlement.pop_tier, {}).is_empty() \
		and settlement.upkeep_timer >= PERIODIC_PERIOD


## Liefert die laufende Güter-Nachfrage für eine Bevölkerungsstufe.
func base_demand_for_tier(tier: int) -> Dictionary:
	return BASE_DEMAND_BY_TIER.get(tier, {})


## Liefert die periodische Güter-Nachfrage für eine Bevölkerungsstufe.
func periodic_demand_for_tier(tier: int) -> Dictionary:
	return PERIODIC_DEMAND_BY_TIER.get(tier, {})


## Liefert die in dieser Runde tatsächlich fällige Gesamt-Nachfrage (Basis + ggf. periodisch).
func current_total_demand(settlement: Settlement) -> Dictionary:
	var demand := base_demand_for_tier(settlement.pop_tier).duplicate()
	if is_periodic_due(settlement):
		for id in periodic_demand_for_tier(settlement.pop_tier):
			demand[id] = demand.get(id, 0) + periodic_demand_for_tier(settlement.pop_tier)[id]
	return demand

class_name RelicSystem
extends RefCounted
## Aggregiert die Effekte aller Relics eines Spielers an EINER (testbaren) Stelle,
## damit Produktion/Platzierung/Wertung/Räuber nur abfragen statt iterieren müssen.

static func production_bonus(player: Player, ctx: Dictionary) -> int:
	var sum := 0
	for r in player.relics:
		sum += r.modify_production(ctx)
	return sum


static func robber_immune(player: Player) -> bool:
	for r in player.relics:
		if r.is_robber_immune(player):
			return true
	return false


static func disconnected_roads(player: Player) -> bool:
	for r in player.relics:
		if r.allows_disconnected_roads(player):
			return true
	return false


static func ignores_distance(player: Player) -> bool:
	for r in player.relics:
		if r.ignores_settlement_distance(player):
			return true
	return false


static func bonus_vp(player: Player) -> int:
	var sum := 0
	for r in player.relics:
		sum += r.bonus_victory_points(player)
	return sum


static func extra_seven_steals(player: Player) -> int:
	var sum := 0
	for r in player.relics:
		sum += r.extra_steal_on_seven(player)
	return sum

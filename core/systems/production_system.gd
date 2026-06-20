class_name ProductionSystem
extends RefCounted
## Rohstoff-Gewinnung in Catan: bei einem Würfelwurf bekommt jeder Spieler für
## seine Siedlungen/Städte an passenden Tiles Ressourcen. Reine Logik über GameState.

var hex := HexGrid.new()


## Verteilt Ressourcen nach einem Würfelwurf: jedes Tile mit passendem Token
## (und ohne Räuber) gibt jeder angrenzenden Siedlung (1) bzw. Stadt (2) Ertrag.
func collect_resources(value: int) -> void:
	for coord in GameState.tiles:
		var tile: Tile = GameState.tiles[coord]
		if tile.number_token != value:
			continue
		if coord == GameState.robber_tile:
			continue   # Räuber blockiert die Produktion dieses Tiles
		var res: StringName = Terrain.TERRAIN_RESOURCES.get(tile.terrain, &"")
		if res == &"":
			continue
		for vertex in hex.get_vertices(coord):
			var s: Settlement = GameState.settlements.get(vertex)
			if s == null:
				continue
			var amount := 2 if s.level == 2 else 1
			var player: Player = GameState.players[s.owner_id]
			var ctx := {
				"player": player,
				"res": res,
				"base_amount": amount,
				"terrain": tile.terrain,
				"settlement_level": s.level,
				"dice_value": value,
				"owner_id": s.owner_id,
			}
			GameState.add_resource_to(player, res, _apply_relic_multipliers(player, res, amount, ctx))


## Vergibt die Startressourcen für die zweite Setup-Siedlung: je angrenzendem
## produzierenden Tile 1 Ressource.
func grant_initial_resources(vertex: Vector3i, player: Player) -> void:
	for coord in hex.vertex_adjacent_tiles(vertex):
		var tile: Tile = GameState.tiles.get(coord)
		if tile == null:
			continue
		var res: StringName = Terrain.TERRAIN_RESOURCES.get(tile.terrain, &"")
		if res != &"":
			GameState.add_resource_to(player, res, 1)


## Einziger Chokepoint für Roguelike-Multiplier/Power-Ups (Relics): addiert die
## Produktions-Boni der Relics des Spielers (nie unter 0).
func _apply_relic_multipliers(player: Player, _res: StringName, amount: int, ctx: Dictionary) -> int:
	return maxi(0, amount + RelicSystem.production_bonus(player, ctx))

class_name ProcGen
extends RefCounted
## Erzeugt das klassische 19-Hex-Catan-Brett (Reihen 3-4-5-4-3) mit
## authentischer Ressourcen- und Zahlen-Token-Verteilung. Seed-basiert über RNG.

var hex := HexGrid.new()

# 18 produzierende Tiles + 1 Wüste (klassische Catan-Verteilung).
const RESOURCE_BAG: Array = [
	Terrain.TerrainType.FOREST, Terrain.TerrainType.FOREST, Terrain.TerrainType.FOREST, Terrain.TerrainType.FOREST,
	Terrain.TerrainType.FIELDS, Terrain.TerrainType.FIELDS, Terrain.TerrainType.FIELDS, Terrain.TerrainType.FIELDS,
	Terrain.TerrainType.PASTURE, Terrain.TerrainType.PASTURE, Terrain.TerrainType.PASTURE, Terrain.TerrainType.PASTURE,
	Terrain.TerrainType.HILLS, Terrain.TerrainType.HILLS, Terrain.TerrainType.HILLS,
	Terrain.TerrainType.MOUNTAINS, Terrain.TerrainType.MOUNTAINS, Terrain.TerrainType.MOUNTAINS,
	Terrain.TerrainType.DESERT,
]

# 18 Zahlen-Token (kein 7). Werden den produzierenden Tiles der Reihe nach zugewiesen.
const TOKEN_BAG: Array = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]


## Generiert das komplette 19-Hex-Brett in den GameState.
func generate_board() -> void:
	RNG.seed_run(GameState.seed)
	GameState.tiles.clear()

	var coords := hex.get_range(Vector2i.ZERO, 2)   # exakt 19 Tiles (3-4-5-4-3)
	var terrains := RESOURCE_BAG.duplicate()
	RNG.shuffle(terrains)
	var tokens := TOKEN_BAG.duplicate()
	RNG.shuffle(tokens)

	var token_i := 0
	for i in coords.size():
		var tile := Tile.new()
		tile.coord = coords[i]
		tile.terrain = terrains[i]
		if tile.terrain == Terrain.TerrainType.DESERT:
			tile.number_token = 0
			GameState.robber_tile = tile.coord   # Räuber startet auf der Wüste
		else:
			tile.number_token = tokens[token_i]
			token_i += 1
		GameState.tiles[tile.coord] = tile

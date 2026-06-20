class_name ProcGen
extends RefCounted
## Erzeugt ein Catan-Brett, dessen Größe sich nach der Spielerzahl richtet
## (≤2 → Radius 2 / 19 Hex, 3–4 → Radius 3 / 37 Hex, ≥5 → Radius 4 / 61 Hex).
## Ressourcen, Zahlen-Token und Wüsten werden proportional zur Tilezahl verteilt.
## Seed-basiert über RNG → jeder Peer erzeugt dasselbe Brett.

var hex := HexGrid.new()

# Die fünf produzierenden Terrain-Typen (gleichmäßig über das Brett verteilt).
const PRODUCING_TERRAINS: Array = [
	Terrain.TerrainType.FOREST,
	Terrain.TerrainType.FIELDS,
	Terrain.TerrainType.PASTURE,
	Terrain.TerrainType.HILLS,
	Terrain.TerrainType.MOUNTAINS,
]

# Klassische 18er-Token-Verteilung (kein 7). Wird bei größeren Brettern zyklisch
# wiederholt, damit die Häufigkeit von 6/8 usw. proportional erhalten bleibt.
const TOKEN_BAG: Array = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]

# Ungefähr 1 Wüste je so vielen Tiles (klassisch: 1 Wüste auf 19 Tiles).
const TILES_PER_DESERT := 19


## Brett-Radius abhängig von der Spielerzahl.
func radius_for_players(count: int) -> int:
	if count <= 2:
		return 2
	if count <= 4:
		return 3
	return 4


## Generiert das Brett in den GameState (Größe nach Spielerzahl).
func generate_board() -> void:
	RNG.seed_run(GameState.seed)
	GameState.tiles.clear()

	var radius := radius_for_players(GameState.players.size())
	var coords := hex.get_range(Vector2i.ZERO, radius)
	var terrains := _build_terrain_bag(coords.size())
	RNG.shuffle(terrains)
	var tokens := _build_token_bag(_count_producing(terrains))
	RNG.shuffle(tokens)

	var token_i := 0
	var robber_set := false
	for i in coords.size():
		var tile := Tile.new()
		tile.coord = coords[i]
		tile.terrain = terrains[i]
		if tile.terrain == Terrain.TerrainType.DESERT:
			tile.number_token = 0
			if not robber_set:
				GameState.robber_tile = tile.coord   # Räuber startet auf der ersten Wüste
				robber_set = true
		else:
			tile.number_token = tokens[token_i]
			token_i += 1
		GameState.tiles[tile.coord] = tile


## Baut die Terrain-Tüte für n Tiles: proportional viele Wüsten, Rest gleichmäßig
## über die fünf produzierenden Typen verteilt.
func _build_terrain_bag(n: int) -> Array:
	var deserts := maxi(1, int(round(float(n) / float(TILES_PER_DESERT))))
	var producing := n - deserts
	var bag: Array = []
	for i in producing:
		bag.append(PRODUCING_TERRAINS[i % PRODUCING_TERRAINS.size()])
	for _i in deserts:
		bag.append(Terrain.TerrainType.DESERT)
	return bag


## Genau ein Token je produzierendem Tile (Token-Verteilung zyklisch wiederholt).
func _build_token_bag(producing: int) -> Array:
	var bag: Array = []
	for i in producing:
		bag.append(TOKEN_BAG[i % TOKEN_BAG.size()])
	return bag


func _count_producing(terrains: Array) -> int:
	var n := 0
	for t in terrains:
		if t != Terrain.TerrainType.DESERT:
			n += 1
	return n

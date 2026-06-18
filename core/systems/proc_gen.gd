class_name ProcGen
extends RefCounted
var hex := HexGrid.new()
var baserad := 4
var radius := baserad

## Seed-basierte prozedurale Generierung einer Stage/Region.
## Nutzt den zentralen RNG für reproduzierbare Welten.


## Generiert eine komplette Stage (Terrain, Token, Start, Modifikatoren).
func generate_stage(stage: int) -> void:
	#todo rng, radius, gamestate clear
	RNG.seed_run(GameState.seed + stage)
	generate_terrain()
	assign_number_tokens()
	radius = baserad + stage


## Verteilt Terrain-Typen über das Brett.
func generate_terrain() -> void:
	for coord in hex.get_range(Vector2i.ZERO, radius):
		var roll := RNG.randi_range(1, 100)
		var tile := Tile.new()
		tile.coord = coord
		tile.terrain = roll % Terrain.TerrainType.size()
		GameState.tiles[coord] = tile


## Weist den Tiles Zahlen-Token (2..12) zu.
func assign_number_tokens() -> void:
	for coord in GameState.tiles:
		var tile : Tile = GameState.tiles[coord]
		if tile.terrain == Terrain.TerrainType.DESERT or tile.terrain == Terrain.TerrainType.WATER:
			tile.number_token=0
			continue
		var roll := RNG.randi_range(2, 12)
		tile.number_token = roll


## Wählt die Startposition des Spielers.
func choose_start_position() -> Vector2i:
	# TODO
	return Vector2i.ZERO

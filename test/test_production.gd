extends GutTest
## Prüft die Würfel-Produktion: Besitzer bekommt 1 (Siedlung) bzw. 2 (Stadt);
## der Räuber blockiert das Tile.

var production: ProductionSystem
var hex := HexGrid.new()


func before_each() -> void:
	production = ProductionSystem.new()
	GameState.new_run(1, [{"name": "A"}, {"name": "B"}])
	var tile := Tile.new()
	tile.coord = Vector2i.ZERO
	tile.terrain = Terrain.TerrainType.FOREST   # -> wood
	tile.number_token = 8
	GameState.tiles[Vector2i.ZERO] = tile
	GameState.robber_tile = Vector2i(99, 99)


func _place(level: int) -> void:
	var v := hex.get_vertices(Vector2i.ZERO)[0]
	var s := Settlement.new()
	s.vertex = v
	s.owner_id = 0
	s.level = level
	GameState.settlements[v] = s
	GameState.players[0].settlements.append(v)


func test_settlement_yields_one() -> void:
	_place(1)
	production.collect_resources(8)
	assert_eq(GameState.players[0].get_resource(&"wood"), 1)


func test_city_yields_two() -> void:
	_place(2)
	production.collect_resources(8)
	assert_eq(GameState.players[0].get_resource(&"wood"), 2)


func test_robber_blocks_tile() -> void:
	_place(1)
	GameState.robber_tile = Vector2i.ZERO
	production.collect_resources(8)
	assert_eq(GameState.players[0].get_resource(&"wood"), 0)


func test_wrong_number_no_yield() -> void:
	_place(1)
	production.collect_resources(5)
	assert_eq(GameState.players[0].get_resource(&"wood"), 0)

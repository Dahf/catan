extends GutTest
## Prüft die Relic-Effekte über alle vier Kategorien: Produktion, Regelbruch,
## Synergie-VP und aggressive Extra-Diebstähle.

var production: ProductionSystem
var scoring: ScoringSystem
var hex := HexGrid.new()


func before_each() -> void:
	Net.disconnect_session()
	production = ProductionSystem.new()
	scoring = ScoringSystem.new()
	GameState.new_run(1, [{"name": "A"}, {"name": "B"}])
	var tile := Tile.new()
	tile.coord = Vector2i.ZERO
	tile.terrain = Terrain.TerrainType.FOREST   # -> wood
	tile.number_token = 8
	GameState.tiles[Vector2i.ZERO] = tile
	GameState.robber_tile = Vector2i(99, 99)


func _place(level: int) -> Vector3i:
	var v := hex.get_vertices(Vector2i.ZERO)[0]
	var s := Settlement.new()
	s.vertex = v
	s.owner_id = 0
	s.level = level
	GameState.settlements[v] = s
	GameState.players[0].settlements.append(v)
	return v


func test_production_relic_adds_bonus() -> void:
	var r := RelicProduction.new()
	r.target_terrain = Terrain.TerrainType.FOREST
	r.per_terrain = 1
	GameState.players[0].relics.append(r)
	_place(1)
	production.collect_resources(8)
	assert_eq(GameState.players[0].get_resource(&"wood"), 2)   # 1 Basis + 1 Relic


func test_production_relic_respects_terrain() -> void:
	var r := RelicProduction.new()
	r.target_terrain = Terrain.TerrainType.FIELDS   # passt nicht zum Wald-Tile
	r.per_terrain = 5
	GameState.players[0].relics.append(r)
	_place(1)
	production.collect_resources(8)
	assert_eq(GameState.players[0].get_resource(&"wood"), 1)   # kein Bonus


func test_rulebreak_ignores_distance() -> void:
	GameState.turn_phase = GameState.TurnPhase.SETUP
	var v := _place(1)
	var adj := hex.adjacent_vertices(v)[0]
	var p := GameState.players[0]
	assert_false(GameState.can_place_settlement(adj, p), "ohne Relic: Abstandsregel verbietet")
	var r := RelicRulebreak.new()
	r.ignore_distance = true
	p.relics.append(r)
	assert_true(GameState.can_place_settlement(adj, p), "mit Relic: Abstandsregel ignoriert")


func test_rulebreak_disconnected_roads() -> void:
	GameState.turn_phase = GameState.TurnPhase.BUILD
	var v := hex.get_vertices(Vector2i.ZERO)[0]
	var edge: Array = hex.incident_edges(v)[0]
	var p := GameState.players[0]
	assert_false(GameState.can_place_road(edge, p), "ohne Relic: keine Anbindung")
	var r := RelicRulebreak.new()
	r.disconnected_roads = true
	p.relics.append(r)
	assert_true(GameState.can_place_road(edge, p), "mit Relic: Anbindung egal")


func test_synergy_adds_vp() -> void:
	var prod := RelicProduction.new()
	prod.category = Relic.Category.PRODUCTION
	var syn := RelicSynergy.new()
	syn.category = Relic.Category.SYNERGY
	syn.vp_per_category = Relic.Category.PRODUCTION   # +1 VP je Produktions-Relic
	GameState.players[0].relics.append(prod)
	GameState.players[0].relics.append(syn)
	scoring.recompute(GameState.players[0])
	assert_eq(GameState.players[0].victory_points, 1)   # 0 Gebäude + 1 Produktions-Relic


func test_aggressive_extra_steals() -> void:
	var r := RelicAggressive.new()
	r.extra_steals = 2
	GameState.players[0].relics.append(r)
	assert_eq(RelicSystem.extra_seven_steals(GameState.players[0]), 2)


func test_robber_immune_aggregator() -> void:
	assert_false(RelicSystem.robber_immune(GameState.players[0]))
	var r := RelicRulebreak.new()
	r.robber_immune = true
	GameState.players[0].relics.append(r)
	assert_true(RelicSystem.robber_immune(GameState.players[0]))

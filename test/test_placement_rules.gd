extends GutTest
## Prüft die Catan-Platzierungsregeln: Abstandsregel, Setup-Straßen-Anker und
## Straßen-Verbindung im normalen Spiel.

var hex := HexGrid.new()


func before_each() -> void:
	GameState.new_run(1, [{"name": "A"}])
	for c in hex.get_range(Vector2i.ZERO, 1):
		var tile := Tile.new()
		tile.coord = c
		tile.terrain = Terrain.TerrainType.FOREST
		tile.number_token = 8
		GameState.tiles[c] = tile


func test_distance_rule() -> void:
	GameState.turn_phase = GameState.TurnPhase.SETUP
	var p := GameState.players[0]
	var verts := hex.get_vertices(Vector2i.ZERO)
	assert_true(GameState.can_place_settlement(verts[0], p), "freier Vertex erlaubt")
	assert_true(GameState.place_settlement(verts[0], p), "Setup-Platzierung gelingt")
	assert_false(GameState.can_place_settlement(verts[0], p), "belegter Vertex verboten")
	assert_false(GameState.can_place_settlement(verts[1], p), "Nachbar-Vertex verboten (Abstand)")
	assert_true(GameState.can_place_settlement(verts[2], p), "nicht benachbarter Vertex erlaubt")


func test_setup_road_requires_anchor() -> void:
	GameState.turn_phase = GameState.TurnPhase.SETUP
	var p := GameState.players[0]
	var verts := hex.get_vertices(Vector2i.ZERO)
	GameState.setup_road_anchor = verts[0]
	GameState.has_setup_anchor = true
	var incident: Array = hex.incident_edges(verts[0])
	assert_true(GameState.can_place_road(incident[0], p), "Straße am Anker erlaubt")
	var detached := hex.make_edge(verts[2], verts[3])
	assert_false(GameState.can_place_road(detached, p), "Straße ohne Ankerbezug verboten")


func test_normal_road_needs_connection() -> void:
	GameState.turn_phase = GameState.TurnPhase.SETUP
	var p := GameState.players[0]
	var verts := hex.get_vertices(Vector2i.ZERO)
	GameState.place_settlement(verts[0], p)   # eigene Siedlung als Anbindung
	GameState.turn_phase = GameState.TurnPhase.BUILD
	var incident: Array = hex.incident_edges(verts[0])
	assert_true(GameState.can_place_road(incident[0], p), "Straße an eigener Siedlung erlaubt")
	var detached := hex.make_edge(verts[2], verts[3])
	assert_false(GameState.can_place_road(detached, p), "unverbundene Straße verboten")


func test_city_upgrade_requires_own_settlement() -> void:
	GameState.turn_phase = GameState.TurnPhase.SETUP
	var p := GameState.players[0]
	var verts := hex.get_vertices(Vector2i.ZERO)
	assert_false(GameState.can_upgrade_city(verts[0], p), "ohne Siedlung kein Upgrade")
	GameState.place_settlement(verts[0], p)
	assert_true(GameState.can_upgrade_city(verts[0], p), "eigene Siedlung upgradebar")

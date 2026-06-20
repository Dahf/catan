extends GutTest
## Prüft die Fakt-Apply-Schicht (Net.send_*/fact_*) im Offline-Modus: dieselbe
## Mutation, die online per RPC auf alle Peers ginge, wird hier lokal angewandt.
## Damit ist garantiert, dass der Apply-Code unabhängig vom Transport korrekt ist.

func before_each() -> void:
	Net.disconnect_session()   # offline erzwingen (kein Peer)
	GameState.new_run(1, [{"name": "A"}, {"name": "B"}])


func test_send_resource_applies_delta() -> void:
	Net.send_resource(0, &"wood", 3)
	assert_eq(GameState.players[0].get_resource(&"wood"), 3)
	Net.send_resource(0, &"wood", -1)
	assert_eq(GameState.players[0].get_resource(&"wood"), 2)


func test_fact_settlement_applies() -> void:
	var v := Vector3i(1, 2, -3)
	Net.send_settlement(v, 1, 1)
	assert_true(GameState.settlements.has(v))
	assert_eq(GameState.settlements[v].owner_id, 1)
	assert_eq(GameState.settlements[v].level, 1)
	assert_true(GameState.players[1].settlements.has(v))


func test_fact_city_moves_settlement_to_cities() -> void:
	var v := Vector3i(2, 0, -2)
	Net.send_settlement(v, 0, 1)
	Net.send_city(v)
	assert_eq(GameState.settlements[v].level, 2)
	assert_true(GameState.players[0].cities.has(v))
	assert_false(GameState.players[0].settlements.has(v))


func test_fact_road_keys_and_owner() -> void:
	var edge := [Vector3i(0, 0, 0), Vector3i(1, 0, -1)]
	Net.send_road(edge, 1)
	var hex := HexGrid.new()
	var key := hex.edge_key(hex.make_edge(edge[0], edge[1]))
	assert_eq(GameState.roads.get(key), 1)
	assert_eq(GameState.players[1].roads.size(), 1)


func test_turnstate_fact_sets_scalars() -> void:
	GameState.turn_phase = GameState.TurnPhase.BUILD
	GameState.current_player_index = 1
	GameState.robber_tile = Vector2i(3, -1)
	Net.send_turnstate()
	# Offline wird der Fakt lokal angewandt; die Skalare bleiben gesetzt.
	assert_eq(GameState.turn_phase, GameState.TurnPhase.BUILD)
	assert_eq(GameState.current_player_index, 1)
	assert_eq(GameState.robber_tile, Vector2i(3, -1))

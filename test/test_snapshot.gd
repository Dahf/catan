extends GutTest
## Prüft GameState.to_snapshot()/apply_snapshot() — die Grundlage für Reconnect/
## Late-Join (Host serialisiert den vollen Zustand, Peer stellt ihn wieder her).

func before_each() -> void:
	Net.disconnect_session()
	GameState.new_run(99, [{"name": "A"}, {"name": "B"}])
	GameState.seed = 99
	var proc := ProcGen.new()
	proc.generate_board()


func test_roundtrip_restores_full_state() -> void:
	var v := Vector3i(1, 2, -3)
	Net.send_settlement(v, 0, 1)
	Net.send_road([Vector3i(0, 0, 0), Vector3i(1, 0, -1)], 1)
	Net.send_resource(0, &"wood", 4)
	GameState.current_player_index = 1
	GameState.turn_phase = GameState.TurnPhase.BUILD
	var robber_before := GameState.robber_tile

	var snap := GameState.to_snapshot()
	GameState.apply_snapshot(snap)

	assert_eq(GameState.tiles.size(), 19, "Alle Tiles wiederhergestellt")
	assert_true(GameState.settlements.has(v), "Siedlung wiederhergestellt")
	assert_eq(GameState.settlements[v].owner_id, 0)
	assert_eq(GameState.players[0].get_resource(&"wood"), 4)
	assert_eq(GameState.players[0].settlements.size(), 1)
	assert_eq(GameState.players[1].roads.size(), 1)
	assert_eq(GameState.roads.size(), 1)
	assert_eq(GameState.current_player_index, 1)
	assert_eq(GameState.turn_phase, GameState.TurnPhase.BUILD)
	assert_eq(GameState.robber_tile, robber_before)


func test_city_level_survives_roundtrip() -> void:
	var v := Vector3i(2, 0, -2)
	Net.send_settlement(v, 0, 1)
	Net.send_city(v)
	var snap := GameState.to_snapshot()
	GameState.apply_snapshot(snap)
	assert_eq(GameState.settlements[v].level, 2)
	assert_true(GameState.players[0].cities.has(v))

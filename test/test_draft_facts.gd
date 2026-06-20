extends GutTest
## Prüft die Draft-Fakt-Schicht (Net.send_*/fact_*) offline: Relic-Zuweisung,
## Draft-Reihenfolge-Signal, Intent-Routing und Snapshot-Rehydrierung.

func before_each() -> void:
	Net.disconnect_session()
	GameState.new_run(1, [{"name": "A"}, {"name": "B"}])


func test_content_db_has_relics() -> void:
	assert_gt(ContentDB.relics.size(), 0, "ContentDB hat .tres-Relics geladen")


func test_relic_assigned_lands_on_player() -> void:
	watch_signals(EventBus)
	var rid: StringName = ContentDB.relics.keys()[0]
	Net.send_relic_assigned(0, rid)
	assert_eq(GameState.players[0].relics.size(), 1)
	assert_eq(GameState.relics.size(), 1)
	assert_signal_emitted(EventBus, "relic_acquired")


func test_draft_turn_sets_current() -> void:
	Net.send_draft_turn(1)
	assert_eq(GameState.draft_current, 1)
	Net.send_draft_turn(-1)
	assert_eq(GameState.draft_current, -1)


func test_pick_request_routes_to_eventbus() -> void:
	watch_signals(EventBus)
	Net.request_draft_pick(&"holzfaeller_axt")   # offline → direkt
	assert_signal_emitted(EventBus, "draft_pick_requested")


func test_snapshot_rehydrates_relics() -> void:
	var rid: StringName = ContentDB.relics.keys()[0]
	GameState.players[0].relics.append(ContentDB.get_relic(rid))
	GameState.relics.append(ContentDB.get_relic(rid))
	GameState.stage = 3
	var snap := GameState.to_snapshot()
	GameState.apply_snapshot(snap)
	assert_eq(GameState.players[0].relics.size(), 1)
	assert_eq(GameState.relics.size(), 1)
	assert_eq(GameState.stage, 3)

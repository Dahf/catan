extends GutTest
## End-to-End: erzwingt einen kompletten Stage-Draft auf der Main-Szene (offline)
## und prüft, dass jeder Spieler draftet und die Partie danach in ROLL zurückkehrt.

var main: Node


func before_each() -> void:
	Net.disconnect_session()
	GameState.reset()   # Main bootet dann einen Standard-Offline-Run (4 Spieler + Board)
	main = load("res://main/main.tscn").instantiate()
	add_child_autofree(main)
	await get_tree().process_frame


func test_full_stage_draft_assigns_relics_and_returns_to_roll() -> void:
	main._begin_stage_draft()
	assert_eq(GameState.turn_phase, GameState.TurnPhase.DRAFT, "Draft gestartet")

	# Der jeweils aktive Drafter nimmt immer das erste verbliebene Ring-Relic.
	var guard := 0
	while GameState.turn_phase == GameState.TurnPhase.DRAFT and guard < 50:
		guard += 1
		var ring: Array = main._draft_ring
		if ring.is_empty():
			break
		EventBus.draft_pick_requested.emit(ring[0])

	assert_eq(GameState.turn_phase, GameState.TurnPhase.ROLL, "Draft endet wieder in ROLL")
	assert_eq(GameState.draft_current, -1, "kein aktiver Drafter mehr")
	# Pro Stage zieht jeder Spieler genau EIN Relic.
	for p in GameState.players:
		assert_eq(p.relics.size(), 1, "Spieler %d hat 1 Relic" % p.id)

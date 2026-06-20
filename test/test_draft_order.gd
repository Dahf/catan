extends GutTest
## Prüft die Draft-Reihenfolge: jeder Spieler einmal, Rückstand (weniger VP) zuerst,
## deterministische Tie-Breaks (kleinere id).

func before_each() -> void:
	Net.disconnect_session()
	GameState.new_run(1, [{"name": "A"}, {"name": "B"}, {"name": "C"}, {"name": "D"}])
	GameState.players[0].victory_points = 5
	GameState.players[1].victory_points = 2
	GameState.players[2].victory_points = 8
	GameState.players[3].victory_points = 2   # Gleichstand mit 1 -> kleinere id zuerst


func test_order_trailing_first_one_pick_each() -> void:
	var order := DraftOrder.build(GameState.players)
	# Rang aufsteigend (Tie: id): 1, 3, 0, 2 — jeder genau einmal.
	assert_eq(order, [1, 3, 0, 2])

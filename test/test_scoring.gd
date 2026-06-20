extends GutTest
## Prüft die Siegpunkt-Berechnung: Siedlung = 1, Stadt = 2, Sieg bei 10.

var scoring: ScoringSystem


func before_each() -> void:
	scoring = ScoringSystem.new()
	GameState.new_run(1, [{"name": "A"}])


func test_settlements_and_cities() -> void:
	var p := GameState.players[0]
	p.settlements = [Vector3i(1, 0, 0), Vector3i(2, 0, 0)]
	p.cities = [Vector3i(3, 0, 0)]
	assert_eq(scoring.recompute(p), 4)   # 2*1 + 1*2


func test_not_won_below_ten() -> void:
	var p := GameState.players[0]
	p.cities = [Vector3i(1, 0, 0), Vector3i(2, 0, 0)]
	scoring.recompute(p)
	assert_false(scoring.has_won(p))


func test_won_at_ten() -> void:
	var p := GameState.players[0]
	p.cities = [Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(3, 0, 0), Vector3i(4, 0, 0), Vector3i(5, 0, 0)]
	scoring.recompute(p)
	assert_true(scoring.has_won(p))   # 5*2 = 10

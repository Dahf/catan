extends GutTest
## Sichert die Grundlage des MP-Brettsyncs ab: gleicher Seed → identisches Brett
## (jeder Peer generiert lokal, ohne Tile-Übertragung). Verschiedener Seed → i.d.R.
## anderes Brett.

func _generate(seed_value: int) -> Dictionary:
	GameState.new_run(seed_value, [{"name": "A"}, {"name": "B"}])
	GameState.seed = seed_value
	var proc := ProcGen.new()
	proc.generate_board()
	var snapshot := {}
	for coord in GameState.tiles:
		var t: Tile = GameState.tiles[coord]
		snapshot[coord] = [t.terrain, t.number_token]
	return {"tiles": snapshot, "robber": GameState.robber_tile}


func test_same_seed_same_board() -> void:
	var a := _generate(12345)
	var b := _generate(12345)
	assert_eq(a["tiles"], b["tiles"], "Tiles müssen bei gleichem Seed identisch sein")
	assert_eq(a["robber"], b["robber"], "Räuber-Startfeld muss identisch sein")


func test_board_has_19_tiles() -> void:
	var a := _generate(7)
	assert_eq((a["tiles"] as Dictionary).size(), 19)


func test_different_seed_differs() -> void:
	var a := _generate(1)
	var b := _generate(2)
	assert_ne(a["tiles"], b["tiles"], "Unterschiedlicher Seed sollte ein anderes Brett ergeben")

extends GutTest
## Prüft die reinen Roster-Helfer von Net (Slot-Zuweisung, Mapping, Spieler-Configs).
## Die Transport-/RPC-Pfade werden manuell (zwei Instanzen) verifiziert; hier nur
## die deterministische, peer-unabhängige Logik.

func before_each() -> void:
	Net.roster.clear()
	Net.local_slot = -1
	Net._held_slots.clear()


func after_each() -> void:
	Net.roster.clear()
	Net.local_slot = -1
	Net._held_slots.clear()


func _seed_roster() -> void:
	Net.roster = [
		Net._make_slot(0, 1, 0, "Host"),
		Net._make_slot(1, 7, 0, "Gast"),
	]


func test_make_slot_shape() -> void:
	var s := Net._make_slot(2, 9, 1234, "Foo")
	assert_eq(s["slot"], 2)
	assert_eq(s["peer_id"], 9)
	assert_eq(s["steam_id"], 1234)
	assert_eq(s["name"], "Foo")
	assert_true(s["connected"])
	assert_eq(s["color"], GameState.PLAYER_COLORS[2])


func test_next_free_slot_picks_lowest() -> void:
	_seed_roster()
	assert_eq(Net._next_free_slot(), 2)


func test_next_free_slot_full_returns_minus_one() -> void:
	Net.roster = [
		Net._make_slot(0, 1, 0, "A"),
		Net._make_slot(1, 2, 0, "B"),
		Net._make_slot(2, 3, 0, "C"),
		Net._make_slot(3, 4, 0, "D"),
	]
	assert_eq(Net._next_free_slot(), -1)


func test_slot_and_peer_mapping() -> void:
	_seed_roster()
	assert_eq(Net.slot_of_peer(7), 1)
	assert_eq(Net.slot_of_peer(999), -1)
	assert_eq(Net.peer_of_slot(0), 1)
	assert_eq(Net.peer_of_slot(5), -1)


func test_player_configs_match_roster_order() -> void:
	_seed_roster()
	var configs := Net.player_configs()
	assert_eq(configs.size(), 2)
	assert_eq(configs[0]["name"], "Host")
	assert_eq(configs[1]["name"], "Gast")
	assert_eq(configs[0]["color"], GameState.PLAYER_COLORS[0])

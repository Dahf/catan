extends Node
## Aktueller Run-Zustand (Daten-Kern). Autoload-Name: GameState.
## Hält alle Spieldaten; die Systeme operieren auf diesem Zustand.
## Catan-Modell: jeder Spieler hat eigene Ressourcen, Siedlungen/Städte und Straßen.
var _hex := HexGrid.new()
var _rules := PlacementRules.new()

var seed: int = 0
var tiles: Dictionary = {}            # Vector2i -> Tile
var settlements: Dictionary = {}      # Vector3i(vertex) -> Settlement (autoritative Belegung)
var roads: Dictionary = {}            # edge_key(String) -> owner_id(int)
var robber_tile: Vector2i = Vector2i.ZERO

var players: Array[Player] = []
var current_player_index: int = 0

# Während der Setup-Phase: Vertex der zuletzt gesetzten Siedlung, an die die
# nächste Setup-Straße anschließen muss.
var setup_road_anchor: Vector3i = Vector3i.ZERO
var has_setup_anchor: bool = false
var setup_expect_road: bool = false   # true: aktueller Setup-Spieler muss Straße setzen

# Roguelike: Run-/Draft-Zustand.
var stage: int = 1
var turn: int = 0
var relics: Array[Relic] = []          # global erworbene Relics (Log für Snapshot/Save)
var draft_current: int = -1            # Spieler-Slot, der gerade im Draft am Zug ist (-1 = keiner)

enum TurnPhase { SETUP, ROLL, ROBBER_DISCARD, ROBBER_MOVE, BUILD, DRAFT, GAME_OVER }
var turn_phase: TurnPhase = TurnPhase.SETUP

const RESOURCE_IDS: Array[StringName] = [&"wood", &"brick", &"ore", &"grain", &"wool"]

const COST_ROAD := {&"wood": 1, &"brick": 1}
const COST_SETTLEMENT := {&"wood": 1, &"brick": 1, &"grain": 1, &"wool": 1}
const COST_CITY := {&"grain": 2, &"ore": 3}

const PLAYER_COLORS: Array[Color] = [
	Color("d23b3b"),   # Rot
	Color("3b6fd2"),   # Blau
	Color("e0a020"),   # Orange/Gelb
	Color("e8e8e8"),   # Weiß
]


## Liefert den Spieler, der gerade am Zug ist.
func current_player() -> Player:
	return players[current_player_index]


## Startet einen neuen Run mit gegebenem Seed und Spieler-Konfigurationen.
## player_configs: Array von Dictionaries {name: String, color: Color (optional)}.
func new_run(new_seed: int, player_configs: Array) -> void:
	reset()
	seed = new_seed
	for i in player_configs.size():
		var cfg: Dictionary = player_configs[i]
		var p := Player.new()
		p.id = i
		p.display_name = cfg.get("name", "Spieler %d" % (i + 1))
		p.color = cfg.get("color", PLAYER_COLORS[i % PLAYER_COLORS.size()])
		players.append(p)


## Setzt den gesamten Run-Zustand zurück.
func reset() -> void:
	tiles.clear()
	settlements.clear()
	roads.clear()
	players.clear()
	robber_tile = Vector2i.ZERO
	current_player_index = 0
	setup_road_anchor = Vector3i.ZERO
	has_setup_anchor = false
	setup_expect_road = false
	stage = 1
	turn = 0
	relics.clear()
	draft_current = -1
	turn_phase = TurnPhase.SETUP


## True, solange ein modales Overlay (Räuber-Abwurf) die Brett-Eingaben sperrt.
func is_input_blocked() -> bool:
	return turn_phase == TurnPhase.ROBBER_DISCARD or turn_phase == TurnPhase.GAME_OVER


## Liefert das Tile an einer Koordinate (oder null).
func get_tile(coord: Vector2i) -> Tile:
	return tiles.get(coord)


# --- Ressourcen ----------------------------------------------------------------

## Prüft, ob der Spieler die Kosten aus seinem Bestand bezahlen kann.
func can_afford(player: Player, cost: Dictionary) -> bool:
	for item in cost:
		if player.get_resource(item) < cost[item]:
			return false
	return true


## Zieht die Kosten vom Spielerbestand ab (als Fakten, host-autoritativ).
func spend(player: Player, cost: Dictionary) -> void:
	for item in cost:
		Net.send_resource(player.id, item, -int(cost[item]))


## Fügt einem Spieler eine Ressourcenmenge hinzu (als Fakt, host-autoritativ).
func add_resource_to(player: Player, id: StringName, amount: int) -> void:
	Net.send_resource(player.id, id, amount)


# --- Platzierungs-Prüfungen (Delegation an PlacementRules) ----------------------

func can_place_settlement(vertex: Vector3i, player: Player) -> bool:
	return _rules.can_place_settlement(vertex, player)


func can_place_road(edge, player: Player) -> bool:
	return _rules.can_place_road(edge, player)


func can_upgrade_city(vertex: Vector3i, player: Player) -> bool:
	return _rules.can_upgrade_city(vertex, player)


# --- Platzierung ---------------------------------------------------------------

## Platziert eine Siedlung auf einem Vertex. Außerhalb der Setup-Phase werden
## Kosten abgezogen. Gibt false zurück, wenn die Platzierung ungültig/zu teuer ist.
func place_settlement(vertex: Vector3i, player: Player) -> bool:
	if not _rules.can_place_settlement(vertex, player):
		return false
	var is_setup := turn_phase == TurnPhase.SETUP
	if not is_setup:
		if not can_afford(player, COST_SETTLEMENT):
			return false
		spend(player, COST_SETTLEMENT)
	Net.send_settlement(vertex, player.id, 1)
	return true


## Platziert eine Straße auf einer Kante. Außerhalb der Setup-Phase Kosten.
func place_road(edge, player: Player) -> bool:
	if not _rules.can_place_road(edge, player):
		return false
	var is_setup := turn_phase == TurnPhase.SETUP
	if not is_setup:
		if not can_afford(player, COST_ROAD):
			return false
		spend(player, COST_ROAD)
	var canon := _hex.make_edge(edge[0], edge[1])
	Net.send_road(canon, player.id)
	return true


## Wertet eine eigene Siedlung zur Stadt auf (Kosten: 2 Getreide, 3 Erz).
func upgrade_city(vertex: Vector3i, player: Player) -> bool:
	if not _rules.can_upgrade_city(vertex, player):
		return false
	var s: Settlement = settlements.get(vertex)
	if s == null:
		return false
	if not can_afford(player, COST_CITY):
		return false
	spend(player, COST_CITY)
	Net.send_city(vertex)
	return true


## Schaltet zur nächsten Runde weiter (globaler Rundenzähler).
func advance_turn() -> void:
	turn += 1
	EventBus.turn_advanced.emit(turn)


# --- Snapshot (für Reconnect/Late-Join, Phase 4) -------------------------------

## Serialisiert den gesamten Spielzustand in ein RPC-fähiges Dictionary.
func to_snapshot() -> Dictionary:
	var ps: Array = []
	for p in players:
		ps.append({
			"id": p.id,
			"name": p.display_name,
			"color": p.color,
			"resources": p.resources.duplicate(),
			"settlements": p.settlements.duplicate(),
			"cities": p.cities.duplicate(),
			"roads": p.roads.duplicate(),
			"vp": p.victory_points,
			"relics": _relic_ids(p.relics),
		})
	var ts: Dictionary = {}
	for coord in tiles:
		var t: Tile = tiles[coord]
		ts[coord] = {"terrain": t.terrain, "token": t.number_token}
	var ss: Dictionary = {}
	for v in settlements:
		var s: Settlement = settlements[v]
		ss[v] = {"level": s.level, "owner": s.owner_id}
	return {
		"seed": seed,
		"tiles": ts,
		"settlements": ss,
		"roads": roads.duplicate(),
		"players": ps,
		"current": current_player_index,
		"robber": robber_tile,
		"phase": turn_phase,
		"turn": turn,
		"stage": stage,
		"relics": _relic_ids(relics),
		"draft_current": draft_current,
		"anchor": setup_road_anchor,
		"has_anchor": has_setup_anchor,
		"expect_road": setup_expect_road,
	}


## Relic-Liste → Array von String-IDs (für Snapshot; rehydriert via ContentDB).
func _relic_ids(arr: Array) -> Array:
	var ids: Array = []
	for r in arr:
		ids.append(String(r.id))
	return ids


## Array von String-IDs → typisierte Relic-Liste (unbekannte IDs werden übersprungen).
func _relics_from_ids(ids: Array) -> Array[Relic]:
	var out: Array[Relic] = []
	for id in ids:
		var r := ContentDB.get_relic(StringName(id))
		if r != null:
			out.append(r)
	return out


## Stellt den Spielzustand aus einem Snapshot wieder her (überschreibt alles).
func apply_snapshot(d: Dictionary) -> void:
	reset()
	seed = d["seed"]
	for coord in d["tiles"]:
		var td: Dictionary = d["tiles"][coord]
		var t := Tile.new()
		t.coord = coord
		t.terrain = td["terrain"]
		t.number_token = td["token"]
		tiles[coord] = t
	robber_tile = d["robber"]
	for pd in d["players"]:
		var p := Player.new()
		p.id = pd["id"]
		p.display_name = pd["name"]
		p.color = pd["color"]
		p.resources = (pd["resources"] as Dictionary).duplicate()
		p.settlements.assign(pd["settlements"])
		p.cities.assign(pd["cities"])
		p.roads = (pd["roads"] as Array).duplicate()
		p.victory_points = pd["vp"]
		p.relics = _relics_from_ids(pd.get("relics", []))
		players.append(p)
	for v in d["settlements"]:
		var sd: Dictionary = d["settlements"][v]
		var s := Settlement.new()
		s.vertex = v
		s.level = sd["level"]
		s.owner_id = sd["owner"]
		settlements[v] = s
	roads = (d["roads"] as Dictionary).duplicate()
	current_player_index = d["current"]
	turn_phase = d["phase"]
	turn = d["turn"]
	stage = d.get("stage", 1)
	relics = _relics_from_ids(d.get("relics", []))
	draft_current = d.get("draft_current", -1)
	setup_road_anchor = d["anchor"]
	has_setup_anchor = d["has_anchor"]
	setup_expect_road = d["expect_road"]

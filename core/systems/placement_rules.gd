class_name PlacementRules
extends RefCounted
## Reine Lese-Prüfungen der Catan-Platzierungsregeln (keine Buchung).
## Wird von GameState (bei der Platzierung) und von game_board (Ghost-Vorschau)
## genutzt, damit beide exakt dieselbe Logik sehen. Liest aus dem GameState-Autoload.

var hex := HexGrid.new()


## Siedlung: Vertex frei, berührt das Brett, hält Abstandsregel ein; außerhalb
## der Setup-Phase zusätzlich an eine eigene Straße angebunden.
func can_place_settlement(vertex: Vector3i, player: Player) -> bool:
	if not _vertex_on_board(vertex):
		return false
	if GameState.settlements.has(vertex):
		return false
	# Abstandsregel: kein direkter Nachbar-Vertex darf belegt sein.
	for adj in hex.adjacent_vertices(vertex):
		if GameState.settlements.has(adj):
			return false
	if GameState.turn_phase == GameState.TurnPhase.SETUP:
		return true
	# Normales Spiel: mindestens eine angrenzende Kante gehört dem Spieler.
	return _vertex_touches_own_road(vertex, player)


## Straße: Kante frei und korrekt angebunden. In der Setup-Phase muss sie an die
## gerade gesetzte Siedlung (setup_road_anchor) anschließen.
func can_place_road(edge, player: Player) -> bool:
	var key := hex.edge_key(edge)
	if GameState.roads.has(key):
		return false
	var endpoints := hex.edge_endpoints(edge)
	if not (_vertex_on_board(endpoints[0]) or _vertex_on_board(endpoints[1])):
		return false
	if GameState.turn_phase == GameState.TurnPhase.SETUP:
		if not GameState.has_setup_anchor:
			return false
		return endpoints[0] == GameState.setup_road_anchor or endpoints[1] == GameState.setup_road_anchor
	# Normales Spiel: ein Endpunkt berührt eigene Siedlung/Stadt oder eigene Straße.
	for v in endpoints:
		if _vertex_owned_by(v, player):
			return true
		if _vertex_touches_own_road(v, player):
			return true
	return false


## Stadt-Upgrade: Vertex trägt eine eigene Siedlung (Level 1).
func can_upgrade_city(vertex: Vector3i, player: Player) -> bool:
	var s: Settlement = GameState.settlements.get(vertex)
	return s != null and s.owner_id == player.id and s.level == 1


# --- Helfer --------------------------------------------------------------------

func _vertex_on_board(vertex: Vector3i) -> bool:
	for coord in hex.vertex_adjacent_tiles(vertex):
		if GameState.tiles.has(coord):
			return true
	return false


func _vertex_owned_by(vertex: Vector3i, player: Player) -> bool:
	var s: Settlement = GameState.settlements.get(vertex)
	return s != null and s.owner_id == player.id


func _vertex_touches_own_road(vertex: Vector3i, player: Player) -> bool:
	for e in hex.incident_edges(vertex):
		if GameState.roads.get(hex.edge_key(e), -1) == player.id:
			return true
	return false

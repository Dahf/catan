extends Node3D
## Einstiegspunkt des Spiels. Verdrahtet Board + UI und steuert den Catan-Spielzug:
## Setup-Platzierung (Schlangen-Reihenfolge) → pro Spieler: Würfeln → ggf. Räuber →
## Bauen → Zug beenden. Reine Orchestrierung; Spielregeln liegen in den Systemen.

const NUM_PLAYERS := 4

var proc := ProcGen.new()
var production := ProductionSystem.new()
var scoring := ScoringSystem.new()

# Setup-Phase (Anfangsplatzierung)
var _setup_order: Array[int] = []
var _setup_pos: int = 0

# Räuber-Abwurf: noch ausstehende Spieler-IDs
var _discard_queue: Array[int] = []

# Relic-Draft (host-/offline-autoritativ)
var _draft_order: Array[int] = []   # Pick-Reihenfolge (Spieler-Slots, Snake/Catchup)
var _draft_pos: int = 0             # Index in _draft_order
var _draft_ring: Array = []         # noch verfügbare Relic-IDs im Ring


func _ready() -> void:
	EventBus.settlement_placed.connect(_on_settlement_placed)
	EventBus.road_placed.connect(_on_road_placed)
	EventBus.city_upgraded.connect(_on_city_upgraded)
	EventBus.roll_requested.connect(roll_dice)
	EventBus.end_turn_requested.connect(end_turn)
	EventBus.robber_tile_chosen.connect(_on_robber_tile_chosen)
	EventBus.robber_victim_chosen.connect(_on_robber_victim_chosen)
	EventBus.discard_submitted.connect(_on_discard_submitted)
	EventBus.draft_pick_requested.connect(_on_draft_pick_requested)
	# VP-Neuberechnung läuft auf JEDEM Peer (deterministisch aus Siedlungen/Städten),
	# damit auch Clients korrekte Siegpunkte anzeigen.
	EventBus.settlement_placed.connect(_rescore_owner)
	EventBus.city_upgraded.connect(_rescore_owner)
	_boot()


## Berechnet die Siegpunkte des betroffenen Spielers neu (auf allen Peers).
func _rescore_owner(_vertex: Vector3i, owner_id: int) -> void:
	scoring.recompute(GameState.players[owner_id])


## True, wenn dieser Prozess die Spiel-Logik fahren darf: Offline ODER Netz-Host.
## Clients fahren die Zug-State-Machine nicht selbst — sie folgen den Fakten (Phase 2).
func _is_authority() -> bool:
	return (not Net.is_online()) or Net.is_host()


## Bootet das Spiel. Wurde der Zustand bereits von der Lobby vorbereitet (tiles
## gefüllt), wird er übernommen; sonst entsteht ein Standard-Offline-Run.
func _boot() -> void:
	if GameState.tiles.is_empty():
		GameState.new_run(GameState.seed, _default_player_configs())
		proc.generate_board()
	$GameBoard.build_from_state()
	if _is_authority():
		_begin_setup()
	else:
		# Client: Brett steht; lokale UI initialisieren und aktuellen Zug-Zustand
		# beim Host anfordern (Fakten folgen).
		EventBus.phase_changed.emit()
		Net.request_resync()


func _default_player_configs() -> Array:
	var configs: Array = []
	for i in NUM_PLAYERS:
		configs.append({"name": "Spieler %d" % (i + 1), "color": GameState.PLAYER_COLORS[i]})
	return configs


# --- Setup-Phase (Anfangsplatzierung) ------------------------------------------

func _begin_setup() -> void:
	var n := GameState.players.size()
	_setup_order.clear()
	for i in n:
		_setup_order.append(i)
	for i in range(n - 1, -1, -1):
		_setup_order.append(i)   # Schlange: z.B. 0,1,2,3,3,2,1,0
	_setup_pos = 0
	GameState.turn_phase = GameState.TurnPhase.SETUP
	GameState.current_player_index = _setup_order[0]
	GameState.has_setup_anchor = false
	GameState.setup_expect_road = false
	_emit_phase()


func _on_settlement_placed(vertex: Vector3i, _owner_id: int) -> void:
	if not _is_authority():
		return
	if GameState.turn_phase != GameState.TurnPhase.SETUP:
		_check_win(GameState.players[_owner_id])
		return
	# Setup: Siedlung gesetzt → als Anker für die folgende Straße merken.
	GameState.setup_road_anchor = vertex
	GameState.has_setup_anchor = true
	GameState.setup_expect_road = true
	# Zweite Siedlung (Schlangen-Rücklauf): Startressourcen vergeben.
	if _setup_pos >= GameState.players.size():
		production.grant_initial_resources(vertex, GameState.players[_owner_id])
	_emit_phase()


func _on_road_placed(_edge, _owner_id: int) -> void:
	if not _is_authority():
		return
	if GameState.turn_phase != GameState.TurnPhase.SETUP:
		return
	# Setup: Straße gesetzt → nächster Schlangen-Schritt.
	_setup_pos += 1
	GameState.has_setup_anchor = false
	GameState.setup_expect_road = false
	if _setup_pos < _setup_order.size():
		GameState.current_player_index = _setup_order[_setup_pos]
		_emit_phase()
	else:
		_finish_setup()


func _finish_setup() -> void:
	GameState.current_player_index = 0
	GameState.turn_phase = GameState.TurnPhase.ROLL
	scoring.recompute_all()
	_emit_phase()


func _on_city_upgraded(_vertex: Vector3i, owner_id: int) -> void:
	if not _is_authority():
		return
	_check_win(GameState.players[owner_id])


# --- Hauptzug ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and GameState.turn_phase == GameState.TurnPhase.ROLL:
		Net.request_roll()


## Würfelt 2d6. Bei 7 startet der Räuber, sonst Ressourcen verteilen → BUILD.
func roll_dice() -> void:
	if not _is_authority():
		return
	if GameState.turn_phase != GameState.TurnPhase.ROLL:
		return
	var value := RNG.randi_range(1, 6) + RNG.randi_range(1, 6)
	Net.send_dice(value)
	if value == 7:
		_begin_robber()
	else:
		production.collect_resources(value)
		scoring.recompute_all()
		GameState.turn_phase = GameState.TurnPhase.BUILD
		_emit_phase()


## Beendet den Zug des aktuellen Spielers und gibt an den nächsten weiter.
func end_turn() -> void:
	if not _is_authority():
		return
	if GameState.turn_phase != GameState.TurnPhase.BUILD:
		return
	if _check_win(GameState.current_player()):
		return
	var n := GameState.players.size()
	GameState.current_player_index = (GameState.current_player_index + 1) % n
	GameState.advance_turn()
	# Synchroner Stage-Takt: nach jeder vollen Runde × ROUNDS_PER_STAGE → Draft.
	if GameState.turn % (DraftConfig.ROUNDS_PER_STAGE * n) == 0:
		_begin_stage_draft()
	else:
		GameState.turn_phase = GameState.TurnPhase.ROLL
		_emit_phase()


# --- Räuber (bei einer 7) ------------------------------------------------------

func _begin_robber() -> void:
	_discard_queue.clear()
	for p in GameState.players:
		if p.total_cards() > 7:
			_discard_queue.append(p.id)
	if _discard_queue.is_empty():
		_begin_robber_move()
	else:
		GameState.turn_phase = GameState.TurnPhase.ROBBER_DISCARD
		_emit_phase()
		_request_next_discard()


func _request_next_discard() -> void:
	if _discard_queue.is_empty():
		_begin_robber_move()
		return
	var pid := _discard_queue[0]
	var count := GameState.players[pid].total_cards() / 2   # ganzzahlig: abrunden
	Net.send_robber_discard_required(pid, count)


func _on_discard_submitted(player_id: int, discards: Dictionary) -> void:
	if not _is_authority():
		return
	if GameState.turn_phase != GameState.TurnPhase.ROBBER_DISCARD:
		return
	if not _discard_queue.has(player_id):
		return   # nur angeforderte Spieler dürfen abwerfen (Anti-Spoofing)
	GameState.spend(GameState.players[player_id], discards)
	_discard_queue.erase(player_id)
	_request_next_discard()


func _begin_robber_move() -> void:
	GameState.turn_phase = GameState.TurnPhase.ROBBER_MOVE
	_emit_phase()


func _on_robber_tile_chosen(tile: Vector2i) -> void:
	if not _is_authority():
		return
	if GameState.turn_phase != GameState.TurnPhase.ROBBER_MOVE:
		return
	if tile == GameState.robber_tile or not GameState.tiles.has(tile):
		return   # Räuber muss auf ein anderes Feld
	Net.send_robber_moved(tile)
	var victims := _victims_at(tile)
	if victims.is_empty():
		_finish_robber()
	elif victims.size() == 1:
		_steal_from(victims[0])
		_finish_robber()
	else:
		Net.send_robber_victims(victims)   # Auswahl durch Spieler


func _on_robber_victim_chosen(victim_id: int) -> void:
	if not _is_authority():
		return
	if GameState.turn_phase != GameState.TurnPhase.ROBBER_MOVE:
		return
	_steal_from(victim_id)
	_finish_robber()


## Spieler-IDs (≠ aktueller Spieler) mit Siedlung/Stadt am Tile und Handkarten.
func _victims_at(tile: Vector2i) -> Array:
	var hex := HexGrid.new()
	var ids: Array = []
	for vertex in hex.get_vertices(tile):
		var s: Settlement = GameState.settlements.get(vertex)
		if s == null or s.owner_id == GameState.current_player_index:
			continue
		if ids.has(s.owner_id):
			continue
		if RelicSystem.robber_immune(GameState.players[s.owner_id]):
			continue   # Relic: dieser Spieler ist räuber-immun
		if GameState.players[s.owner_id].total_cards() > 0:
			ids.append(s.owner_id)
	return ids


func _steal_from(victim_id: int) -> void:
	var thief: Player = GameState.current_player()
	# Normaler Diebstahl + ggf. Relic-Extra-Diebstähle (Plünderer).
	var count := 1 + RelicSystem.extra_seven_steals(thief)
	for _i in count:
		if not _steal_one(victim_id, thief):
			break


## Stiehlt eine zufällige Karte vom Opfer. Gibt false zurück, wenn das Opfer leer ist.
func _steal_one(victim_id: int, thief: Player) -> bool:
	var victim: Player = GameState.players[victim_id]
	var pool: Array = []
	for id in victim.resources:
		for _i in victim.get_resource(id):
			pool.append(id)
	if pool.is_empty():
		return false
	var res: StringName = pool[RNG.randi_range(0, pool.size() - 1)]
	GameState.add_resource_to(victim, res, -1)
	GameState.add_resource_to(thief, res, 1)
	Net.send_resource_stolen(victim_id, thief.id, res)
	return true


func _finish_robber() -> void:
	GameState.turn_phase = GameState.TurnPhase.BUILD
	_emit_phase()


# --- Relic-Draft (Stage-Ende) --------------------------------------------------

## Startet den Draft am Stage-Ende: Reihenfolge + Ring bauen, Phase/Ring/erster
## Drafter an alle Peers melden. Nur host-/offline-autoritativ.
func _begin_stage_draft() -> void:
	GameState.stage += 1
	GameState.turn_phase = GameState.TurnPhase.DRAFT
	EventBus.stage_completed.emit(GameState.stage)
	_build_draft_order()
	_draft_pos = 0
	_draft_ring = _draw_relic_pool(_draft_order.size())
	_emit_phase()                       # Phase DRAFT an alle
	Net.send_draft_offer(_draft_ring)   # Ring-Visual an alle
	_advance_draft()                    # ersten Drafter melden (oder sofort beenden)


## Baut die Pick-Reihenfolge nach Siegpunkten (Rückstand zuerst). SNAKE: zwei
## Durchläufe als Schlange (1-2-3-4-4-3-2-1). CATCHUP: ein Durchlauf je Spieler.
func _build_draft_order() -> void:
	scoring.recompute_all()
	_draft_order = DraftOrder.build(GameState.players)


## Zieht eindeutige Relic-IDs für den Ring (deterministisch über RNG). CATCHUP legt
## einen Auswahlpuffer drauf, damit auch der letzte Spieler echte Wahl hat.
func _draw_relic_pool(num_picks: int) -> Array:
	var pool_size := num_picks
	if DraftConfig.MODE == DraftConfig.DraftMode.CATCHUP:
		pool_size = num_picks + DraftConfig.CHOICES_PER_PICK - 1
	var ids: Array = ContentDB.relics.keys()
	RNG.shuffle(ids)
	return ids.slice(0, mini(pool_size, ids.size()))


## Meldet den nächsten Drafter oder beendet den Draft, wenn keiner/nichts mehr da ist.
func _advance_draft() -> void:
	if _draft_pos >= _draft_order.size() or _draft_ring.is_empty():
		_finish_draft()
		return
	Net.send_draft_turn(_draft_order[_draft_pos])


## Verarbeitet die Wahl des aktiven Drafters (Absender bereits in Net validiert).
func _on_draft_pick_requested(relic_id: StringName) -> void:
	if not _is_authority():
		return
	if GameState.turn_phase != GameState.TurnPhase.DRAFT:
		return
	if _draft_pos >= _draft_order.size():
		return
	if not _draft_ring.has(relic_id):
		return   # Relic nicht (mehr) im Ring — ignorieren (Anti-Spoofing)
	var pid := _draft_order[_draft_pos]
	_draft_ring.erase(relic_id)
	Net.send_relic_assigned(pid, relic_id)
	scoring.recompute_all()             # Synergie-VP sofort spiegeln
	if _check_win(GameState.players[pid]):
		return                          # Relic-getriebener Sieg
	_draft_pos += 1
	_advance_draft()


## Beendet den Draft: Ring abräumen, zurück in die normale Runde (ROLL).
func _finish_draft() -> void:
	Net.send_draft_turn(-1)
	EventBus.draft_finished.emit()
	GameState.turn_phase = GameState.TurnPhase.ROLL
	_emit_phase()


# --- Helfer --------------------------------------------------------------------

## Prüft Sieg des Spielers; setzt ggf. GAME_OVER und meldet den Gewinner.
func _check_win(player: Player) -> bool:
	scoring.recompute(player)
	if scoring.has_won(player):
		GameState.turn_phase = GameState.TurnPhase.GAME_OVER
		_emit_phase()
		Net.send_game_won(player.id, player.victory_points)
		return true
	return false


## Broadcastet den skalaren Zug-Zustand (Phase/Aktivspieler/Setup-Anker/Räuber) als
## Fakt an alle Peers; offline ein lokaler Aufruf. Feuert phase_changed +
## active_player_changed. Wird nur aus host-/offline-autoritativer Logik gerufen.
func _emit_phase() -> void:
	Net.send_turnstate()

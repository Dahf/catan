extends Node
## Transport-agnostischer Multiplayer-Kern. Autoload-Name: Net.
##
## Architektur (Richtung A): Command/Intent → Host-autoritativ → Fakten-Broadcast.
## Clients mutieren GameState nie direkt, sondern senden Absichten (request_*) per
## RPC an den Host (Peer 1). Der Host validiert und broadcastet Fakten (apply_*),
## die auf JEDEM Peer dieselbe Mutation + dasselbe EventBus-Fakt-Signal auslösen.
##
## Diese Phase (0/1) deckt Transport, Roster und Spielstart ab. Die Intent-/Fakt-
## RPCs der eigentlichen Spiel-Logik kommen in Phase 2 hinzu.
##
## Transport: Steam (über SteamManager) ODER ENet als Dev-Fallback, damit die
## komplette Netzwerk-Logik lokal mit zwei Instanzen testbar ist, bevor Steam-
## Binaries installiert sind. Der Host hat IMMER Peer-ID 1 und Roster-Slot 0.

signal roster_changed()
signal connection_succeeded()
signal connection_failed_()
signal server_disconnected_()
## Vom Host nach "Start" an alle gesendet. player_configs passt zu GameState.new_run().
signal game_started(seed: int, player_configs: Array)
## Ein (wieder-)beigetretener Peer hat einen Snapshot erhalten und soll in die
## Spielszene wechseln (ohne Neu-Generierung).
signal game_resumed()

const DEV_PORT := 24555
const MAX_PLAYERS := 4

enum Transport { NONE, ENET, STEAM }

# Roster: ein Eintrag pro Slot. Auf dem Host autoritativ, an Clients repliziert.
# { slot:int, peer_id:int, steam_id:int, name:String, color:Color, connected:bool }
var roster: Array = []
var local_slot: int = -1
var transport: int = Transport.NONE
var in_game: bool = false

# Host: zuletzt bekannte Steam-IDs getrennter Spieler für Reconnect-Matching (Phase 4).
var _held_slots: Dictionary = {}   # steam_id(int) -> slot(int)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- Status-Helfer -------------------------------------------------------------

## True, wenn ein Peer aktiv ist und dieser Prozess der autoritative Host ist.
func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()

## True, sobald überhaupt eine Mehrspieler-Sitzung aktiv ist.
func is_online() -> bool:
	return multiplayer.has_multiplayer_peer()

func my_peer_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1


# --- Verbindungsaufbau: ENet (Dev) ---------------------------------------------

## Hostet eine lokale ENet-Sitzung (Dev/Test ohne Steam).
func host_enet(port: int = DEV_PORT, host_name: String = "Host") -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("Net: ENet-Server konnte nicht erstellt werden: %d" % err)
		return err
	multiplayer.multiplayer_peer = peer
	transport = Transport.ENET
	_init_host_roster(host_name, 0)
	return OK


## Tritt einer lokalen ENet-Sitzung bei (Dev/Test ohne Steam).
func join_enet(address: String = "127.0.0.1", port: int = DEV_PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("Net: ENet-Client konnte nicht erstellt werden: %d" % err)
		return err
	multiplayer.multiplayer_peer = peer
	transport = Transport.ENET
	return OK


# --- Verbindungsaufbau: Steam --------------------------------------------------

## Von SteamManager aufgerufen, sobald ein fertig konfigurierter Steam-Peer als
## Host bereitsteht. host_steam_id wird als Identität von Slot 0 hinterlegt.
func attach_steam_host(peer: MultiplayerPeer, host_name: String, host_steam_id: int) -> void:
	multiplayer.multiplayer_peer = peer
	transport = Transport.STEAM
	_init_host_roster(host_name, host_steam_id)


## Von SteamManager aufgerufen, sobald ein Steam-Peer als Client verbunden ist.
func attach_steam_client(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	transport = Transport.STEAM


## Trennt die aktuelle Sitzung und setzt den Roster-Zustand zurück.
func disconnect_session() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	transport = Transport.NONE
	in_game = false
	roster.clear()
	local_slot = -1
	_held_slots.clear()
	roster_changed.emit()


# --- Roster (host-autoritativ) -------------------------------------------------

func _init_host_roster(host_name: String, host_steam_id: int) -> void:
	roster.clear()
	_held_slots.clear()
	roster.append(_make_slot(0, 1, host_steam_id, host_name))
	local_slot = 0
	roster_changed.emit()


func _make_slot(slot: int, peer_id: int, steam_id: int, pname: String) -> Dictionary:
	return {
		"slot": slot,
		"peer_id": peer_id,
		"steam_id": steam_id,
		"name": pname,
		"color": GameState.PLAYER_COLORS[slot % GameState.PLAYER_COLORS.size()],
		"connected": true,
	}


## Host: nächster freier Slot oder -1, wenn voll.
func _next_free_slot() -> int:
	var used := {}
	for entry in roster:
		used[entry["slot"]] = true
	for s in MAX_PLAYERS:
		if not used.has(s):
			return s
	return -1


func slot_of_peer(peer_id: int) -> int:
	for entry in roster:
		if entry["peer_id"] == peer_id:
			return entry["slot"]
	return -1


func peer_of_slot(slot: int) -> int:
	for entry in roster:
		if entry["slot"] == slot:
			return entry["peer_id"]
	return -1


# --- Multiplayer-Signale --------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if not is_host():
		return
	# Steam-Identität (für Reconnect-Matching) später über SteamManager; ENet: 0.
	var steam_id := _steam_id_for_peer(peer_id)
	var pname := _name_for_peer(peer_id, steam_id)

	# Reconnect: hatte diese Steam-ID schon einen Slot? (Phase 4)
	var slot := -1
	if steam_id != 0 and _held_slots.has(steam_id):
		slot = _held_slots[steam_id]
		_held_slots.erase(steam_id)
		_reactivate_slot(slot, peer_id, pname)
	else:
		slot = _next_free_slot()
		if slot == -1:
			# Lobby voll: Verbindung des neuen Peers ablehnen.
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
			return
		roster.append(_make_slot(slot, peer_id, steam_id, pname))

	roster_changed.emit()
	_sync_roster.rpc(roster)

	# Mitten im Spiel beigetreten/reconnected: vollständigen Zustand schicken.
	if in_game:
		_resume_peer.rpc_id(peer_id, GameState.to_snapshot())


## Host → (wieder-)beitretender Peer: Snapshot anwenden und in die Spielszene wechseln.
@rpc("authority", "call_remote", "reliable")
func _resume_peer(snapshot: Dictionary) -> void:
	GameState.apply_snapshot(snapshot)
	local_slot = slot_of_peer(my_peer_id())
	in_game = true
	game_resumed.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host():
		return
	var slot := slot_of_peer(peer_id)
	if slot == -1:
		return
	var entry = _entry_for_slot(slot)
	if entry == null:
		return
	if in_game:
		# Im Spiel: Slot für Reconnect freihalten (Phase 4).
		entry["connected"] = false
		entry["peer_id"] = -1
		if entry["steam_id"] != 0:
			_held_slots[entry["steam_id"]] = slot
	else:
		# In der Lobby: Slot komplett entfernen.
		roster.erase(entry)
	roster_changed.emit()
	_sync_roster.rpc(roster)


func _on_connected_to_server() -> void:
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	transport = Transport.NONE
	connection_failed_.emit()

func _on_server_disconnected() -> void:
	transport = Transport.NONE
	roster.clear()
	local_slot = -1
	server_disconnected_.emit()


func _reactivate_slot(slot: int, peer_id: int, pname: String) -> void:
	var entry = _entry_for_slot(slot)
	if entry == null:
		return
	entry["peer_id"] = peer_id
	entry["connected"] = true
	if pname != "":
		entry["name"] = pname


func _entry_for_slot(slot: int):
	for entry in roster:
		if entry["slot"] == slot:
			return entry
	return null


# Steam-Identität nur verfügbar, wenn SteamManager aktiv ist; sonst 0 (ENet-Dev).
func _steam_id_for_peer(peer_id: int) -> int:
	if SteamManager.available and transport == Transport.STEAM:
		return SteamManager.steam_id_for_peer(peer_id)
	return 0

func _name_for_peer(peer_id: int, steam_id: int) -> String:
	if steam_id != 0:
		return SteamManager.persona_name_for(steam_id)
	return "Spieler %d" % peer_id


# --- Roster-Replikation (Host → alle) ------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _sync_roster(new_roster: Array) -> void:
	roster = new_roster
	# Lokalen Slot anhand der eigenen Peer-ID bestimmen.
	local_slot = slot_of_peer(my_peer_id())
	roster_changed.emit()


# --- Spielstart (Host → alle) --------------------------------------------------

## Host: legt Seed fest und startet das Spiel auf allen Peers deterministisch.
func start_game() -> void:
	if not is_host():
		return
	var game_seed := randi()   # neuer Run-Seed; bewusst NICHT der geseedete RNG.
	in_game = true
	_begin_game.rpc(game_seed, roster)


@rpc("authority", "call_local", "reliable")
func _begin_game(game_seed: int, final_roster: Array) -> void:
	roster = final_roster
	local_slot = slot_of_peer(my_peer_id())
	in_game = true
	game_started.emit(game_seed, player_configs())


## Spieler-Konfigurationen aus dem Roster, passend zu GameState.new_run().
func player_configs() -> Array:
	var configs: Array = []
	for entry in roster:
		configs.append({"name": entry["name"], "color": entry["color"]})
	return configs


# ==============================================================================
# Phase 2: Intents (Client → Host) und Fakten (Host → alle)
# ==============================================================================
#
# Muster: Die UI ruft request_*(). Auf Host/Offline wird die Aktion direkt
# ausgeführt; auf einem Client wird ein _intent_*-RPC an Peer 1 gesendet. Der Host
# validiert (richtiger Absender) und führt dann aus. Die eigentlichen Mutationen
# laufen über send_*()/fact_*(): online als call_local-RPC an alle, offline als
# direkter lokaler Aufruf — derselbe Apply-Code-Pfad in beiden Fällen.

func _is_authority_runtime() -> bool:
	return (not is_online()) or is_host()

## Slot des RPC-Absenders (für Intent-Validierung).
func _sender_slot() -> int:
	return slot_of_peer(multiplayer.get_remote_sender_id())


# --- Intent: Resync (Client fordert aktuellen Zug-Zustand beim Boot an) ---------

func request_resync() -> void:
	if not _is_authority_runtime():
		_intent_resync.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _intent_resync() -> void:
	# Host sendet den aktuellen skalaren Zug-Zustand erneut an alle.
	send_turnstate()


# --- Intents: Würfeln / Zug beenden --------------------------------------------

func request_roll() -> void:
	if _is_authority_runtime():
		EventBus.roll_requested.emit()
	else:
		_intent_roll.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _intent_roll() -> void:
	if _sender_slot() == GameState.current_player_index:
		EventBus.roll_requested.emit()


func request_end_turn() -> void:
	if _is_authority_runtime():
		EventBus.end_turn_requested.emit()
	else:
		_intent_end_turn.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _intent_end_turn() -> void:
	if _sender_slot() == GameState.current_player_index:
		EventBus.end_turn_requested.emit()


# --- Intents: Bauen ------------------------------------------------------------

## Build-Intents geben für den lokalen (host/offline) Pfad den Erfolg zurück,
## damit die UI das getragene Bauteil nur bei Erfolg ablegt. Beim Client-Pfad
## wird optimistisch true geliefert (Eingabe ist clientseitig auf den eigenen Zug
## beschränkt, Phase 3); der Host validiert zusätzlich.
func request_place_settlement(vertex: Vector3i) -> bool:
	if _is_authority_runtime():
		return GameState.place_settlement(vertex, GameState.current_player())
	_intent_place_settlement.rpc_id(1, vertex)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _intent_place_settlement(vertex: Vector3i) -> void:
	if _sender_slot() == GameState.current_player_index:
		GameState.place_settlement(vertex, GameState.current_player())


func request_place_road(edge: Array) -> bool:
	if _is_authority_runtime():
		return GameState.place_road(edge, GameState.current_player())
	_intent_place_road.rpc_id(1, edge)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _intent_place_road(edge: Array) -> void:
	if _sender_slot() == GameState.current_player_index:
		GameState.place_road(edge, GameState.current_player())


func request_upgrade_city(vertex: Vector3i) -> bool:
	if _is_authority_runtime():
		return GameState.upgrade_city(vertex, GameState.current_player())
	_intent_upgrade_city.rpc_id(1, vertex)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _intent_upgrade_city(vertex: Vector3i) -> void:
	if _sender_slot() == GameState.current_player_index:
		GameState.upgrade_city(vertex, GameState.current_player())


# --- Intents: Räuber & Abwurf --------------------------------------------------

func request_robber_tile(tile: Vector2i) -> void:
	if _is_authority_runtime():
		EventBus.robber_tile_chosen.emit(tile)
	else:
		_intent_robber_tile.rpc_id(1, tile)

@rpc("any_peer", "call_remote", "reliable")
func _intent_robber_tile(tile: Vector2i) -> void:
	if _sender_slot() == GameState.current_player_index:
		EventBus.robber_tile_chosen.emit(tile)


func request_robber_victim(victim_id: int) -> void:
	if _is_authority_runtime():
		EventBus.robber_victim_chosen.emit(victim_id)
	else:
		_intent_robber_victim.rpc_id(1, victim_id)

@rpc("any_peer", "call_remote", "reliable")
func _intent_robber_victim(victim_id: int) -> void:
	if _sender_slot() == GameState.current_player_index:
		EventBus.robber_victim_chosen.emit(victim_id)


## player_id wird offline/host übernommen; per RPC leitet der Host ihn aus dem
## Absender-Slot ab (kein Abwerfen für fremde Spieler).
func request_discard(player_id: int, discards: Dictionary) -> void:
	if _is_authority_runtime():
		EventBus.discard_submitted.emit(player_id, discards)
	else:
		_intent_discard.rpc_id(1, discards)

@rpc("any_peer", "call_remote", "reliable")
func _intent_discard(discards: Dictionary) -> void:
	var pid := _sender_slot()
	if pid != -1:
		EventBus.discard_submitted.emit(pid, discards)


# --- Fakten: send_* (Host → alle / offline lokal) ------------------------------

func send_resource(player_id: int, id: StringName, delta: int) -> void:
	if is_online():
		fact_resource.rpc(player_id, String(id), delta)
	else:
		fact_resource(player_id, String(id), delta)

func send_settlement(vertex: Vector3i, owner_id: int, level: int) -> void:
	if is_online():
		fact_settlement.rpc(vertex, owner_id, level)
	else:
		fact_settlement(vertex, owner_id, level)

func send_road(edge: Array, owner_id: int) -> void:
	if is_online():
		fact_road.rpc(edge, owner_id)
	else:
		fact_road(edge, owner_id)

func send_city(vertex: Vector3i) -> void:
	if is_online():
		fact_city.rpc(vertex)
	else:
		fact_city(vertex)

func send_dice(value: int) -> void:
	if is_online():
		fact_dice.rpc(value)
	else:
		fact_dice(value)

func send_robber_moved(tile: Vector2i) -> void:
	if is_online():
		fact_robber_moved.rpc(tile)
	else:
		fact_robber_moved(tile)

func send_resource_stolen(from_id: int, to_id: int, res: StringName) -> void:
	if is_online():
		fact_resource_stolen.rpc(from_id, to_id, String(res))
	else:
		fact_resource_stolen(from_id, to_id, String(res))

func send_robber_discard_required(player_id: int, count: int) -> void:
	if is_online():
		fact_robber_discard_required.rpc(player_id, count)
	else:
		fact_robber_discard_required(player_id, count)

func send_robber_victims(victim_ids: Array) -> void:
	if is_online():
		fact_robber_victims.rpc(victim_ids)
	else:
		fact_robber_victims(victim_ids)

func send_game_won(player_id: int, score: int) -> void:
	if is_online():
		fact_game_won.rpc(player_id, score)
	else:
		fact_game_won(player_id, score)

## Synchronisiert die skalaren Zug-Zustände + feuert Phasen-/Aktivspieler-Signale.
func send_turnstate() -> void:
	var ts := {
		"phase": GameState.turn_phase,
		"current": GameState.current_player_index,
		"anchor": GameState.setup_road_anchor,
		"has_anchor": GameState.has_setup_anchor,
		"expect_road": GameState.setup_expect_road,
		"robber": GameState.robber_tile,
	}
	if is_online():
		fact_turnstate.rpc(ts)
	else:
		fact_turnstate(ts)


# --- Fakten: fact_* (auf jedem Peer angewandt) ---------------------------------

@rpc("authority", "call_local", "reliable")
func fact_resource(player_id: int, id: String, delta: int) -> void:
	var p: Player = GameState.players[player_id]
	p.add_resource(StringName(id), delta)
	EventBus.resource_changed.emit(player_id, StringName(id), p.get_resource(StringName(id)))

@rpc("authority", "call_local", "reliable")
func fact_settlement(vertex: Vector3i, owner_id: int, level: int) -> void:
	var s := Settlement.new()
	s.vertex = vertex
	s.level = level
	s.owner_id = owner_id
	GameState.settlements[vertex] = s
	GameState.players[owner_id].settlements.append(vertex)
	EventBus.settlement_placed.emit(vertex, owner_id)

@rpc("authority", "call_local", "reliable")
func fact_road(edge: Array, owner_id: int) -> void:
	var canon := GameState._hex.make_edge(edge[0], edge[1])
	GameState.roads[GameState._hex.edge_key(canon)] = owner_id
	GameState.players[owner_id].roads.append(canon)
	EventBus.road_placed.emit(canon, owner_id)

@rpc("authority", "call_local", "reliable")
func fact_city(vertex: Vector3i) -> void:
	var s: Settlement = GameState.settlements.get(vertex)
	if s == null:
		return
	var owner_id: int = s.owner_id
	s.level = 2
	GameState.players[owner_id].settlements.erase(vertex)
	GameState.players[owner_id].cities.append(vertex)
	EventBus.city_upgraded.emit(vertex, owner_id)

@rpc("authority", "call_local", "reliable")
func fact_dice(value: int) -> void:
	EventBus.dice_rolled.emit(value)

@rpc("authority", "call_local", "reliable")
func fact_robber_moved(tile: Vector2i) -> void:
	GameState.robber_tile = tile
	EventBus.robber_moved.emit(tile)

@rpc("authority", "call_local", "reliable")
func fact_resource_stolen(from_id: int, to_id: int, res: String) -> void:
	EventBus.resource_stolen.emit(from_id, to_id, StringName(res))

@rpc("authority", "call_local", "reliable")
func fact_robber_discard_required(player_id: int, count: int) -> void:
	EventBus.robber_discard_required.emit(player_id, count)

@rpc("authority", "call_local", "reliable")
func fact_robber_victims(victim_ids: Array) -> void:
	EventBus.robber_victims_available.emit(victim_ids)

@rpc("authority", "call_local", "reliable")
func fact_game_won(player_id: int, score: int) -> void:
	GameState.turn_phase = GameState.TurnPhase.GAME_OVER
	EventBus.game_won.emit(player_id)
	EventBus.run_ended.emit(score)

@rpc("authority", "call_local", "reliable")
func fact_turnstate(ts: Dictionary) -> void:
	GameState.turn_phase = ts["phase"]
	GameState.current_player_index = ts["current"]
	GameState.setup_road_anchor = ts["anchor"]
	GameState.has_setup_anchor = ts["has_anchor"]
	GameState.setup_expect_road = ts["expect_road"]
	GameState.robber_tile = ts["robber"]
	EventBus.phase_changed.emit()
	EventBus.active_player_changed.emit(GameState.current_player_index)

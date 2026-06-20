extends Node
## Globaler Signal-Hub zur Entkopplung von Core und Presentation.
## Autoload-Name: EventBus. Nur Signal-Deklarationen, keine Logik.

# --- Ressourcen / Wertung ---
signal resource_changed(player_id: int, id: StringName, amount: int)
signal victory_points_changed(player_id: int, vp: int)

# --- Würfel / Runde / Phasen ---
signal dice_rolled(value: int)
signal turn_advanced(turn: int)
signal phase_changed()
signal active_player_changed(index: int)
signal game_won(player_id: int)

# --- Platzierung ---
signal settlement_placed(vertex: Vector3i, owner_id: int)
signal road_placed(edge, owner_id: int)
signal city_upgraded(vertex: Vector3i, owner_id: int)

# --- Räuber ---
signal robber_moved(tile: Vector2i)
signal robber_discard_required(player_id: int, count: int)
signal robber_victims_available(victim_ids: Array)
signal resource_stolen(from_id: int, to_id: int, res: StringName)

# --- UI-Absichten (von HUD/Board ausgelöst, von main.gd verarbeitet) ---
signal roll_requested()
signal end_turn_requested()
signal robber_tile_chosen(tile: Vector2i)
signal robber_victim_chosen(victim_id: int)
signal discard_submitted(player_id: int, discards: Dictionary)

# --- Roguelike / Relic-Draft ---
signal stage_completed(stage: int)
signal run_ended(score: int)
signal relic_acquired(relic: Relic)
## Host → alle: ein Relic-Ring (Karussell) soll mit diesen IDs aufgebaut werden.
signal draft_ring_spawned(relic_ids: Array)
## Host → alle: dieser Spieler-Slot ist jetzt im Draft am Zug (-1 = keiner).
signal draft_turn_changed(player_id: int)
## Host → alle: der Draft dieser Stage ist beendet (Ring abräumen).
signal draft_finished()
## Absicht des aktiven Drafters, ein Relic aufzunehmen (auf Host validiert).
signal draft_pick_requested(relic_id: StringName)

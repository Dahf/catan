extends Node3D
## Einstiegspunkt des Spiels. Verdrahtet Board + UI und steuert den Spielzug-Loop.
var proc := ProcGen.new()
var production := ProductionSystem.new()
var demand := DemandSystem.new()

var test := Test.new()

func _ready() -> void:
	test.test_truth()
	EventBus.round_confirmed.connect(_on_round_confirmed)
	EventBus.ai_turn_done.connect(_resolve_turn)
	start_run()


## Startet einen neuen Run (Seed wählen, ProcGen, Board aufbauen).
func start_run() -> void:
	GameState.new_run(GameState.seed)
	proc.generate_stage(1)
	$GameBoard.build_from_state()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	match GameState.turn_phase:
		GameState.TurnPhase.ROLLING:
			_start_turn()
		GameState.TurnPhase.ROLLED:
			_enter_planning()
		GameState.TurnPhase.PLANNING:
			EventBus.round_confirmed.emit()
		GameState.TurnPhase.AI_PENDING:
			_enter_ai_turn()
		GameState.TurnPhase.AI_TURN:
			EventBus.ai_turn_done.emit()

## Phase 1 "Würfeln": würfelt, sammelt Tile-Ressourcen ein. Bleibt zunächst in
## einem Zwischenschritt (ROLLED), damit der Spieler die erhaltenen Ressourcen
## sieht, bevor mit der nächsten Leertaste die Planung geöffnet wird.
func _start_turn() -> void:
	var value := RNG.randi_range(1, 6) + RNG.randi_range(1, 6)
	EventBus.dice_rolled.emit(value)
	production.on_dice_rolled(value)
	GameState.turn_phase = GameState.TurnPhase.ROLLED
	EventBus.rolled_phase_entered.emit()


## Zwischenschritt -> Phase 2 "Planen": öffnet die Planungsphase.
func _enter_planning() -> void:
	GameState.turn_phase = GameState.TurnPhase.PLANNING
	EventBus.planning_phase_entered.emit()


## Planung bestätigt: Planungs-Screen schließt, Spieler kann sich wieder frei
## bewegen, bis er mit der Leertaste den KI-Zug startet.
func _on_round_confirmed() -> void:
	GameState.turn_phase = GameState.TurnPhase.AI_PENDING


## Phase 3 "KI-Zug": wird per Leertaste aus AI_PENDING gestartet.
## Platzhalter — die KI handelt hier noch nicht, reserviert nur den Schritt im Ablauf.
func _enter_ai_turn() -> void:
	GameState.turn_phase = GameState.TurnPhase.AI_TURN
	EventBus.ai_turn_entered.emit()


## Phase 4 "Ausführen": ausgelöst durch EventBus.ai_turn_done.
## Lässt nur die vom Spieler ausgewählten Fabriken produzieren, dann Nachfrage/Bevölkerung/Rundenwechsel.
func _resolve_turn() -> void:
	GameState.turn_phase = GameState.TurnPhase.RESOLVING
	production.run_factories()
	demand.consume_goods()
	demand.update_population()
	GameState.advance_turn()
	GameState.turn_phase = GameState.TurnPhase.ROLLING
	EventBus.round_resolved.emit(GameState.turn)

extends Node2D
## Einstiegspunkt des Spiels. Verdrahtet Board + UI und steuert den Spielzug-Loop.
var proc := ProcGen.new()
var production := ProductionSystem.new() 


func _ready() -> void:
	start_run()


## Startet einen neuen Run (Seed wählen, ProcGen, Board aufbauen).
func start_run() -> void:
	GameState.new_run(GameState.seed)
	proc.generate_stage(1)
	$GameBoard.build_from_state()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_process_turn()

## Führt einen kompletten Spielzug aus (Würfeln -> Produktion -> Nachfrage -> Ziel prüfen).
func _process_turn() -> void:
	var value := RNG.randi_range(1, 6) + RNG.randi_range(1, 6)
	EventBus.dice_rolled.emit(value)
	production.on_dice_rolled(value)
	GameState.advance_turn()

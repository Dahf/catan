extends Node2D
## Einstiegspunkt des Spiels. Verdrahtet Board + UI und steuert den Spielzug-Loop.
var proc := ProcGen.new()

func _ready() -> void:
	# TODO: Run starten, UI/Board initialisieren
	proc.generate_stage(1)
	for i in GameState.tiles.keys():
		print(GameState.tiles[i].terrain, "   ", GameState.tiles[i].number_token)


## Startet einen neuen Run (Seed wählen, ProcGen, Board aufbauen).
func start_run() -> void:
	# TODO
	pass


## Führt einen kompletten Spielzug aus (Würfeln -> Produktion -> Nachfrage -> Ziel prüfen).
func _process_turn() -> void:
	# TODO
	pass

extends Node2D
## Einstiegspunkt des Spiels. Verdrahtet Board + UI und steuert den Spielzug-Loop.
var hex := HexGrid.new()

func _ready() -> void:
	# TODO: Run starten, UI/Board initialisieren
	var range:= hex.get_range(Vector2i(0,0), 1)
	print(range)
	pass


## Startet einen neuen Run (Seed wählen, ProcGen, Board aufbauen).
func start_run() -> void:
	# TODO
	pass


## Führt einen kompletten Spielzug aus (Würfeln -> Produktion -> Nachfrage -> Ziel prüfen).
func _process_turn() -> void:
	# TODO
	pass

class_name ProductionSystem
extends RefCounted
## Verarbeitet Rohstoff-Gewinnung (durch Würfel) und Fabrik-Produktion.
## Reine Logik über GameState — keine Node-Abhängigkeit.

## Wird aufgerufen, wenn gewürfelt wurde: aktiviert passende Tiles.
func on_dice_rolled(value: int) -> void:
	# TODO
	pass


## Sammelt Rohstoffe aller Tiles mit passendem Zahlen-Token ins Lager.
func collect_resources(value: int) -> void:
	# TODO
	pass


## Lässt alle Fabriken/Verarbeiter ihre Rezepte ausführen (Input -> Output).
func run_factories() -> void:
	# TODO
	pass


## Ein vollständiger Produktions-Tick (collect + run_factories + Energie).
func tick() -> void:
	# TODO
	pass

class_name ProductionSystem
extends RefCounted
## Verarbeitet Rohstoff-Gewinnung (durch Würfel) und Fabrik-Produktion.
## Reine Logik über GameState — keine Node-Abhängigkeit.

## Wird aufgerufen, wenn gewürfelt wurde: aktiviert passende Tiles.
func on_dice_rolled(value: int) -> void:
	collect_resources(value)


## Sammelt Rohstoffe aller Tiles mit passendem Zahlen-Token ins Lager.
func collect_resources(value: int) -> void:
	for coord in GameState.tiles:
		var tile : Tile = GameState.tiles[coord]
		if tile.number_token != value:
			continue
		var type : StringName = Terrain.TERRAIN_RESOURCES.get(tile.terrain, &"")
		if type == &"":
			continue
			#TODO buildings
		GameState.add_resource(type, 1)


## Lässt alle Fabriken/Verarbeiter ihre Rezepte ausführen (Input -> Output).
func run_factories() -> void:
	# TODO
	pass


## Ein vollständiger Produktions-Tick (collect + run_factories + Energie).
func tick() -> void:
	# TODO
	pass

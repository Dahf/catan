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
## Bei knappen Inputs entscheidet die Gebäude-Priorität, wer zuerst bedient wird:
## die Liste wird absteigend sortiert, danach verändert spend() das gemeinsame
## Lager sofort, sodass niedriger priorisierte Gebäude den reduzierten Bestand
## sehen statt zufällig nach Dictionary-Reihenfolge zu konkurrieren.
func run_factories() -> void:
	var producers : Array[BuildingInstance] = []
	for coord in GameState.tiles:
		var tile : Tile = GameState.tiles[coord]
		var building : BuildingInstance = tile.building
		if building == null or not building.active or not building.produce_this_round \
				or building.def == null or building.def.recipe == null:
			continue
		producers.append(building)
	producers.sort_custom(func(a, b): return a.priority > b.priority)

	for building : BuildingInstance in producers:
		var recipe : Recipe = building.def.recipe
		if building.recipe_progress == 0:
			if not GameState.can_afford(recipe.inputs):
				continue
			GameState.spend(recipe.inputs)
			building.recipe_progress = 1
		else:
			building.recipe_progress += 1

		if building.recipe_progress >= recipe.turns_per_cycle:
			for resource in recipe.outputs:
				GameState.add_resource(resource, recipe.outputs[resource])
			building.recipe_progress = 0

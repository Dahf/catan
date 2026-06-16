extends Node
## Lädt allen data-driven Content (BuildingDef/Recipe/Relic) beim Start.
## Autoload-Name: ContentDB.

var buildings: Dictionary = {}   # StringName -> BuildingDef
var recipes: Dictionary = {}     # StringName -> Recipe
var relics: Dictionary = {}      # StringName -> Relic


## Lädt alle .tres-Ressourcen aus den content/-Ordnern.
func load_all() -> void:
	# TODO
	pass


func get_building(id: StringName) -> BuildingDef:
	# TODO
	return null


func get_recipe(id: StringName) -> Recipe:
	# TODO
	return null


func get_relic(id: StringName) -> Relic:
	# TODO
	return null


## Alle bekannten Bautypen (z.B. fürs Baumenü).
func all_buildings() -> Array[BuildingDef]:
	# TODO
	return []

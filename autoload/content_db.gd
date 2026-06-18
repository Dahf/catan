extends Node
## Lädt allen data-driven Content (BuildingDef/Recipe/Relic) beim Start.
## Autoload-Name: ContentDB.

var buildings: Dictionary = {}   # StringName -> BuildingDef
var recipes: Dictionary = {}     # StringName -> Recipe
var relics: Dictionary = {}      # StringName -> Relic

func _ready() -> void:
	load_all()
## Lädt alle .tres-Ressourcen aus den content/-Ordnern.
func load_all() -> void:
	_load_dir("res://content/buildings", buildings)
	pass

func _load_dir(path:String, target:Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var res := load(path.path_join(file))
		if res != null and &"id" in res:
			target[res.id] = res

func get_building(id: StringName) -> BuildingDef:
	return buildings.get(id)


func get_recipe(id: StringName) -> Recipe:
	return recipes.get(id)


func get_relic(id: StringName) -> Relic:
	return relics.get(id)


## Alle bekannten Bautypen (z.B. fürs Baumenü).
func all_buildings() -> Array[BuildingDef]:
	var res : Array[BuildingDef] = []
	for building in buildings.values():
		res.append(building)
	return res

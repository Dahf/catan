extends Node
## Lädt data-driven Content beim Start. Autoload-Name: ContentDB.
## In Kern-Catan gibt es keine data-driven Gebäude/Rezepte mehr (Straße/Siedlung/
## Stadt sind fest, Kosten als Konstanten in GameState). Das Relic-Laden bleibt
## als Hook für die spätere Roguelike-Schicht erhalten.

var relics: Dictionary = {}      # StringName -> Relic


func _ready() -> void:
	load_all()


## Lädt alle .tres-Ressourcen aus den content/-Ordnern.
func load_all() -> void:
	_load_dir("res://content/relics", relics)


func _load_dir(path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var res := load(path.path_join(file))
		if res != null and &"id" in res:
			target[res.id] = res


func get_relic(id: StringName) -> Relic:
	return relics.get(id)

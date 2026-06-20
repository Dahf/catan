class_name Player
extends RefCounted
## Ein Spieler im Catan-Run (Hot-Seat). Hält eigene Ressourcen, Gebäude und
## Siegpunkte. Die KI-Anbindung kommt später über das `is_ai`-Flag (Hook).

var id: int = -1
var display_name: String = ""
var color: Color = Color.WHITE
var resources: Dictionary = {}            # StringName -> int
var settlements: Array[Vector3i] = []     # Vertices mit Siedlung (Level 1)
var cities: Array[Vector3i] = []          # Vertices mit Stadt (Level 2)
var roads: Array = []                      # Array von Kanten ([Vector3i, Vector3i] sortiert)
var victory_points: int = 0
var is_ai: bool = false                    # Hook für spätere KI-Gegner
var relics: Array[Relic] = []              # im Draft erworbene Relikte (Besitz pro Spieler)


## Aktueller Bestand einer Ressource.
func get_resource(id: StringName) -> int:
	return resources.get(id, 0)


## Fügt (oder zieht bei negativem Wert) eine Ressourcenmenge hinzu.
func add_resource(id: StringName, amount: int) -> void:
	resources[id] = resources.get(id, 0) + amount


## Gesamtzahl der Handkarten (relevant für den 7er-Abwurf).
func total_cards() -> int:
	var n := 0
	for id in resources:
		n += resources[id]
	return n

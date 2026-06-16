extends Node
## Aktueller Run-Zustand (Daten-Kern). Autoload-Name: GameState.
## Hält alle Spieldaten; die Systeme operieren auf diesem Zustand.

var seed: int = 0
var tiles: Dictionary = {}            # Vector2i -> Tile
var settlements: Dictionary = {}      # Vector3i(vertex) -> Settlement
var storage: Dictionary = {}          # StringName -> int (Netzwerk-Lager)
var population: int = 0
var pop_tier: int = 1
var power_available: int = 0
var stage: int = 1
var turn: int = 0
var relics: Array[Relic] = []


## Startet einen neuen Run mit gegebenem Seed (setzt Zustand zurück).
func new_run(seed: int) -> void:
	# TODO
	pass


## Setzt den gesamten Run-Zustand zurück.
func reset() -> void:
	# TODO
	pass


## Liefert das Tile an einer Koordinate (oder null).
func get_tile(coord: Vector2i) -> Tile:
	# TODO
	return null


## Prüft, ob die Kosten aus dem Lager bezahlt werden können.
func can_afford(cost: Dictionary) -> bool:
	# TODO
	return false


## Zieht die Kosten vom Lager ab.
func spend(cost: Dictionary) -> void:
	# TODO
	pass


## Fügt eine Ressourcenmenge dem Lager hinzu.
func add_resource(id: StringName, amount: int) -> void:
	# TODO
	pass


## Platziert ein Gebäude auf einer Tile-Koordinate.
func place_building(coord: Vector2i, def: BuildingDef) -> void:
	# TODO
	pass


## Schaltet zur nächsten Runde weiter.
func advance_turn() -> void:
	# TODO
	pass

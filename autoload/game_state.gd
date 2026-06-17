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
	reset()
	self.seed = seed
	


## Setzt den gesamten Run-Zustand zurück.
func reset() -> void:
	tiles.clear()
	settlements.clear()
	storage.clear()
	population = 0
	pop_tier = 1
	power_available = 0
	stage = 1
	turn = 0
	relics.clear()


## Liefert das Tile an einer Koordinate (oder null).
func get_tile(coord: Vector2i) -> Tile:
	return tiles.get(coord)


## Prüft, ob die Kosten aus dem Lager bezahlt werden können.
func can_afford(cost: Dictionary) -> bool:
	for item in cost:
		if storage.get(item, 0) < cost[item]:
			return false
	return true


## Zieht die Kosten vom Lager ab.
func spend(cost: Dictionary) -> void:
	for item in cost:
		storage[item] = storage.get(item, 0) - cost[item]


## Fügt eine Ressourcenmenge dem Lager hinzu.
func add_resource(id: StringName, amount: int) -> void:
	storage[id] = storage.get(id, 0) + amount


## Platziert ein Gebäude auf einer Tile-Koordinate.
func place_building(coord: Vector2i, def: BuildingDef) -> void:
	# TODO
	pass


## Schaltet zur nächsten Runde weiter.
func advance_turn() -> void:
	turn += 1
	EventBus.turn_advanced.emit(turn)

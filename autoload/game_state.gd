extends Node
## Aktueller Run-Zustand (Daten-Kern). Autoload-Name: GameState.
## Hält alle Spieldaten; die Systeme operieren auf diesem Zustand.
var _hex = HexGrid.new()

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

enum TurnPhase { ROLLING, ROLLED, PLANNING, AI_PENDING, AI_TURN, RESOLVING }
var turn_phase: TurnPhase = TurnPhase.ROLLING

## True während ein Phasen-Overlay (Planung/KI-Zug) geöffnet ist und Spielfeld-
## Eingaben (Bewegung, Interaktion, Bauen) deshalb gesperrt sein sollen.
func is_input_blocked() -> bool:
	return turn_phase == TurnPhase.PLANNING or turn_phase == TurnPhase.AI_TURN

const DEFAULT_PRIORITY_BY_CATEGORY := {
	BuildingDef.Category.EXTRACTOR: 20,
	BuildingDef.Category.PROCESSOR: 10,
	BuildingDef.Category.FACTORY: 0,
}

## Start-Kapital, damit das erste Gebäude/Siedlung nicht am Henne-Ei-Problem
## (Ressource X nötig, um den Produzenten von X zu bauen) scheitert.
const STARTING_RESOURCES := {
	&"wood": 5,
	&"brick": 5,
	&"grain": 5,
	&"wool": 5,
}


## Startet einen neuen Run mit gegebenem Seed (setzt Zustand zurück).
func new_run(seed: int) -> void:
	reset()
	self.seed = seed
	for id in STARTING_RESOURCES:
		add_resource(id, STARTING_RESOURCES[id])



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
	turn_phase = TurnPhase.ROLLING


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
		EventBus.resource_changed.emit(item, storage[item])


## Fügt eine Ressourcenmenge dem Lager hinzu.
func add_resource(id: StringName, amount: int) -> void:
	storage[id] = storage.get(id, 0) + amount
	EventBus.resource_changed.emit(id, storage[id])


## Platziert ein Gebäude auf einer Tile-Koordinate.
func place_building(coord: Vector2i, def: BuildingDef) -> bool:
	var tile : Tile = tiles.get(coord)
	if tile == null or tile.is_water() or tile.has_building():
		return false
	if not def.valid_terrain.is_empty() and not def.valid_terrain.has(tile.terrain):
		return false
	if not can_afford(def.build_cost):
		return false
	var inst := BuildingInstance.new()
	inst.def = def
	inst.coord = coord
	inst.priority = DEFAULT_PRIORITY_BY_CATEGORY.get(def.category, 0)
	tile.building = inst
	spend(def.build_cost)
	EventBus.building_placed.emit(coord, def)
	return true
	
func place_settlement(vertex: Vector3i, def: BuildingDef) -> bool:
	if settlements.has(vertex):
		return false
	if not can_afford(def.build_cost):
		return false
	spend(def.build_cost)
	var s := Settlement.new()
	s.vertex = vertex
	settlements[vertex] = s
	EventBus.settlement_placed.emit(vertex, def)
	return true


## Schaltet ein platziertes Gebäude an/aus.
func set_building_active(coord: Vector2i, active: bool) -> void:
	var tile : Tile = tiles.get(coord)
	if tile == null or tile.building == null:
		return
	tile.building.active = active
	EventBus.building_updated.emit(coord)


## Setzt die Priorität eines Gebäudes bei knappen Inputs.
func set_building_priority(coord: Vector2i, priority: int) -> void:
	var tile : Tile = tiles.get(coord)
	if tile == null or tile.building == null:
		return
	tile.building.priority = priority
	EventBus.building_updated.emit(coord)


## Setzt die Produktions-Entscheidung für diese Runde (persistiert bis erneut geändert).
func set_building_produce_this_round(coord: Vector2i, produce: bool) -> void:
	var tile : Tile = tiles.get(coord)
	if tile == null or tile.building == null:
		return
	tile.building.produce_this_round = produce
	EventBus.building_updated.emit(coord)


## Schaltet zur nächsten Runde weiter.
func advance_turn() -> void:
	turn += 1
	EventBus.turn_advanced.emit(turn)

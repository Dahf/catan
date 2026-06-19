extends Node
## Globaler Signal-Hub zur Entkopplung von Core und Presentation.
## Autoload-Name: EventBus. Nur Signal-Deklarationen, keine Logik.

signal building_placed(coord: Vector2i, def: BuildingDef)
signal building_removed(coord: Vector2i)
signal resource_changed(id: StringName, amount: int)
signal dice_rolled(value: int)
signal turn_advanced(turn: int)
signal population_changed(population: int, tier: int)
signal stage_completed(stage: int)
signal run_ended(score: int)
signal relic_acquired(relic: Relic)
signal settlement_placed(vertex: Vector3i, def: BuildingDef)
signal carried_building_changed(def: BuildingDef)
signal building_selected(coord: Vector2i)
signal settlement_selected(vertex: Vector3i)
signal building_updated(coord: Vector2i)
signal rolled_phase_entered()
signal planning_phase_entered()
signal round_confirmed()
signal ai_turn_entered()
signal ai_turn_done()
signal round_resolved(turn: int)

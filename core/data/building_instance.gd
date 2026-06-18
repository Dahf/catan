class_name BuildingInstance
extends RefCounted
## Eine konkrete, platzierte Instanz eines Bautyps auf dem Brett.

var def: BuildingDef
var coord: Vector2i               # Tile-Koordinate (axial q,r)
var level: int = 1
var active: bool = true           # genug Energie/Input vorhanden?


## Gibt true zurück, wenn das Gebäude diesen Zyklus produzieren kann.
func can_produce() -> bool:
	if def == null or def.recipe == null:
		return false
	return GameState.can_afford(def.recipe.inputs)

class_name BuildingInstance
extends RefCounted
## Eine konkrete, platzierte Instanz eines Bautyps auf dem Brett.

var def: BuildingDef
var coord: Vector2i               # Tile-Koordinate (axial q,r)
var level: int = 1
var active: bool = true           # genug Energie/Input vorhanden?
var recipe_progress: int = 0      # Runden im aktuellen Produktionszyklus
var priority: int = 0             # höher = wird bei Engpässen zuerst bedient
var produce_this_round: bool = true   # Spieler-Entscheidung in der Planungsphase


## Gibt true zurück, wenn das Gebäude diesen Zyklus produzieren kann (reine
## Affordability-Prüfung, unabhängig von produce_this_round).
func can_produce() -> bool:
	if def == null or def.recipe == null:
		return false
	return GameState.can_afford(def.recipe.inputs)

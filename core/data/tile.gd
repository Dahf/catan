class_name Tile
extends RefCounted
## Ein einzelnes Hex-Feld im Spielzustand (reine Daten).

var coord: Vector2i                          # axial (q, r)
var terrain: Terrain.TerrainType = Terrain.TerrainType.DESERT
var number_token: int = 0                    # 0 = inaktiv, sonst 2..12
var building: BuildingInstance = null


## Gibt true zurück, wenn auf diesem Tile ein Gebäude steht.
func has_building() -> bool:
	return building != null


## Gibt true zurück, wenn dies ein Wasserfeld ist (unbebaubar).
func is_water() -> bool:
	return terrain == Terrain.TerrainType.WATER

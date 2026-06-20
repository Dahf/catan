class_name Tile
extends RefCounted
## Ein einzelnes Hex-Feld im Spielzustand (reine Daten).
## Gebäude leben im Catan-Modell auf Vertices/Kanten, nicht auf Tiles.

var coord: Vector2i                          # axial (q, r)
var terrain: Terrain.TerrainType = Terrain.TerrainType.DESERT
var number_token: int = 0                    # 0 = inaktiv (Wüste), sonst 2..12


## Gibt true zurück, wenn dies ein Wasserfeld ist (unbebaubar; in Kern-Catan ungenutzt).
func is_water() -> bool:
	return terrain == Terrain.TerrainType.WATER

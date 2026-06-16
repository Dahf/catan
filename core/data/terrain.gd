class_name Terrain
extends RefCounted
## Definiert die Terrain-Typen eines Hex-Tiles.
## Reine Definitionen — keine Logik.

enum TerrainType {
	FOREST,     # Wald     -> Holz
	HILLS,      # Hügel    -> Lehm
	MOUNTAINS,  # Berge    -> Stein / Erz / Kohle
	FIELDS,     # Felder   -> Getreide
	PASTURE,    # Weide    -> Wolle
	DESERT,     # Wüste    -> nichts
	WATER,      # Wasser   -> unbebaubar
}

# Anzeigenamen pro Terrain (selbst zu befüllen)
const TERRAIN_NAMES := {}

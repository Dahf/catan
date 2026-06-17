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

## Welcher Rohstoff aus welchem Terrain gewonnen wird (klassisches Catan-Mapping).
## DESERT/WATER fehlen bewusst -> liefern nichts.
const TERRAIN_RESOURCES := {
	TerrainType.FOREST: &"wood",
	TerrainType.HILLS: &"brick",
	TerrainType.MOUNTAINS: &"ore",
	TerrainType.FIELDS: &"grain",
	TerrainType.PASTURE: &"wool",
}

## Deutsche Anzeigenamen der Rohstoffe (fürs HUD).
const RESOURCE_NAMES := {
	&"wood": "Holz",
	&"brick": "Lehm",
	&"ore": "Erz",
	&"grain": "Getreide",
	&"wool": "Wolle",
}

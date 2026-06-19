class_name CatanPalette
extends RefCounted
## Zentrale Farb-/Beschriftungs-Konstanten für das Siedler-Theme.
## Einzige Quelle der Wahrheit für alle code-gebauten UI-Elemente (Chips, Badges, ...).
## Stil: dunkles, flaches Strategy-UI mit goldenen Akzenten (kein Parchment/Holz-Look).

const PARCHMENT_LIGHT := Color(0.88, 0.83, 0.74)
const PARCHMENT_DARK := Color(0.24, 0.18, 0.13)
const WOOD_BROWN := Color(0.85, 0.65, 0.25)
const WOOD_BROWN_DARK := Color(0.62, 0.47, 0.16)
const LEATHER_RED := Color(0.82, 0.30, 0.30)
const FOREST_GREEN := Color(0.4, 0.68, 0.32)
const AMBER_GOLD := Color(0.85, 0.65, 0.25)
const INK_BLACK := Color(0.95, 0.92, 0.86)

## Farbe je Ressource (für Chips), da keine Icon-Assets existieren.
const RESOURCE_COLORS := {
	&"wood": Color(0.36, 0.62, 0.4),
	&"brick": Color(0.82, 0.42, 0.28),
	&"ore": Color(0.58, 0.55, 0.5),
	&"grain": Color(0.88, 0.72, 0.25),
	&"wool": Color(0.85, 0.87, 0.9),
	&"plank": Color(0.78, 0.55, 0.3),
	&"tool": Color(0.55, 0.5, 0.45),
}

## Feste Anzeige-Reihenfolge der Ressourcen, damit Leisten nicht "springen".
const RESOURCE_ORDER: Array[StringName] = [
	&"wood", &"brick", &"ore", &"grain", &"wool", &"plank", &"tool",
]

## Badge-Farbe je Bautyp-Kategorie (BuildingDef.Category).
const CATEGORY_COLORS := {
	BuildingDef.Category.EXTRACTOR: AMBER_GOLD,
	BuildingDef.Category.PROCESSOR: FOREST_GREEN,
	BuildingDef.Category.FACTORY: LEATHER_RED,
	BuildingDef.Category.INFRASTRUCTURE: PARCHMENT_DARK,
	BuildingDef.Category.SETTLEMENT: WOOD_BROWN,
}

const CATEGORY_NAMES := {
	BuildingDef.Category.EXTRACTOR: "Extraktoren",
	BuildingDef.Category.PROCESSOR: "Verarbeitung",
	BuildingDef.Category.FACTORY: "Fabriken",
	BuildingDef.Category.INFRASTRUCTURE: "Infrastruktur",
	BuildingDef.Category.SETTLEMENT: "Siedlungen",
}

## Tier-Badge-Farbe für Siedlungen (eskalierend mit Bedeutung).
const TIER_COLORS := {
	1: PARCHMENT_DARK,
	2: AMBER_GOLD,
	3: LEATHER_RED,
}


static func resource_label(id: StringName) -> String:
	return Terrain.RESOURCE_NAMES.get(id, str(id))


static func resource_color(id: StringName) -> Color:
	return RESOURCE_COLORS.get(id, PARCHMENT_DARK)

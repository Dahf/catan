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
}

## Feste Anzeige-Reihenfolge der Ressourcen, damit Leisten nicht "springen".
const RESOURCE_ORDER: Array[StringName] = [
	&"wood", &"brick", &"ore", &"grain", &"wool",
]


static func resource_label(id: StringName) -> String:
	return Terrain.RESOURCE_NAMES.get(id, str(id))


static func resource_color(id: StringName) -> Color:
	return RESOURCE_COLORS.get(id, PARCHMENT_DARK)

class_name BuildingDef
extends Resource
## Definition eines Bautyps (data-driven, als .tres editierbar).
## Neuer Bautyp = neue .tres-Datei, kein Code.

enum Category { EXTRACTOR, PROCESSOR, FACTORY, INFRASTRUCTURE, SETTLEMENT }

# Platzierungs-Modell (Hybrid): auf einem Tile oder auf einer Ecke/Vertex
enum Placement { TILE, VERTEX }

@export var id: StringName
@export var display_name: String
@export var category: Category = Category.EXTRACTOR
@export var placement: Placement = Placement.TILE
@export var build_cost: Dictionary              # StringName(resource) -> int
@export var recipe: Recipe                       # null bei reiner Infrastruktur
@export var requires_power: bool = false
@export var valid_terrain: Array[Terrain.TerrainType] = []
@export var icon: Texture2D

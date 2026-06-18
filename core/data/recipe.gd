class_name Recipe
extends Resource
## Produktionsrezept eines Gebäudes (data-driven, als .tres editierbar).
## Beschreibt, welche Inputs pro Zyklus zu welchen Outputs werden.

@export var id: StringName
@export var inputs: Dictionary   # StringName(resource) -> int (pro Zyklus verbraucht)
@export var outputs: Dictionary  # StringName(resource) -> int (pro Zyklus erzeugt)
@export var ticks_per_cycle: int = 1

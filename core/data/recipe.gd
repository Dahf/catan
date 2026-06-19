class_name Recipe
extends Resource
## Produktionsrezept eines Gebäudes (data-driven, als .tres editierbar).
## Beschreibt, welche Inputs pro Zyklus zu welchen Outputs werden.

@export var id: StringName
@export var inputs: Dictionary   # StringName(resource) -> int (pro Zyklus verbraucht)
@export var outputs: Dictionary  # StringName(resource) -> int (pro Zyklus erzeugt)
@export var turns_per_cycle: int = 1   # Anzahl Spielzüge bis ein Zyklus fertig ist

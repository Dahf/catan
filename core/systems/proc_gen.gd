class_name ProcGen
extends RefCounted
## Seed-basierte prozedurale Generierung einer Stage/Region.
## Nutzt den zentralen RNG für reproduzierbare Welten.

## Generiert eine komplette Stage (Terrain, Token, Start, Modifikatoren).
func generate_stage(stage: int) -> void:
	# TODO
	pass


## Verteilt Terrain-Typen über das Brett.
func generate_terrain() -> void:
	# TODO
	pass


## Weist den Tiles Zahlen-Token (2..12) zu.
func assign_number_tokens() -> void:
	# TODO
	pass


## Wählt die Startposition des Spielers.
func choose_start_position() -> Vector2i:
	# TODO
	return Vector2i.ZERO

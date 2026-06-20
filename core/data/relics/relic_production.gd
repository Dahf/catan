class_name RelicProduction
extends Relic
## Produktions-Relic: erhöht die Rohstoff-Ausbeute bei passenden Tiles.
## Alle Bedingungen sind optional und werden UND-verknüpft.

## Nur dieses Terrain (Terrain.TerrainType); -1 = jedes.
@export var target_terrain: int = -1
## Bonus pro passendem Produktions-Treffer (z.B. +1 Holz je Wald).
@export var per_terrain: int = 0
## Nur Städte (Level 2)?
@export var city_only: bool = false
## Nur bei diesen Würfelwerten (leer = alle).
@export var dice_values: Array[int] = []
## Pauschaler Zusatz unabhängig von per_terrain.
@export var flat_bonus: int = 0
## Verdoppelt die Basis-Ausbeute (addiert base_amount).
@export var double: bool = false


func modify_production(ctx: Dictionary) -> int:
	var terrain: int = ctx.get("terrain", -1)
	var level: int = ctx.get("settlement_level", 1)
	var dice: int = ctx.get("dice_value", 0)
	var base: int = ctx.get("base_amount", 0)
	if target_terrain != -1 and terrain != target_terrain:
		return 0
	if city_only and level != 2:
		return 0
	if not dice_values.is_empty() and not dice_values.has(dice):
		return 0
	var bonus := per_terrain + flat_bonus
	if double:
		bonus += base
	return bonus

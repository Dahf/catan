class_name RelicSynergy
extends Relic
## Synergie-Relic: vergibt zusätzliche Siegpunkte abhängig vom eigenen Relic-Besitz
## → belohnt gezieltes Draften über mehrere Stages (Build-Around).

## +1 VP pro besessenem Relic dieser Kategorie (Relic.Category); -1 = aus.
@export var vp_per_category: int = -1
## +1 VP pro N besessener Relics (beliebige Kategorie); 0 = aus.
@export var vp_per_n_relics: int = 0


func bonus_victory_points(player: Player) -> int:
	var vp := 0
	if vp_per_category != -1:
		var count := 0
		for r in player.relics:
			if r.category == vp_per_category:
				count += 1
		vp += count
	if vp_per_n_relics > 0:
		vp += player.relics.size() / vp_per_n_relics
	return vp

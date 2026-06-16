class_name DemandSystem
extends RefCounted
## Bevölkerungs-Nachfrage: Konsum von Gütern, Wachstum/Verfall, Aufstiegsstufen.
## Reine Logik über GameState.

## Bevölkerung konsumiert benötigte Güter aus dem Lager.
func consume_goods() -> void:
	# TODO
	pass


## Passt Bevölkerung/Tier an, je nachdem ob die Nachfrage erfüllt wurde.
func update_population() -> void:
	# TODO
	pass


## Liefert die Güter-Nachfrage für eine Bevölkerungsstufe.
func demand_for_tier(tier: int) -> Dictionary:
	# TODO
	return {}

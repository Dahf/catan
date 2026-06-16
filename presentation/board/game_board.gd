extends Node2D
## Zeigt das Spielbrett an und reagiert auf Core-Events.
## Liest aus GameState, schickt Spieler-Eingaben als Commands an den Core.

func _ready() -> void:
	# TODO: an EventBus-Signale koppeln, Brett aus GameState aufbauen
	pass


## Baut die komplette Darstellung aus dem aktuellen GameState neu auf.
func build_from_state() -> void:
	# TODO
	pass


## Aktualisiert die Darstellung (z.B. nach einem Tick).
func refresh() -> void:
	# TODO
	pass


func _on_building_placed(coord: Vector2i, def: BuildingDef) -> void:
	# TODO
	pass


func _on_tile_clicked(coord: Vector2i) -> void:
	# TODO
	pass

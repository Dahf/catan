extends Node2D
## Zeigt das Spielbrett an und reagiert auf Core-Events.
## Liest aus GameState, schickt Spieler-Eingaben als Commands an den Core.


@onready var hex_map = $HexTileMap

var _tokens: Node2D

func _ready() -> void:
	# TODO: an EventBus-Signale koppeln, Brett aus GameState aufbauen
	_tokens = Node2D.new()
	_tokens.name = "Tokens"
	add_child(_tokens)
	pass


## Baut die komplette Darstellung aus dem aktuellen GameState neu auf.
func build_from_state() -> void:
	hex_map.clear_board()
	for child in _tokens.get_children():
		child.queue_free()
		
	for coord in GameState.tiles:
		var tile: Tile = GameState.tiles[coord]
		hex_map.set_terrain(coord, tile.terrain)
		if tile.number_token > 0:
			_add_token(coord, tile.number_token)
		

func _add_token(coord: Vector2i, value: int) -> void:
	var label := Label.new()
	label.text = str(value)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(hex_map.TILE_SIZE)
	label.position = hex_map.hex_to_world(coord) - Vector2(hex_map.TILE_SIZE) / 2.0
	label.add_theme_color_override("font_color", Color.BLACK)
	_tokens.add_child(label)
	
	
## Aktualisiert die Darstellung (z.B. nach einem Tick).
func refresh() -> void:
	build_from_state()


func _on_building_placed(coord: Vector2i, def: BuildingDef) -> void:
	# TODO
	pass


func _on_tile_clicked(coord: Vector2i) -> void:
	# TODO
	pass

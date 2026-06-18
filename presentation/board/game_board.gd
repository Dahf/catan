extends Node2D
## Zeigt das Spielbrett an und reagiert auf Core-Events.
## Liest aus GameState, schickt Spieler-Eingaben als Commands an den Core.

@onready var camera = $Camera2D


@onready var hex_map = $HexTileMap

var _tokens: Node2D
var _hex:= HexGrid.new()
var _build_def : BuildingDef = null
var _buildings_node : Node2D

func _ready() -> void:
	# TODO: an EventBus-Signale koppeln, Brett aus GameState aufbauen
	_buildings_node = Node2D.new()
	_buildings_node.name = "Buildings"
	add_child(_buildings_node)
	_tokens = Node2D.new()
	_tokens.name = "Tokens"
	add_child(_tokens)
	EventBus.build_mode_requested.connect(_on_build_mode_requested)
	EventBus.settlement_placed.connect(_on_settlement_placed)
	EventBus.building_placed.connect(_on_building_placed)



## Baut die komplette Darstellung aus dem aktuellen GameState neu auf.
func build_from_state() -> void:
	hex_map.clear_board()
	for child in _tokens.get_children():
		child.queue_free()
	for child in _buildings_node.get_children():
		child.queue_free()
	for coord in GameState.tiles:
		var tile: Tile = GameState.tiles[coord]
		hex_map.set_terrain(coord, tile.terrain)
		if tile.number_token > 0:
			_add_token(coord, tile.number_token)
	zoom_factor()
	
func zoom_factor() -> void:
	var min := Vector2(INF, INF)
	var max := Vector2(-INF, -INF)
	var half := Vector2(hex_map.TILE_SIZE) / 2
	
	for coord in GameState.tiles:
		var center : Vector2 = hex_map.hex_to_world(coord)
		min = min.min(center - half)
		max = max.max(center + half)
	
	var bs := (max - min)* 1.2
	var view := get_viewport_rect().size
	var zoomfactor : float = min(view.x/bs.x,view.y/bs.y)
	camera.zoom = Vector2(zoomfactor,zoomfactor)
	camera.position = (min + max) / 2
	

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

func _on_build_mode_requested(def: BuildingDef) -> void:
	_build_def = def
	

func _on_building_placed(coord: Vector2i, def: BuildingDef) -> void:
	var marker := Label.new()
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.text = def.display_name.substr(0, 1)
	marker.position = hex_map.hex_to_world(coord) - Vector2(hex_map.TILE_SIZE)/2
	marker.add_theme_color_override("font_color", Color.WHITE)
	_buildings_node.add_child(marker)


func _on_settlement_placed(vertex: Vector3i, def: BuildingDef) -> void:
	var dot := Label.new()
	dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.text = "⌂"
	dot.size = Vector2(hex_map.TILE_SIZE)
	dot.position = _vertex_world(vertex) 
	dot.add_theme_color_override("font_color", Color.WHITE)
	_buildings_node.add_child(dot)

func _vertex_world(vertex: Vector3i) -> Vector2:
	var sum := Vector2.ZERO
	var adj := _hex.vertex_adjacent_tiles(vertex)
	for coord in adj:
		sum += hex_map.hex_to_world(coord)
	return sum/float(adj.size())

func _unhandled_input(event: InputEvent) -> void:
	if _build_def == null:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world : Vector2 = hex_map.to_local(get_global_mouse_position())
		if _build_def.placement == BuildingDef.Placement.TILE:
			if GameState.place_building(hex_map.world_to_hex(world), _build_def):
				_build_def = null
		else:
			if GameState.place_settlement(_nearest_vertex(world), _build_def):
				_build_def = null
		
	return
	

func _nearest_vertex(world: Vector2) -> Vector3i:
	var hex_coord : Vector2i = hex_map.world_to_hex(world)
	var min = INF
	var best = Vector3i.ZERO
	for ver_coord in _hex.get_vertices(hex_coord):
		var pos : Vector2 = _vertex_world(ver_coord)
		var d := pos.distance_squared_to(world)
		if d < min:
			min = d
			best = ver_coord
	return best

func _on_tile_clicked(coord: Vector2i) -> void:
	# TODO
	pass

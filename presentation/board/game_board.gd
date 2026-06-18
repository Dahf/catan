extends Node3D
## Zeigt das Spielbrett in 3D an und reagiert auf Core-Events.
## Liest aus GameState, schickt Spieler-Eingaben (Maus-Raycast) als Commands an den Core.
## Steuert außerdem die isometrische Kamera (Follow <-> Übersicht) und platziert den
## laufbaren Character.

@onready var hex_map: HexBoard3D = $HexBoard
@onready var camera: Camera3D = $Camera3D
@onready var light: DirectionalLight3D = $DirectionalLight3D
@onready var player: CharacterBody3D = $Player

enum CamMode { FOLLOW, OVERVIEW }

const ISO_PITCH := -45.0     # Grad, Blick schräg nach unten
const ISO_YAW := 45.0        # Grad, isometrische Drehung
const FOLLOW_SIZE := 16.0    # orthogonale Sichthöhe im Follow-Modus
const FOLLOW_BACK := 24.0    # Abstand der Kamera entlang ihrer Blickachse

var _hex := HexGrid.new()
var _build_def: BuildingDef = null
var _buildings_node: Node3D
var _tokens: Node3D
var _walls_node: Node3D
var _cam_mode: CamMode = CamMode.FOLLOW
var _overview_center := Vector3.ZERO
var _overview_size := 24.0
var _bounds_min := Vector3.ZERO
var _bounds_max := Vector3.ZERO


func _ready() -> void:
	_buildings_node = Node3D.new()
	_buildings_node.name = "Buildings"
	add_child(_buildings_node)
	_tokens = Node3D.new()
	_tokens.name = "Tokens"
	add_child(_tokens)
	_walls_node = Node3D.new()
	_walls_node.name = "Walls"
	add_child(_walls_node)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(ISO_PITCH, ISO_YAW, 0.0)
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.shadow_enabled = true

	EventBus.build_mode_requested.connect(_on_build_mode_requested)
	EventBus.settlement_placed.connect(_on_settlement_placed)
	EventBus.building_placed.connect(_on_building_placed)


## Baut die komplette 3D-Darstellung aus dem aktuellen GameState neu auf.
func build_from_state() -> void:
	hex_map.clear_board()
	for child in _tokens.get_children():
		child.queue_free()
	for child in _buildings_node.get_children():
		child.queue_free()
	for child in _walls_node.get_children():
		child.queue_free()

	for coord in GameState.tiles:
		var tile: Tile = GameState.tiles[coord]
		hex_map.set_terrain(coord, tile.terrain)
		if tile.number_token > 0:
			_add_token(coord, tile.number_token)

	_compute_bounds()
	_build_perimeter()
	_place_player_start()


## Aktualisiert die Darstellung (z.B. nach einem Tick).
func refresh() -> void:
	build_from_state()


func _process(_delta: float) -> void:
	_update_camera()


# --- Kamera --------------------------------------------------------------------

func _update_camera() -> void:
	# Blickachse (Kamera schaut entlang -Z, +Z zeigt nach hinten).
	var back := camera.global_transform.basis.z
	if _cam_mode == CamMode.FOLLOW:
		camera.size = FOLLOW_SIZE
		camera.global_position = player.global_position + back * FOLLOW_BACK
	else:
		camera.size = _overview_size
		camera.global_position = _overview_center + back * (_overview_size * 1.5)


func _compute_bounds() -> void:
	if GameState.tiles.is_empty():
		_overview_center = Vector3.ZERO
		_overview_size = 24.0
		_bounds_min = Vector3.ZERO
		_bounds_max = Vector3.ZERO
		return
	var mn := Vector3(INF, 0.0, INF)
	var mx := Vector3(-INF, 0.0, -INF)
	for coord in GameState.tiles:
		var p: Vector3 = hex_map.hex_to_world(coord)
		mn.x = minf(mn.x, p.x)
		mn.z = minf(mn.z, p.z)
		mx.x = maxf(mx.x, p.x)
		mx.z = maxf(mx.z, p.z)
	_bounds_min = mn
	_bounds_max = mx
	_overview_center = (mn + mx) * 0.5
	var span := mx - mn
	_overview_size = maxf(span.x, span.z) + 6.0


## Unsichtbare Mauer rund um das Brett, damit der Character nicht herunterläuft.
func _build_perimeter() -> void:
	if GameState.tiles.is_empty():
		return
	var pad := 1.2
	var mn := _bounds_min - Vector3(pad, 0.0, pad)
	var mx := _bounds_max + Vector3(pad, 0.0, pad)
	var mid := (mn + mx) * 0.5
	var sx := mx.x - mn.x
	var sz := mx.z - mn.z
	var h := 3.0
	var thick := 0.5
	var specs := [
		[Vector3(mid.x, h * 0.5, mn.z), Vector3(sx + thick, h, thick)],
		[Vector3(mid.x, h * 0.5, mx.z), Vector3(sx + thick, h, thick)],
		[Vector3(mn.x, h * 0.5, mid.z), Vector3(thick, h, sz + thick)],
		[Vector3(mx.x, h * 0.5, mid.z), Vector3(thick, h, sz + thick)],
	]
	for spec in specs:
		var body := StaticBody3D.new()
		body.position = spec[0]
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[1]
		col.shape = box
		body.add_child(col)
		_walls_node.add_child(body)


func _place_player_start() -> void:
	if GameState.tiles.is_empty():
		return
	player.global_position = _overview_center + Vector3(0.0, 2.0, 0.0)
	player.velocity = Vector3.ZERO


# --- Marker / Tokens -----------------------------------------------------------

func _add_token(coord: Vector2i, value: int) -> void:
	var label := Label3D.new()
	label.text = str(value)
	label.font_size = 96
	label.pixel_size = 0.008
	label.modulate = Color.BLACK
	# Flach auf die Tile-Oberfläche legen (Text zeigt nach oben), leicht angehoben
	# gegen Z-Fighting mit der Hex-Oberseite.
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.position = hex_map.hex_to_world(coord) + Vector3(0.0, 0.03, 0.0)
	_tokens.add_child(label)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


## StaticBody mit zentrierter Box-Kollision (auf dem Boden stehend).
## Visuelle Meshes werden anschließend angehängt.
func _building_body(footprint: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = footprint
	col.shape = shape
	col.position = Vector3(0.0, footprint.y / 2.0, 0.0)
	body.add_child(col)
	return body


## Fabrik/Extraktor (TILE): flacher Quader mit kleinem Schornstein.
func _make_tile_building() -> StaticBody3D:
	var body := _building_body(Vector3(0.5, 0.4, 0.5))
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.4, 0.5)
	base.mesh = box
	base.material_override = _mat(Color(0.55, 0.57, 0.62))
	base.position = Vector3(0.0, 0.2, 0.0)
	body.add_child(base)
	var chimney := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.06
	cyl.height = 0.35
	chimney.mesh = cyl
	chimney.material_override = _mat(Color(0.3, 0.3, 0.33))
	chimney.position = Vector3(0.14, 0.55, 0.14)
	body.add_child(chimney)
	return body


## Siedlung (VERTEX): kleines Haus mit Spitzdach.
func _make_settlement() -> StaticBody3D:
	var body := _building_body(Vector3(0.3, 0.28, 0.3))
	var walls := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.28, 0.3)
	walls.mesh = box
	walls.material_override = _mat(Color(0.92, 0.89, 0.78))
	walls.position = Vector3(0.0, 0.14, 0.0)
	body.add_child(walls)
	var roof := MeshInstance3D.new()
	var pyramid := CylinderMesh.new()
	pyramid.top_radius = 0.0
	pyramid.bottom_radius = 0.26
	pyramid.height = 0.22
	pyramid.radial_segments = 4
	roof.mesh = pyramid
	roof.material_override = _mat(Color(0.7, 0.25, 0.18))
	roof.rotation_degrees = Vector3(0.0, 45.0, 0.0)   # Dachkanten parallel zu den Wänden
	roof.position = Vector3(0.0, 0.39, 0.0)
	body.add_child(roof)
	return body


# --- Event-Handler -------------------------------------------------------------

func _on_build_mode_requested(def: BuildingDef) -> void:
	_build_def = def


func _on_building_placed(coord: Vector2i, _def: BuildingDef) -> void:
	var b := _make_tile_building()
	b.position = hex_map.hex_to_world(coord)
	_buildings_node.add_child(b)


func _on_settlement_placed(vertex: Vector3i, _def: BuildingDef) -> void:
	var b := _make_settlement()
	b.position = _vertex_world(vertex)
	_buildings_node.add_child(b)


# --- Eingabe -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		_cam_mode = CamMode.OVERVIEW if _cam_mode == CamMode.FOLLOW else CamMode.FOLLOW
		return

	if _build_def == null:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world = _mouse_to_board()
		if world == null:
			return
		if _build_def.placement == BuildingDef.Placement.TILE:
			if GameState.place_building(hex_map.world_to_hex(world), _build_def):
				_build_def = null
		else:
			if GameState.place_settlement(_nearest_vertex(world), _build_def):
				_build_def = null


## Projiziert die Mausposition als Strahl auf die Brett-Ebene (y = 0).
## Liefert Vector3 oder null.
func _mouse_to_board():
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var plane := Plane(Vector3.UP, 0.0)
	return plane.intersects_ray(origin, dir)


# --- Vertex-Geometrie ----------------------------------------------------------

func _vertex_world(vertex: Vector3i) -> Vector3:
	var sum := Vector3.ZERO
	var adj := _hex.vertex_adjacent_tiles(vertex)
	for coord in adj:
		sum += hex_map.hex_to_world(coord)
	return sum / float(adj.size())


func _nearest_vertex(world: Vector3) -> Vector3i:
	var hex_coord := hex_map.world_to_hex(world)
	var best_d := INF
	var best := Vector3i.ZERO
	for ver_coord in _hex.get_vertices(hex_coord):
		var pos := _vertex_world(ver_coord)
		var d := pos.distance_squared_to(world)
		if d < best_d:
			best_d = d
			best = ver_coord
	return best

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
const INTERACTION_RANGE := 3.0   # max. Abstand Spieler <-> Gebäude für E-Interaktion

const DEPOT_SPACING := 2.8   # Abstand zwischen den Depot-Pickup-Punkten

const HEX_EDGE_PAD := 1.2        # Rand um die Hex-Mittelpunkte, bis zur äußeren Hex-Kante (Depot-Abstand)
const TABLE_PAD := 14.0          # großzügiger, aber endlicher Rand um die Hex-Fläche
const TABLE_THICKNESS := 0.6     # sichtbare Dicke der Tischplatte
const LEG_HEIGHT := 9.0
const LEG_SIZE := 1.8            # Breite/Tiefe der rechteckigen Beine
const LEG_INSET := LEG_SIZE / 2.0   # Beine sitzen bündig an der Tischkante
const TABLE_UV_TILE := 2.0       # Weltgröße einer Textur-Kachel (Planke)
const TABLE_COLOR := Color(0.42, 0.27, 0.16)   # Holzbraun

var _hex := HexGrid.new()
var _carried_def: BuildingDef = null   # aktuell vom Spieler getragener Bautyp
var _buildings_node: Node3D
var _tokens: Node3D
var _walls_node: Node3D
var _depot_node: Node3D
var _holo_labels: Dictionary = {}   # Vector2i -> Label3D
var _settlement_holo_labels: Dictionary = {}   # Vector3i -> Label3D
var _demand_system := DemandSystem.new()
var _interact_indicator: Label3D
var _ghost_node: Node3D = null   # Halbtransparente Bauvorschau am Drop-Ziel (nur während des Tragens)
var _ghost_mat_valid: StandardMaterial3D
var _ghost_mat_invalid: StandardMaterial3D
var _interact_target: Dictionary = {}   # {"coord"|"vertex": ...} oder {"depot_def": BuildingDef} oder {}
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
	_depot_node = Node3D.new()
	_depot_node.name = "Depot"
	add_child(_depot_node)

	_interact_indicator = Label3D.new()
	_interact_indicator.text = "[E]"
	_interact_indicator.font_size = 56
	_interact_indicator.pixel_size = 0.005
	_interact_indicator.modulate = Color(1.0, 0.85, 0.2)
	_interact_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interact_indicator.no_depth_test = true
	_interact_indicator.visible = false
	add_child(_interact_indicator)

	_ghost_mat_valid = _ghost_mat(Color(0.25, 1.0, 0.35, 0.5))
	_ghost_mat_invalid = _ghost_mat(Color(1.0, 0.25, 0.2, 0.5))

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(ISO_PITCH, ISO_YAW, 0.0)
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.shadow_enabled = true

	EventBus.settlement_placed.connect(_on_settlement_placed)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.turn_advanced.connect(_on_turn_advanced)
	EventBus.building_updated.connect(_on_building_updated)


## Baut die komplette 3D-Darstellung aus dem aktuellen GameState neu auf.
func build_from_state() -> void:
	hex_map.clear_board()
	for child in _tokens.get_children():
		child.queue_free()
	for child in _buildings_node.get_children():
		child.queue_free()
	for child in _walls_node.get_children():
		child.queue_free()
	for child in _depot_node.get_children():
		child.queue_free()

	for coord in GameState.tiles:
		var tile: Tile = GameState.tiles[coord]
		hex_map.set_terrain(coord, tile.terrain)
		if tile.number_token > 0:
			_add_token(coord, tile.number_token)

	_compute_bounds()
	_build_table()
	_place_player_start()
	_build_depot()


## Aktualisiert die Darstellung (z.B. nach einem Tick).
func refresh() -> void:
	build_from_state()


func _process(_delta: float) -> void:
	_update_camera()
	_update_interact_target()


## Aktualisiert das Interaktionsziel: ohne getragenes Bauteil das nächste
## Gebäude/Siedlung/Depot-Pickup in Reichweite, mit getragenem Bauteil das
## Drop-Ziel (Tile/Vertex) unter bzw. nahe dem Spieler.
func _update_interact_target() -> void:
	if _carried_def == null:
		_update_interact_target_idle()
	else:
		_update_interact_target_carrying()


func _update_interact_target_idle() -> void:
	var best_body : Node3D = null
	var best_d := INTERACTION_RANGE
	for body in _buildings_node.get_children():
		if not (body.has_meta(&"coord") or body.has_meta(&"vertex")):
			continue
		var d := player.global_position.distance_to(body.global_position)
		if d <= best_d:
			best_d = d
			best_body = body
	for body in _depot_node.get_children():
		var d := player.global_position.distance_to(body.global_position)
		if d <= best_d:
			best_d = d
			best_body = body

	if best_body == null:
		_interact_target = {}
		_interact_indicator.visible = false
		return

	if best_body.has_meta(&"coord"):
		_interact_target = {"coord": best_body.get_meta(&"coord")}
	elif best_body.has_meta(&"vertex"):
		_interact_target = {"vertex": best_body.get_meta(&"vertex")}
	else:
		_interact_target = {"depot_def": best_body.get_meta(&"depot_def")}

	_interact_indicator.modulate = Color(1.0, 0.85, 0.2)
	_interact_indicator.visible = true
	_interact_indicator.global_position = best_body.global_position + Vector3(0.0, 1.1, 0.0)


func _update_interact_target_carrying() -> void:
	var pos := player.global_position
	if _carried_def.placement == BuildingDef.Placement.TILE:
		var coord := hex_map.world_to_hex(pos)
		var tile : Tile = GameState.tiles.get(coord)
		if tile == null or player.global_position.distance_to(hex_map.hex_to_world(coord)) > INTERACTION_RANGE:
			_interact_target = {}
			_hide_ghost_and_indicator()
			return
		_interact_target = {"coord": coord}
		_show_ghost_at(hex_map.hex_to_world(coord), _can_drop_at_coord(coord))
	else:
		var vertex := _nearest_vertex(pos)
		var vpos := _vertex_world(vertex)
		if pos.distance_to(vpos) > INTERACTION_RANGE:
			_interact_target = {}
			_hide_ghost_and_indicator()
			return
		_interact_target = {"vertex": vertex}
		_show_ghost_at(vpos, _can_drop_at_vertex(vertex))


## Positioniert die Bauvorschau (Ghost) + "[E]"-Hinweis am Drop-Ziel und
## färbt den Ghost je nach Platzierbarkeit grün oder rot.
func _show_ghost_at(world_pos: Vector3, valid: bool) -> void:
	if _ghost_node == null:
		_ghost_node = _make_ghost(_carried_def)
		add_child(_ghost_node)
	_ghost_node.global_position = world_pos
	_ghost_node.visible = true
	_set_ghost_valid(valid)

	_interact_indicator.global_position = world_pos + Vector3(0.0, 0.9, 0.0)
	_interact_indicator.modulate = Color.LIME_GREEN if valid else Color.ORANGE_RED
	_interact_indicator.visible = true


func _hide_ghost_and_indicator() -> void:
	_interact_indicator.visible = false
	if _ghost_node != null:
		_ghost_node.visible = false


## Reine Lesbarkeits-Prüfung (keine Buchung), ob das getragene Bauteil hier
## platziert werden könnte — spiegelt die Validierung in GameState.place_building.
func _can_drop_at_coord(coord: Vector2i) -> bool:
	var tile : Tile = GameState.tiles.get(coord)
	if tile == null or tile.is_water() or tile.has_building():
		return false
	if not _carried_def.valid_terrain.is_empty() and not _carried_def.valid_terrain.has(tile.terrain):
		return false
	return GameState.can_afford(_carried_def.build_cost)


## Reine Lesbarkeits-Prüfung (keine Buchung) für Siedlungs-Drops.
func _can_drop_at_vertex(vertex: Vector3i) -> bool:
	if GameState.settlements.has(vertex):
		return false
	return GameState.can_afford(_carried_def.build_cost)


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


## Baut einen "echten" Tisch: dicke Holzplatte mit Maserungs-Textur und vier
## Beinen, großzügig groß (aber endlich) rund um die Hex-Fläche, plus eine
## unsichtbare Begrenzung an dessen Rand. Die Stufe zur Hex-Plattform ergibt
## sich aus der vorhandenen Hex-Dicke; hochkommen lässt sich der Character
## über die step_height-Logik in player.gd.
func _build_table() -> void:
	if GameState.tiles.is_empty():
		return
	var pad := HEX_EDGE_PAD + TABLE_PAD
	var mn := _bounds_min - Vector3(pad, 0.0, pad)
	var mx := _bounds_max + Vector3(pad, 0.0, pad)
	_build_table_surface(mn, mx)
	_build_table_legs(mn, mx)
	_build_perimeter(mn, mx)


## y-Position der begehbaren Tischoberfläche: knapp unter der Hex-Unterkante
## (HexBoard3D.HEIGHT), mit kleinem Sicherheitsabstand gegen Z-Fighting.
func _table_top_y() -> float:
	return -(HexBoard3D.HEIGHT + 0.02)


## Sichtbare, begehbare Holzplatte mit echter Dicke (man sieht die Kante).
func _build_table_surface(mn: Vector3, mx: Vector3) -> void:
	var mid := (mn + mx) * 0.5
	var size := Vector3(mx.x - mn.x, TABLE_THICKNESS, mx.z - mn.z)
	var top_y := _table_top_y()
	var body := StaticBody3D.new()
	body.position = Vector3(mid.x, top_y, mid.z)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := _wood_material()
	mat.uv1_scale = Vector3(size.x / TABLE_UV_TILE, size.z / TABLE_UV_TILE, 1.0)
	mesh.material_override = mat
	mesh.position = Vector3(0.0, -size.y / 2.0, 0.0)
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = Vector3(0.0, -size.y / 2.0, 0.0)
	body.add_child(col)
	_walls_node.add_child(body)


## Vier Tischbeine an den Ecken (rein dekorativ, ohne Kollision), damit die
## Platte auch wirklich wie ein Tisch und nicht wie ein schwebender Boden wirkt.
func _build_table_legs(mn: Vector3, mx: Vector3) -> void:
	var top_y := _table_top_y() - TABLE_THICKNESS
	var leg_mat := _mat(TABLE_COLOR.darkened(0.3))
	var corners := [
		Vector3(mn.x + LEG_INSET, 0.0, mn.z + LEG_INSET),
		Vector3(mn.x + LEG_INSET, 0.0, mx.z - LEG_INSET),
		Vector3(mx.x - LEG_INSET, 0.0, mn.z + LEG_INSET),
		Vector3(mx.x - LEG_INSET, 0.0, mx.z - LEG_INSET),
	]
	for corner in corners:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(LEG_SIZE, LEG_HEIGHT, LEG_SIZE)
		mesh.mesh = box
		mesh.material_override = leg_mat
		mesh.position = Vector3(corner.x, top_y - LEG_HEIGHT / 2.0, corner.z)
		_walls_node.add_child(mesh)


## Holzmaserungs-Material: prozedural erzeugte Planken-Textur (keine externen
## Asset-Dateien nötig), gekachelt über die ganze Tischplatte.
func _wood_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.albedo_texture = _make_wood_texture()
	mat.roughness = 0.85
	return mat


func _make_wood_texture() -> ImageTexture:
	var size := 128
	var base := TABLE_COLOR
	var dark := TABLE_COLOR.darkened(0.35)
	var light := TABLE_COLOR.lightened(0.12)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for x in size:
		var plank := x % 32
		var grain := sin(float(x) * 0.35) * 0.5 + 0.5
		var col := base.lerp(light, grain * 0.3)
		if plank < 2:
			col = dark
		for y in size:
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Unsichtbare Mauer rund um den Tischrand, damit der Character nicht herunterläuft.
func _build_perimeter(mn: Vector3, mx: Vector3) -> void:
	var mid := (mn + mx) * 0.5
	var sx := mx.x - mn.x
	var sz := mx.z - mn.z
	var h := 3.0
	var thick := 0.5
	var base_y := _table_top_y() + h * 0.5
	var specs := [
		[Vector3(mid.x, base_y, mn.z), Vector3(sx + thick, h, thick)],
		[Vector3(mid.x, base_y, mx.z), Vector3(sx + thick, h, thick)],
		[Vector3(mn.x, base_y, mid.z), Vector3(thick, h, sz + thick)],
		[Vector3(mx.x, base_y, mid.z), Vector3(thick, h, sz + thick)],
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


## Baut das feste Depot: eine Reihe (größerer) Pickup-Punkte, einer pro
## Bautyp, auf der Tischfläche neben der erhöhten Hex-Plattform.
func _build_depot() -> void:
	if GameState.tiles.is_empty():
		return
	var defs := ContentDB.all_buildings()
	var start_x := _overview_center.x - (defs.size() - 1) * DEPOT_SPACING * 0.5
	var z := _bounds_max.z + HEX_EDGE_PAD + 1.0
	for i in defs.size():
		var def : BuildingDef = defs[i]
		var point := _make_depot_point(def)
		point.position = Vector3(start_x + i * DEPOT_SPACING, _table_top_y(), z)
		point.set_meta(&"depot_def", def)
		_depot_node.add_child(point)


const DEPOT_BASE_COLOR := Color(0.85, 0.7, 0.25)


## Pickup-Platzhalter im Depot: Sockel + erkennbares Mini-Modell des Bautyps
## + großes, schwebendes Namens-Label.
func _make_depot_point(def: BuildingDef) -> StaticBody3D:
	var body := _building_body(Vector3(1.0, 0.35, 1.0))
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.35, 1.0)
	base.mesh = box
	base.material_override = _mat(DEPOT_BASE_COLOR)
	base.position = Vector3(0.0, 0.175, 0.0)
	body.add_child(base)

	var model := _make_depot_model(def.id)
	model.position = Vector3(0.0, 0.35, 0.0)
	body.add_child(model)

	var label := Label3D.new()
	label.text = def.display_name
	label.font_size = 110
	label.pixel_size = 0.008
	label.outline_size = 18
	label.modulate = DEPOT_BASE_COLOR
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 1.5, 0.0)
	body.add_child(label)
	return body


## Erkennbares Mini-Modell pro Bautyp (Platzhalter-Primitiven, kein Asset
## nötig), damit man im Depot sofort sieht, welches Gebäude man aufhebt.
func _make_depot_model(id: StringName) -> Node3D:
	match id:
		&"settlement":
			return _without_collision(_make_settlement())
		&"extractor":
			return _make_depot_pick()
		&"sawmill":
			return _make_depot_saw()
		&"smithy":
			return _make_depot_anvil()
		_:
			return _without_collision(_make_tile_building())


## Entfernt die Kollisionsform eines per _make_tile_building()/_make_settlement()
## erzeugten Körpers — als rein dekoratives Depot-Modell braucht es keine.
func _without_collision(body: StaticBody3D) -> StaticBody3D:
	body.get_child(0).queue_free()
	return body


## Spitzhacke (Extraktor): zwei gekreuzte Balken auf einem kurzen Stiel.
func _make_depot_pick() -> Node3D:
	var root := Node3D.new()
	var mat := _mat(Color(0.45, 0.45, 0.48))
	var head := MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.85, 0.12, 0.12)
	head.mesh = head_box
	head.material_override = mat
	head.rotation_degrees = Vector3(0.0, 0.0, 25.0)
	head.position = Vector3(0.0, 0.55, 0.0)
	root.add_child(head)
	var handle := MeshInstance3D.new()
	var handle_box := BoxMesh.new()
	handle_box.size = Vector3(0.1, 0.6, 0.1)
	handle.mesh = handle_box
	handle.material_override = _mat(Color(0.5, 0.35, 0.2))
	handle.rotation_degrees = Vector3(0.0, 0.0, -20.0)
	handle.position = Vector3(0.0, 0.25, 0.0)
	root.add_child(handle)
	return root


## Sägeblatt (Sägewerk): stehende Scheibe mit Zähnen auf einem Sockelpfosten.
func _make_depot_saw() -> Node3D:
	var root := Node3D.new()
	var post := MeshInstance3D.new()
	var post_cyl := CylinderMesh.new()
	post_cyl.top_radius = 0.06
	post_cyl.bottom_radius = 0.06
	post_cyl.height = 0.3
	post.mesh = post_cyl
	post.material_override = _mat(Color(0.5, 0.35, 0.2))
	post.position = Vector3(0.0, 0.15, 0.0)
	root.add_child(post)
	var blade := MeshInstance3D.new()
	var blade_cyl := CylinderMesh.new()
	blade_cyl.top_radius = 0.45
	blade_cyl.bottom_radius = 0.45
	blade_cyl.height = 0.08
	blade_cyl.radial_segments = 12
	blade.mesh = blade_cyl
	blade.material_override = _mat(Color(0.75, 0.76, 0.78))
	blade.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	blade.position = Vector3(0.0, 0.55, 0.0)
	root.add_child(blade)
	return root


## Amboss (Schmiede): breite Arbeitsfläche, Taille und Fuß.
func _make_depot_anvil() -> Node3D:
	var root := Node3D.new()
	var mat := _mat(Color(0.2, 0.2, 0.22))
	var top := MeshInstance3D.new()
	var top_box := BoxMesh.new()
	top_box.size = Vector3(0.7, 0.18, 0.32)
	top.mesh = top_box
	top.material_override = mat
	top.position = Vector3(0.0, 0.65, 0.0)
	root.add_child(top)
	var waist := MeshInstance3D.new()
	var waist_box := BoxMesh.new()
	waist_box.size = Vector3(0.3, 0.22, 0.26)
	waist.mesh = waist_box
	waist.material_override = mat
	waist.position = Vector3(0.0, 0.45, 0.0)
	root.add_child(waist)
	var foot := MeshInstance3D.new()
	var foot_box := BoxMesh.new()
	foot_box.size = Vector3(0.5, 0.18, 0.4)
	foot.mesh = foot_box
	foot.material_override = mat
	foot.position = Vector3(0.0, 0.25, 0.0)
	root.add_child(foot)
	return root


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


## Transparentes Material für die Ghost-Vorschau (ohne Schatten/Beleuchtung,
## damit Grün/Rot klar erkennbar bleibt).
func _ghost_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Baut die halbtransparente Bauvorschau passend zur Platzierungsart des
## Bautyps (gleiche Silhouette wie das fertige Gebäude, ohne Kollision).
func _make_ghost(def: BuildingDef) -> Node3D:
	var ghost : Node3D
	if def.placement == BuildingDef.Placement.TILE:
		ghost = _make_tile_building()
	else:
		ghost = _make_settlement()
	(ghost as StaticBody3D).get_child(0).queue_free()   # Kollisionsform: Ghost soll nicht blockieren
	for child in ghost.get_children():
		if child is MeshInstance3D:
			child.material_override = _ghost_mat_valid
	return ghost


func _set_ghost_valid(valid: bool) -> void:
	var mat := _ghost_mat_valid if valid else _ghost_mat_invalid
	for child in _ghost_node.get_children():
		if child is MeshInstance3D:
			child.material_override = mat


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

func _on_building_placed(coord: Vector2i, def: BuildingDef) -> void:
	var b := _make_tile_building()
	b.position = hex_map.hex_to_world(coord)
	b.set_meta(&"coord", coord)
	_buildings_node.add_child(b)
	if def.recipe != null:
		var label := _make_holo_label()
		b.add_child(label)
		_holo_labels[coord] = label
		_update_holo_label(coord)


func _on_settlement_placed(vertex: Vector3i, _def: BuildingDef) -> void:
	var b := _make_settlement()
	b.position = _vertex_world(vertex)
	b.set_meta(&"vertex", vertex)
	_buildings_node.add_child(b)
	var label := _make_settlement_holo_label()
	b.add_child(label)
	_settlement_holo_labels[vertex] = label
	_update_settlement_holo_label(vertex)


func _on_turn_advanced(_turn: int) -> void:
	for coord in _holo_labels:
		_update_holo_label(coord)
	for vertex in _settlement_holo_labels:
		_update_settlement_holo_label(vertex)


func _on_building_updated(coord: Vector2i) -> void:
	_update_holo_label(coord)


## Erzeugt ein schwebendes, immer zur Kamera ausgerichtetes Label ("Holo-Display").
func _make_holo_label() -> Label3D:
	var label := Label3D.new()
	label.font_size = 48
	label.pixel_size = 0.004
	label.modulate = Color(0.4, 0.95, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 0.9, 0.0)
	return label


## Aktualisiert den Holo-Text eines Gebäudes mit Input -> Output und Fortschritt.
func _update_holo_label(coord: Vector2i) -> void:
	var label : Label3D = _holo_labels.get(coord)
	var tile : Tile = GameState.tiles.get(coord)
	if label == null or tile == null or tile.building == null or tile.building.def.recipe == null:
		return
	var recipe : Recipe = tile.building.def.recipe
	label.text = "%s → %s  (%d/%d)" % [
		_format_goods(recipe.inputs),
		_format_goods(recipe.outputs),
		tile.building.recipe_progress,
		recipe.turns_per_cycle,
	]
	label.modulate = Color(0.4, 0.95, 1.0) if tile.building.produce_this_round else Color(0.5, 0.5, 0.5, 0.6)


## Erzeugt das schwebende Countdown-Label über einer Siedlung (Tier 2+ Nachschub).
func _make_settlement_holo_label() -> Label3D:
	var label := Label3D.new()
	label.font_size = 44
	label.pixel_size = 0.0035
	label.modulate = Color(1.0, 0.55, 0.15)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 0.7, 0.0)
	label.visible = false
	return label


## Aktualisiert den Countdown bis zur nächsten periodischen Nachfrage (Holz/Erz ab Tier 2).
func _update_settlement_holo_label(vertex: Vector3i) -> void:
	var label : Label3D = _settlement_holo_labels.get(vertex)
	var settlement : Settlement = GameState.settlements.get(vertex)
	if label == null or settlement == null:
		return
	var periodic := _demand_system.periodic_demand_for_tier(settlement.pop_tier)
	if periodic.is_empty():
		label.visible = false
		return
	label.visible = true
	label.text = "%s in %d" % [
		_format_goods(periodic),
		maxi(DemandSystem.PERIODIC_PERIOD - settlement.upkeep_timer, 0),
	]


func _format_goods(goods: Dictionary) -> String:
	var parts : Array[String] = []
	for id in goods:
		var res_name : String = Terrain.RESOURCE_NAMES.get(id, str(id))
		parts.append("%d %s" % [int(goods[id]), res_name])
	return ", ".join(parts) if not parts.is_empty() else "–"


# --- Eingabe -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		_cam_mode = CamMode.OVERVIEW if _cam_mode == CamMode.FOLLOW else CamMode.FOLLOW
		return

	if GameState.is_input_blocked():
		return   # Planungs-/KI-Zug-Overlay offen: keine Bau-/Interaktions-Eingaben

	if _carried_def == null:
		if event.is_action_pressed("interact"):
			if _interact_target.has("depot_def"):
				_pick_up(_interact_target["depot_def"])
			elif _interact_target.has("coord"):
				EventBus.building_selected.emit(_interact_target["coord"])
			elif _interact_target.has("vertex"):
				EventBus.settlement_selected.emit(_interact_target["vertex"])
		return

	if event.is_action_pressed("ui_cancel"):
		_cancel_carry()
		return

	if event.is_action_pressed("interact"):
		if _interact_target.has("coord"):
			if GameState.place_building(_interact_target["coord"], _carried_def):
				_finish_carry()
		elif _interact_target.has("vertex"):
			if GameState.place_settlement(_interact_target["vertex"], _carried_def):
				_finish_carry()


## Nimmt ein Bauteil vom Depot auf und macht es sichtbar getragen.
func _pick_up(def: BuildingDef) -> void:
	_carried_def = def
	EventBus.carried_building_changed.emit(_carried_def)
	_attach_carry_visual(def)


## Bricht das Tragen ab und legt das Bauteil zurück ins Depot (kostenlos, da nie abgebucht).
func _cancel_carry() -> void:
	_carried_def = null
	EventBus.carried_building_changed.emit(null)
	_detach_carry_visual()
	_remove_ghost()


## Bauteil wurde erfolgreich platziert (Kosten bereits in place_building/place_settlement abgezogen).
func _finish_carry() -> void:
	_carried_def = null
	EventBus.carried_building_changed.emit(null)
	_detach_carry_visual()
	_remove_ghost()


func _remove_ghost() -> void:
	if _ghost_node != null:
		_ghost_node.queue_free()
		_ghost_node = null
	_interact_indicator.visible = false


## Hängt ein simples Platzhalter-Visual des getragenen Bauteils an den
## Carry-Slot des Spielermodells.
func _attach_carry_visual(def: BuildingDef) -> void:
	_detach_carry_visual()
	var visual := Node3D.new()
	visual.name = "CarryVisual"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.25, 0.25)
	mesh.mesh = box
	mesh.material_override = _mat(Color(0.85, 0.7, 0.25))
	visual.add_child(mesh)
	var label := Label3D.new()
	label.text = def.display_name
	label.font_size = 36
	label.pixel_size = 0.0035
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 0.3, 0.0)
	visual.add_child(label)
	player.carry_slot.add_child(visual)


func _detach_carry_visual() -> void:
	for child in player.carry_slot.get_children():
		child.queue_free()


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

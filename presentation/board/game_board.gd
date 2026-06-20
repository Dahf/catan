extends Node3D
## Zeigt das Catan-Brett in 3D und übersetzt Spieler-Eingaben (begehbare Figur +
## Taste E) in Bau-Commands an den Core. Steuert außerdem die isometrische Kamera.
##
## Die begehbare Figur repräsentiert im Hot-Seat stets den aktuellen Spieler.
## Bautyp je nach Phase: SETUP erzwingt Siedlung→Straße, ROBBER_MOVE den Räuber,
## in BUILD wählt der Spieler aus der Bau-Palette (Depot) Straße/Siedlung/Stadt.

@onready var hex_map: HexBoard3D = $HexBoard
@onready var camera: Camera3D = $Camera3D
@onready var light: DirectionalLight3D = $DirectionalLight3D

const PLAYER_SCENE := preload("res://presentation/player/player.tscn")

enum CamMode { FOLLOW, OVERVIEW }
enum BuildKind { NONE, ROAD, SETTLEMENT, CITY, ROBBER }

const ISO_PITCH := -45.0
const ISO_YAW := 45.0
const FOLLOW_SIZE := 16.0
const FOLLOW_BACK := 24.0
const INTERACTION_RANGE := 3.0

const DEPOT_SPACING := 2.8
const HEX_EDGE_PAD := 1.2
const TABLE_PAD := 14.0
const TABLE_THICKNESS := 0.6
const LEG_HEIGHT := 9.0
const LEG_SIZE := 1.8
const LEG_INSET := LEG_SIZE / 2.0
const TABLE_UV_TILE := 2.0
const TABLE_COLOR := Color(0.42, 0.27, 0.16)
const DEPOT_BASE_COLOR := Color(0.85, 0.7, 0.25)

const DEPOT_KINDS := [BuildKind.ROAD, BuildKind.SETTLEMENT, BuildKind.CITY]
const KIND_NAMES := {
	BuildKind.ROAD: "Straße",
	BuildKind.SETTLEMENT: "Siedlung",
	BuildKind.CITY: "Stadt",
}

var _hex := HexGrid.new()
var _carried_kind: int = BuildKind.NONE   # in BUILD getragener Bautyp aus dem Depot
var _buildings_node: Node3D                # Siedlungen/Städte
var _roads_node: Node3D                     # Straßen
var _tokens: Node3D
var _walls_node: Node3D
var _depot_node: Node3D
var _settlement_nodes: Dictionary = {}      # Vector3i -> Node3D
var _characters_node: Node3D                # begehbare Figuren (eine pro Spieler)
var _characters: Dictionary = {}            # slot(int) -> CharacterBody3D
var _robber_pawn: Node3D = null
var _interact_indicator: Label3D
var _ghost_node: Node3D = null
var _ghost_mat_valid: StandardMaterial3D
var _ghost_mat_invalid: StandardMaterial3D
var _interact_target: Dictionary = {}       # {"depot_kind"|"vertex"|"edge"|"tile": ...}
var _cam_mode: CamMode = CamMode.FOLLOW
var _overview_center := Vector3.ZERO
var _overview_size := 24.0
var _bounds_min := Vector3.ZERO
var _bounds_max := Vector3.ZERO


func _ready() -> void:
	_buildings_node = _new_child("Buildings")
	_roads_node = _new_child("Roads")
	_tokens = _new_child("Tokens")
	_walls_node = _new_child("Walls")
	_depot_node = _new_child("Depot")
	_characters_node = _new_child("Characters")

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
	EventBus.road_placed.connect(_on_road_placed)
	EventBus.city_upgraded.connect(_on_city_upgraded)
	EventBus.robber_moved.connect(_on_robber_moved)
	# Reconnect: geänderte peer_id eines Slots → Figuren-Autorität aktualisieren.
	Net.roster_changed.connect(_refresh_character_authorities)


func _new_child(node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	add_child(n)
	return n


## Baut die komplette 3D-Darstellung aus dem aktuellen GameState neu auf.
func build_from_state() -> void:
	hex_map.clear_board()
	for node in [_tokens, _buildings_node, _roads_node, _walls_node, _depot_node, _characters_node]:
		for child in node.get_children():
			child.queue_free()
	_settlement_nodes.clear()
	_characters.clear()

	for coord in GameState.tiles:
		var tile: Tile = GameState.tiles[coord]
		hex_map.set_terrain(coord, tile.terrain)
		if tile.number_token > 0:
			_add_token(coord, tile.number_token)

	_compute_bounds()
	_build_table()
	_spawn_characters()
	_build_depot()
	_build_robber()

	# Bereits platzierte Strukturen (z.B. nach Snapshot/Laden) nachzeichnen.
	for vertex in GameState.settlements:
		var s: Settlement = GameState.settlements[vertex]
		_render_settlement(vertex, s.owner_id, s.level)
	for p in GameState.players:
		for edge in p.roads:
			var road := _make_road(_player_color(p.id))
			road.global_transform = _edge_xform(edge)
			_roads_node.add_child(road)


func refresh() -> void:
	build_from_state()


func _process(_delta: float) -> void:
	_update_camera()
	_update_interact_target()


# --- Bau-Modus / Ziel-Erkennung ------------------------------------------------

## Welcher Bautyp ist im aktuellen Phasen-Kontext aktiv?
func _current_build_kind() -> int:
	if GameState.turn_phase == GameState.TurnPhase.SETUP:
		return BuildKind.ROAD if GameState.setup_expect_road else BuildKind.SETTLEMENT
	if GameState.turn_phase == GameState.TurnPhase.ROBBER_MOVE:
		return BuildKind.ROBBER
	if GameState.turn_phase == GameState.TurnPhase.BUILD:
		return _carried_kind
	return BuildKind.NONE


func _build_interaction_allowed() -> bool:
	# Bauen/Räuber nur für den lokal gesteuerten Spieler und nur in seinem Zug.
	if _controlled_slot() != GameState.current_player_index:
		return false
	return GameState.turn_phase in [
		GameState.TurnPhase.SETUP,
		GameState.TurnPhase.BUILD,
		GameState.TurnPhase.ROBBER_MOVE,
	]


func _update_interact_target() -> void:
	if not _build_interaction_allowed():
		_interact_target = {}
		_hide_ghost_and_indicator()
		return
	var kind := _current_build_kind()
	if kind == BuildKind.NONE:
		_update_depot_target()
	else:
		_update_build_target(kind)


## In BUILD ohne getragenen Typ: nächsten Depot-Punkt in Reichweite anvisieren.
func _update_depot_target() -> void:
	var lc := _local_character()
	if lc == null:
		_clear_build_target()
		return
	var best: Node3D = null
	var best_d := INTERACTION_RANGE
	for body in _depot_node.get_children():
		var d := lc.global_position.distance_to(body.global_position)
		if d <= best_d:
			best_d = d
			best = body
	if best == null:
		_interact_target = {}
		_hide_ghost_and_indicator()
		return
	_interact_target = {"depot_kind": best.get_meta(&"build_kind")}
	_hide_ghost()
	_interact_indicator.modulate = Color(1.0, 0.85, 0.2)
	_interact_indicator.visible = true
	_interact_indicator.global_position = best.global_position + Vector3(0.0, 1.4, 0.0)


## Bautyp aktiv: Ziel (Vertex/Kante/Tile) bestimmen und Ghost-Vorschau zeigen.
func _update_build_target(kind: int) -> void:
	var lc := _local_character()
	if lc == null:
		_clear_build_target()
		return
	var pos := lc.global_position
	var p := GameState.current_player()
	if kind == BuildKind.SETTLEMENT or kind == BuildKind.CITY:
		var v := _nearest_vertex(pos)
		var vp := _vertex_world(v)
		if pos.distance_to(vp) > INTERACTION_RANGE:
			_clear_build_target()
			return
		_interact_target = {"vertex": v}
		if kind == BuildKind.CITY:
			_show_ghost(_make_ghost_city(), _xform(vp), GameState.can_upgrade_city(v, p))
		else:
			_show_ghost(_make_ghost_settlement(), _xform(vp), GameState.can_place_settlement(v, p))
	elif kind == BuildKind.ROAD:
		var edge := _nearest_edge(pos)
		var mid := _edge_midpoint(edge)
		if pos.distance_to(mid) > INTERACTION_RANGE:
			_clear_build_target()
			return
		_interact_target = {"edge": edge}
		_show_ghost(_make_ghost_road(), _edge_xform(edge), GameState.can_place_road(edge, p))
	elif kind == BuildKind.ROBBER:
		var coord := hex_map.world_to_hex(pos)
		var cp := hex_map.hex_to_world(coord)
		if not GameState.tiles.has(coord) or pos.distance_to(cp) > INTERACTION_RANGE:
			_clear_build_target()
			return
		_interact_target = {"tile": coord}
		_show_ghost(_make_ghost_robber(), _xform(cp + Vector3(0.0, 0.2, 0.0)), coord != GameState.robber_tile)


func _clear_build_target() -> void:
	_interact_target = {}
	_hide_ghost_and_indicator()


# --- Eingabe -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		_cam_mode = CamMode.OVERVIEW if _cam_mode == CamMode.FOLLOW else CamMode.FOLLOW
		return

	if GameState.is_input_blocked() or not _build_interaction_allowed():
		return

	if event.is_action_pressed("ui_cancel") and _carried_kind != BuildKind.NONE:
		_carried_kind = BuildKind.NONE
		_detach_carry_visual()
		return

	if not event.is_action_pressed("interact"):
		return

	if _interact_target.has("depot_kind"):
		_carried_kind = _interact_target["depot_kind"]
		_attach_carry_visual(_carried_kind)
		return

	if _interact_target.has("vertex"):
		var v: Vector3i = _interact_target["vertex"]
		var kind := _current_build_kind()
		if kind == BuildKind.CITY:
			if Net.request_upgrade_city(v):
				_after_place()
		elif Net.request_place_settlement(v):
			_after_place()
	elif _interact_target.has("edge"):
		if Net.request_place_road(_interact_target["edge"]):
			_after_place()
	elif _interact_target.has("tile"):
		Net.request_robber_tile(_interact_target["tile"])


## Nach erfolgreicher Platzierung: in BUILD den getragenen Typ ablegen.
func _after_place() -> void:
	if GameState.turn_phase == GameState.TurnPhase.BUILD:
		_carried_kind = BuildKind.NONE
		_detach_carry_visual()
	_hide_ghost_and_indicator()


# --- Ghost-Vorschau ------------------------------------------------------------

func _show_ghost(ghost: Node3D, xform: Transform3D, valid: bool) -> void:
	if _ghost_node != null:
		_ghost_node.queue_free()
	_ghost_node = ghost
	add_child(_ghost_node)
	_ghost_node.global_transform = xform
	_set_ghost_valid(valid)
	_interact_indicator.global_position = xform.origin + Vector3(0.0, 0.9, 0.0)
	_interact_indicator.modulate = Color.LIME_GREEN if valid else Color.ORANGE_RED
	_interact_indicator.visible = true


func _set_ghost_valid(valid: bool) -> void:
	var mat := _ghost_mat_valid if valid else _ghost_mat_invalid
	for child in _ghost_node.get_children():
		if child is MeshInstance3D:
			child.material_override = mat


func _hide_ghost() -> void:
	if _ghost_node != null:
		_ghost_node.queue_free()
		_ghost_node = null


func _hide_ghost_and_indicator() -> void:
	_hide_ghost()
	_interact_indicator.visible = false


func _xform(world_pos: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, world_pos)


# --- Carry-Visual am Spieler ---------------------------------------------------

func _attach_carry_visual(kind: int) -> void:
	_detach_carry_visual()
	var visual := Node3D.new()
	visual.name = "CarryVisual"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.25, 0.25)
	mesh.mesh = box
	mesh.material_override = _mat(GameState.current_player().color)
	visual.add_child(mesh)
	var label := Label3D.new()
	label.text = KIND_NAMES.get(kind, "?")
	label.font_size = 36
	label.pixel_size = 0.0035
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 0.3, 0.0)
	visual.add_child(label)
	var lc := _local_character()
	if lc != null:
		lc.carry_slot.add_child(visual)


func _detach_carry_visual() -> void:
	var lc := _local_character()
	if lc == null:
		return
	for child in lc.carry_slot.get_children():
		child.queue_free()


# --- Event-Handler -------------------------------------------------------------

func _on_settlement_placed(vertex: Vector3i, owner_id: int) -> void:
	_render_settlement(vertex, owner_id, 1)


func _on_city_upgraded(vertex: Vector3i, owner_id: int) -> void:
	_render_settlement(vertex, owner_id, 2)


func _on_road_placed(edge, owner_id: int) -> void:
	var road := _make_road(_player_color(owner_id))
	road.global_transform = _edge_xform(edge)
	_roads_node.add_child(road)


func _on_robber_moved(tile: Vector2i) -> void:
	if _robber_pawn != null:
		_robber_pawn.global_position = hex_map.hex_to_world(tile) + Vector3(0.0, 0.3, 0.0)


func _render_settlement(vertex: Vector3i, owner_id: int, level: int) -> void:
	if _settlement_nodes.has(vertex):
		_settlement_nodes[vertex].queue_free()
	var node := _make_city(_player_color(owner_id)) if level == 2 else _make_settlement(_player_color(owner_id))
	node.position = _vertex_world(vertex)
	node.set_meta(&"vertex", vertex)
	_buildings_node.add_child(node)
	_settlement_nodes[vertex] = node


func _player_color(owner_id: int) -> Color:
	if owner_id >= 0 and owner_id < GameState.players.size():
		return GameState.players[owner_id].color
	return Color.WHITE


# --- Kamera / Bounds / Tisch ---------------------------------------------------

func _update_camera() -> void:
	var back := camera.global_transform.basis.z
	var lc := _local_character()
	if _cam_mode == CamMode.FOLLOW and lc != null:
		camera.size = FOLLOW_SIZE
		camera.global_position = lc.global_position + back * FOLLOW_BACK
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


func _build_table() -> void:
	if GameState.tiles.is_empty():
		return
	var pad := HEX_EDGE_PAD + TABLE_PAD
	var mn := _bounds_min - Vector3(pad, 0.0, pad)
	var mx := _bounds_max + Vector3(pad, 0.0, pad)
	_build_table_surface(mn, mx)
	_build_table_legs(mn, mx)
	_build_perimeter(mn, mx)


func _table_top_y() -> float:
	return -(HexBoard3D.HEIGHT + 0.02)


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


# --- Begehbare Figuren (eine pro Spieler) --------------------------------------

## Welchen Slot steuert dieser Client lokal? Online: eigener Roster-Slot.
## Offline (Hotseat): der aktuell am Zug befindliche Spieler.
func _controlled_slot() -> int:
	return Net.local_slot if Net.is_online() else GameState.current_player_index


## Die lokal gesteuerte Figur (oder null, falls noch nicht gespawnt).
func _local_character() -> CharacterBody3D:
	return _characters.get(_controlled_slot())


## Spawnt eine Figur pro Spieler — auf jedem Peer identisch (gleiche Namen/Reihen-
## folge), damit die MultiplayerSynchronizer-Pfade übereinstimmen.
func _spawn_characters() -> void:
	if GameState.tiles.is_empty():
		return
	var n := GameState.players.size()
	for slot in n:
		var ch: CharacterBody3D = PLAYER_SCENE.instantiate()
		ch.name = "Player_%d" % slot
		ch.slot = slot
		_characters_node.add_child(ch)
		var ang := TAU * float(slot) / float(maxi(n, 1))
		var offset := Vector3(cos(ang), 0.0, sin(ang)) * 2.0
		ch.global_position = _overview_center + Vector3(0.0, 2.0, 0.0) + offset
		ch.velocity = Vector3.ZERO
		_tint_character(ch, _player_color(slot))
		if Net.is_online():
			ch.set_multiplayer_authority(Net.peer_of_slot(slot))
			_add_character_sync(ch)
		_characters[slot] = ch


## Färbt die Platzhalter-Kapsel in der Spielerfarbe ein.
func _tint_character(ch: Node, color: Color) -> void:
	var placeholder := ch.get_node_or_null("Model/Placeholder")
	if placeholder is MeshInstance3D:
		placeholder.material_override = _mat(color)


## Aktualisiert die Multiplayer-Autorität der Figuren anhand des aktuellen Rosters
## (z.B. nach Reconnect, wenn ein Slot eine neue peer_id bekommt).
func _refresh_character_authorities() -> void:
	if not Net.is_online():
		return
	for slot in _characters:
		var peer := Net.peer_of_slot(slot)
		if peer == -1:
			continue
		var ch: Node = _characters[slot]
		ch.set_multiplayer_authority(peer)
		for c in ch.get_children():
			if c is MultiplayerSynchronizer:
				c.set_multiplayer_authority(peer)


## Hängt einen MultiplayerSynchronizer an (Position + Rotation), Autorität = Besitzer.
func _add_character_sync(ch: Node) -> void:
	var cfg := SceneReplicationConfig.new()
	for prop in [NodePath(".:position"), NodePath(".:rotation")]:
		cfg.add_property(prop)
		cfg.property_set_replication_mode(prop, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.replication_config = cfg
	sync.set_multiplayer_authority(ch.get_multiplayer_authority())
	ch.add_child(sync)


# --- Depot (Bau-Palette) -------------------------------------------------------

func _build_depot() -> void:
	if GameState.tiles.is_empty():
		return
	var start_x := _overview_center.x - (DEPOT_KINDS.size() - 1) * DEPOT_SPACING * 0.5
	var z := _bounds_max.z + HEX_EDGE_PAD + 1.0
	for i in DEPOT_KINDS.size():
		var kind: int = DEPOT_KINDS[i]
		var point := _make_depot_point(kind)
		point.position = Vector3(start_x + i * DEPOT_SPACING, _table_top_y(), z)
		point.set_meta(&"build_kind", kind)
		_depot_node.add_child(point)


func _make_depot_point(kind: int) -> Node3D:
	var root := Node3D.new()
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.35, 1.0)
	base.mesh = box
	base.material_override = _mat(DEPOT_BASE_COLOR)
	base.position = Vector3(0.0, 0.175, 0.0)
	root.add_child(base)

	var model: Node3D
	match kind:
		BuildKind.ROAD:
			model = _make_road(Color(0.85, 0.85, 0.85))
		BuildKind.CITY:
			model = _make_city(Color(0.9, 0.9, 0.9))
		_:
			model = _make_settlement(Color(0.9, 0.9, 0.9))
	model.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(model)

	var label := Label3D.new()
	label.text = KIND_NAMES.get(kind, "?")
	label.font_size = 110
	label.pixel_size = 0.008
	label.outline_size = 18
	label.modulate = DEPOT_BASE_COLOR
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 1.5, 0.0)
	root.add_child(label)
	return root


# --- Räuber --------------------------------------------------------------------

func _build_robber() -> void:
	_robber_pawn = _make_robber()
	_robber_pawn.global_transform = _xform(hex_map.hex_to_world(GameState.robber_tile) + Vector3(0.0, 0.3, 0.0))
	_buildings_node.add_child(_robber_pawn)


func _make_robber() -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 0.6
	mesh.mesh = cone
	mesh.material_override = _mat(Color(0.12, 0.12, 0.14))
	mesh.position = Vector3(0.0, 0.3, 0.0)
	root.add_child(mesh)
	return root


# --- Marker / Meshes -----------------------------------------------------------

func _add_token(coord: Vector2i, value: int) -> void:
	var label := Label3D.new()
	label.text = str(value)
	label.font_size = 96
	label.pixel_size = 0.008
	label.modulate = Color.BLACK if value != 6 and value != 8 else Color(0.7, 0.1, 0.1)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.position = hex_map.hex_to_world(coord) + Vector3(0.0, 0.03, 0.0)
	_tokens.add_child(label)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


func _building_body(footprint: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = footprint
	col.shape = shape
	col.position = Vector3(0.0, footprint.y / 2.0, 0.0)
	body.add_child(col)
	return body


func _ghost_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Siedlung (VERTEX): kleines Haus mit Spitzdach, eingefärbt nach Besitzer.
func _make_settlement(color: Color) -> Node3D:
	var root := Node3D.new()
	var walls := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.28, 0.3)
	walls.mesh = box
	walls.material_override = _mat(color)
	walls.position = Vector3(0.0, 0.14, 0.0)
	root.add_child(walls)
	var roof := MeshInstance3D.new()
	var pyramid := CylinderMesh.new()
	pyramid.top_radius = 0.0
	pyramid.bottom_radius = 0.26
	pyramid.height = 0.22
	pyramid.radial_segments = 4
	roof.mesh = pyramid
	roof.material_override = _mat(color.darkened(0.35))
	roof.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	roof.position = Vector3(0.0, 0.39, 0.0)
	root.add_child(roof)
	return root


## Stadt (VERTEX): größerer Doppelblock, eingefärbt nach Besitzer.
func _make_city(color: Color) -> Node3D:
	var root := Node3D.new()
	var main := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.4, 0.42)
	main.mesh = box
	main.material_override = _mat(color)
	main.position = Vector3(0.0, 0.2, 0.0)
	root.add_child(main)
	var tower := MeshInstance3D.new()
	var tbox := BoxMesh.new()
	tbox.size = Vector3(0.22, 0.34, 0.22)
	tower.mesh = tbox
	tower.material_override = _mat(color.lightened(0.15))
	tower.position = Vector3(0.14, 0.55, 0.14)
	root.add_child(tower)
	return root


## Straße (EDGE): liegender Balken, eingefärbt nach Besitzer. Wird per
## _edge_xform entlang der Kante ausgerichtet.
func _make_road(color: Color) -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.1, 0.9)   # lang entlang lokaler -Z (Blickrichtung)
	mesh.mesh = box
	mesh.material_override = _mat(color)
	mesh.position = Vector3(0.0, 0.05, 0.0)
	root.add_child(mesh)
	return root


func _make_ghost_settlement() -> Node3D:
	return _make_settlement(Color.WHITE)


func _make_ghost_city() -> Node3D:
	return _make_city(Color.WHITE)


func _make_ghost_road() -> Node3D:
	return _make_road(Color.WHITE)


func _make_ghost_robber() -> Node3D:
	return _make_robber()


# --- Vertex-/Kanten-Geometrie --------------------------------------------------

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


## Nächste Kante zur Position: inzidente Kanten der nächsten Ecke, beste nach
## Abstand des Welt-Mittelpunkts.
func _nearest_edge(world: Vector3) -> Array:
	var v0 := _nearest_vertex(world)
	var best = null
	var best_d := INF
	for edge in _hex.incident_edges(v0):
		var d := _edge_midpoint(edge).distance_squared_to(world)
		if d < best_d:
			best_d = d
			best = edge
	if best == null:
		return _hex.make_edge(v0, v0)
	return best


func _edge_midpoint(edge) -> Vector3:
	return (_vertex_world(edge[0]) + _vertex_world(edge[1])) * 0.5


## Transform einer Straße/Ghost entlang der Kante (lokale -Z zeigt zum 2. Endpunkt).
func _edge_xform(edge) -> Transform3D:
	var a := _vertex_world(edge[0])
	var b := _vertex_world(edge[1])
	var mid := (a + b) * 0.5
	var t := Transform3D(Basis.IDENTITY, mid)
	if a.distance_to(b) > 0.001:
		t = t.looking_at(b, Vector3.UP)
	return t

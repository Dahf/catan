class_name HexBoard3D
extends Node3D
## Rendert das Hex-Brett in echtem 3D (Hex-Prismen mit Kollision) und übersetzt
## zwischen axialen Hex-Koordinaten und 3D-Weltkoordinaten (XZ-Ebene, y = Höhe).
## Presentation-Schicht — liest aus dem Core, enthält keine Spiellogik.
## Ersetzt den früheren 2D-TileMapLayer (hex_tile_map.gd).

const SIZE := 1.0          # Circumradius eines Hex (Mitte -> Ecke) in Welt-Einheiten
const HEIGHT := 0.25       # Dicke des Prismas; Oberkante liegt auf y = 0
const SQRT3 := 1.7320508075688772

# pointy-top: eine Ecke zeigt nach oben/unten (Norden/Süden), flache Kanten links/rechts.

const TERRAIN_COLORS := {
	Terrain.TerrainType.FOREST: Color("1f6b2e"),     # dunkelgrün
	Terrain.TerrainType.HILLS: Color("b5651d"),      # lehmbraun
	Terrain.TerrainType.MOUNTAINS: Color("7d7d7d"),  # grau
	Terrain.TerrainType.FIELDS: Color("e3c044"),     # goldgelb
	Terrain.TerrainType.PASTURE: Color("8ec64a"),    # hellgrün
	Terrain.TerrainType.DESERT: Color("d9c08a"),     # sandbeige
	Terrain.TerrainType.WATER: Color("2f6fb0"),      # blau
}


## Axiale Hex-Koordinate -> 3D-Weltposition (Mittelpunkt der Oberfläche, y = 0).
func hex_to_world(coord: Vector2i) -> Vector3:
	var x := SIZE * SQRT3 * (coord.x + coord.y / 2.0)
	var z := SIZE * 1.5 * coord.y
	return Vector3(x, 0.0, z)


## 3D-Weltposition (XZ) -> axiale Hex-Koordinate.
func world_to_hex(pos: Vector3) -> Vector2i:
	var q := (SQRT3 / 3.0 * pos.x - 1.0 / 3.0 * pos.z) / SIZE
	var r := (2.0 / 3.0 * pos.z) / SIZE
	return _axial_round(q, r)


## Setzt (erzeugt) das dargestellte Terrain einer Zelle als Hex-Prisma mit Kollision.
func set_terrain(coord: Vector2i, terrain: Terrain.TerrainType) -> void:
	var body := StaticBody3D.new()
	body.position = hex_to_world(coord)

	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = SIZE
	cyl.bottom_radius = SIZE
	cyl.height = HEIGHT
	cyl.radial_segments = 6
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TERRAIN_COLORS.get(terrain, Color.MAGENTA)
	mesh.material_override = mat
	mesh.rotation_degrees = Vector3(0, 0, 0)         # CylinderMesh (6 Seg.) ist bereits pointy-top
	mesh.position = Vector3(0, -HEIGHT / 2.0, 0)     # Oberkante auf y = 0
	body.add_child(mesh)

	# Kollisions-/Begehbarkeit: leicht überlappende Box füllt Lücken an den Ecken.
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE * 1.9, HEIGHT, SIZE * 1.9)
	col.shape = box
	col.position = Vector3(0, -HEIGHT / 2.0, 0)
	body.add_child(col)

	add_child(body)


## Entfernt alle Tiles.
func clear_board() -> void:
	for child in get_children():
		child.queue_free()


# --- Interne Helfer ------------------------------------------------------------

## Rundet gebrochene axiale Koordinaten auf das nächste gültige Hex.
func _axial_round(q: float, r: float) -> Vector2i:
	var x := q
	var z := r
	var y := -x - z
	var rx := roundi(x)
	var ry := roundi(y)
	var rz := roundi(z)
	var dx := absf(rx - x)
	var dy := absf(ry - y)
	var dz := absf(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(rx, rz)

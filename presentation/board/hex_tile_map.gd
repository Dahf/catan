extends TileMapLayer
## Rendert die Hex-Tiles und übersetzt zwischen axialen Hex- und Pixel-/Map-Koordinaten.
## Presentation-Schicht — liest aus dem Core, enthält keine Spiellogik.
##
## Das TileSet wird zur Laufzeit erzeugt: ein einfarbiges pointy-top Hex-Tile pro
## TerrainType (Platzhalter, später durch echte Grafiken ersetzbar).

# Bounding-Box eines Tiles in Pixeln. Verhältnis ~sqrt(3)/2 für ein regelmäßiges
# pointy-top Sechseck (Breite ≈ 0.866 * Höhe).
const TILE_SIZE := Vector2i(59, 68)

# Platzhalter-Farbe pro Terrain. Index = Terrain.TerrainType-Wert.
const TERRAIN_COLORS := {
	Terrain.TerrainType.FOREST: Color("1f6b2e"),     # dunkelgrün
	Terrain.TerrainType.HILLS: Color("b5651d"),      # lehmbraun
	Terrain.TerrainType.MOUNTAINS: Color("7d7d7d"),  # grau
	Terrain.TerrainType.FIELDS: Color("e3c044"),     # goldgelb
	Terrain.TerrainType.PASTURE: Color("8ec64a"),    # hellgrün
	Terrain.TerrainType.DESERT: Color("d9c08a"),     # sandbeige
	Terrain.TerrainType.WATER: Color("2f6fb0"),      # blau
}

const _SOURCE_ID := 0


func _ready() -> void:
	tile_set = _build_tile_set()


## Axiale Hex-Koordinate -> TileMap-Zelle (odd-r Offset).
func hex_to_map(coord: Vector2i) -> Vector2i:
	var col := coord.x + (coord.y - (coord.y & 1)) / 2
	return Vector2i(col, coord.y)


## TileMap-Zelle -> axiale Hex-Koordinate.
func map_to_hex(cell: Vector2i) -> Vector2i:
	var q := cell.x - (cell.y - (cell.y & 1)) / 2
	return Vector2i(q, cell.y)


## Axiale Hex-Koordinate -> lokale Pixelposition (Mittelpunkt).
func hex_to_world(coord: Vector2i) -> Vector2:
	return map_to_local(hex_to_map(coord))


## Lokale Pixelposition -> axiale Hex-Koordinate.
func world_to_hex(pos: Vector2) -> Vector2i:
	return map_to_hex(local_to_map(pos))


## Setzt das dargestellte Terrain einer Zelle.
func set_terrain(coord: Vector2i, terrain: Terrain.TerrainType) -> void:
	set_cell(hex_to_map(coord), _SOURCE_ID, Vector2i(int(terrain), 0))


## Leert das Brett.
func clear_board() -> void:
	clear()


# --- TileSet-Aufbau ------------------------------------------------------------

## Baut ein TileSet mit einem pointy-top Hex-Tile pro TerrainType.
func _build_tile_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	ts.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL  # pointy-top
	ts.tile_size = TILE_SIZE

	var count := Terrain.TerrainType.size()
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(_build_atlas_image(count))
	src.texture_region_size = TILE_SIZE
	for i in range(count):
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, _SOURCE_ID)
	return ts


## Erzeugt ein Atlas-Image: pro Terrain ein gefülltes Sechseck nebeneinander.
func _build_atlas_image(count: int) -> Image:
	var img := Image.create(TILE_SIZE.x * count, TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hex := _hex_polygon()
	for i in range(count):
		var color: Color = TERRAIN_COLORS.get(i, Color.MAGENTA)
		var origin := Vector2(TILE_SIZE.x * i, 0)
		for y in range(TILE_SIZE.y):
			for x in range(TILE_SIZE.x):
				if Geometry2D.is_point_in_polygon(Vector2(x, y), hex):
					img.set_pixel(int(origin.x) + x, y, color)
	return img


## Eckpunkte eines pointy-top Sechsecks innerhalb der Bounding-Box TILE_SIZE.
func _hex_polygon() -> PackedVector2Array:
	var w := float(TILE_SIZE.x)
	var h := float(TILE_SIZE.y)
	var cx := w / 2.0
	var cy := h / 2.0
	return PackedVector2Array([
		Vector2(cx, cy - h / 2.0),          # oben
		Vector2(cx + w / 2.0, cy - h / 4.0),  # oben rechts
		Vector2(cx + w / 2.0, cy + h / 4.0),  # unten rechts
		Vector2(cx, cy + h / 2.0),          # unten
		Vector2(cx - w / 2.0, cy + h / 4.0),  # unten links
		Vector2(cx - w / 2.0, cy - h / 4.0),  # oben links
	])

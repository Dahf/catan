extends TileMapLayer
## Rendert die Hex-Tiles und übersetzt zwischen axialen Hex- und Pixel-/Map-Koordinaten.
## Presentation-Schicht — liest aus dem Core, enthält keine Spiellogik.

## Axiale Hex-Koordinate -> TileMap-Zelle.
func hex_to_map(coord: Vector2i) -> Vector2i:
	# TODO
	return Vector2i.ZERO


## TileMap-Zelle -> axiale Hex-Koordinate.
func map_to_hex(cell: Vector2i) -> Vector2i:
	# TODO
	return Vector2i.ZERO


## Axiale Hex-Koordinate -> Welt-Pixelposition (Mittelpunkt).
func hex_to_world(coord: Vector2i) -> Vector2:
	# TODO
	return Vector2.ZERO


## Welt-Pixelposition -> axiale Hex-Koordinate.
func world_to_hex(pos: Vector2) -> Vector2i:
	# TODO
	return Vector2i.ZERO


## Setzt das dargestellte Terrain einer Zelle.
func set_terrain(coord: Vector2i, terrain: Terrain.TerrainType) -> void:
	# TODO
	pass

class_name HexGrid
extends RefCounted
## Reine Hex-Mathematik auf axialen Koordinaten (q, r als Vector2i).
## Keine Rendering-/Pixel-Logik (die lebt in der Presentation).
## Vertices/Kanten für das Hybrid-Modell (Siedlungen auf Ecken, Straßen auf Kanten).

# Die 6 Nachbar-Richtungen in axialen Koordinaten (selbst zu befüllen)
const DIRECTIONS: Array[Vector2i] = []


## Liefert die (bis zu 6) Nachbar-Tiles einer Koordinate.
func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	# TODO
	return []


## Hex-Distanz zwischen zwei Tiles.
func distance(a: Vector2i, b: Vector2i) -> int:
	# TODO
	return 0


## Alle Tiles innerhalb eines Radius um ein Zentrum.
func get_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	# TODO
	return []


## Tiles auf einer geraden Linie zwischen a und b.
func get_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	# TODO
	return []


# --- Vertices / Kanten (Hybrid-Modell) ---

## Die 6 Ecken (Vertices) eines Tiles.
func get_vertices(coord: Vector2i) -> Array[Vector3i]:
	# TODO
	return []


## Die 6 Kanten (Edges) eines Tiles.
func get_edges(coord: Vector2i) -> Array:
	# TODO
	return []


## Die (bis zu 3) Tiles, die an eine Ecke/Vertex angrenzen.
func vertex_adjacent_tiles(vertex: Vector3i) -> Array[Vector2i]:
	# TODO
	return []


## Die (bis zu 3) benachbarten Vertices einer Ecke (für Straßen/Abstandsregeln).
func adjacent_vertices(vertex: Vector3i) -> Array[Vector3i]:
	# TODO
	return []


## Die beiden Endpunkt-Vertices einer Kante.
func edge_endpoints(edge) -> Array[Vector3i]:
	# TODO
	return []

class_name HexGrid
extends RefCounted
## Reine Hex-Mathematik auf axialen Koordinaten (q, r als Vector2i).
## Keine Rendering-/Pixel-Logik (die lebt in der Presentation).
## Vertices/Kanten für das Hybrid-Modell (Siedlungen auf Ecken, Straßen auf Kanten).

# Die 6 Nachbar-Richtungen in axialen Koordinaten (selbst zu befüllen)
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1,0), #East
	Vector2i(0,1), #SouthEast
	Vector2i(-1,1), #SouthWest
	Vector2i(-1,0), #West
	Vector2i(-1,-1), #NorthWest
	Vector2i(0,-1) #NorthEast
]


## Liefert die (bis zu 6) Nachbar-Tiles einer Koordinate.
func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	# TODO
	var result: Array[Vector2i] = []
	for i in DIRECTIONS:
		result.append(coord + i)
	return result


## Hex-Distanz zwischen zwei Tiles.
func distance(a: Vector2i, b: Vector2i) -> int:
	# TODO
	var dq := a.x-b.x
	var dr := a.y-b.y
	return (abs(dq)+abs(dq+dr)+abs(dr))/2


## Alle Tiles innerhalb eines Radius um ein Zentrum.
func get_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	# TODO
	var result : Array[Vector2i] = []
	for i in range(-radius, radius + 1):
		for j in range(-radius, radius + 1):
			var scan : Vector2i = Vector2i(i, j)
			if distance(center, scan) <= radius:
				result.append(scan)
	
	return result


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

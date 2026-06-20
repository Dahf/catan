class_name HexGrid
extends RefCounted
## Reine Hex-Mathematik auf axialen Koordinaten (q, r als Vector2i).
## Keine Rendering-/Pixel-Logik (die lebt in der Presentation).
##
## Koordinatensysteme in dieser Datei:
##   - TILE  : axial (q, r) als Vector2i  -> ein Sechseck
##   - CUBE  : (x, y, z) als Vector3i mit x+y+z=0 -> nur intern für Mathematik
##   - VERTEX: Vector3i = Summe der (bis zu 3) angrenzenden Tiles in Cube-Koords.
##             Dadurch ist jede Ecke EINDEUTIG, egal von welchem Tile aus berechnet.
##   - EDGE  : Array[Vector3i] mit 2 (sortierten) Vertex-Koordinaten -> eine Kante.
##
## Orientierung: "pointy-top" Sechsecke. Richtungen im Uhrzeigersinn ab Osten.

# Die 6 Nachbar-Richtungen in AXIALEN Koordinaten (E, SE, SW, W, NW, NE)
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # E
	Vector2i(0, 1),   # SE
	Vector2i(-1, 1),  # SW
	Vector2i(-1, 0),  # W
	Vector2i(0, -1),  # NW
	Vector2i(1, -1),  # NE
]

# Dieselben Richtungen in CUBE-Koordinaten (für Vertex-/Kanten-Mathematik)
# Reihenfolge muss INDEX-GLEICH zu DIRECTIONS sein.
const CUBE_DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, -1, 0),   # E
	Vector3i(0, -1, 1),   # SE
	Vector3i(-1, 0, 1),   # SW
	Vector3i(-1, 1, 0),   # W
	Vector3i(0, 1, -1),   # NW
	Vector3i(1, 0, -1),   # NE
]

## Liefert die (bis zu 6) Nachbar-Tiles einer Koordinate.
func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRECTIONS:
		result.append(coord + dir)
	return result


## Hex-Distanz zwischen zwei Tiles (Anzahl Schritte).
func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return (abs(dq) + abs(dq + dr) + abs(dr)) / 2


## Alle Tiles innerhalb eines Radius um ein Zentrum (inklusive Zentrum).
func get_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dq in range(-radius, radius + 1):
		var r_min := maxi(-radius, -dq - radius)
		var r_max := mini(radius, -dq + radius)
		for dr in range(r_min, r_max + 1):
			result.append(center + Vector2i(dq, dr))
	return result


## Tiles auf einer geraden Linie zwischen a und b (inklusive beider Enden).
func get_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n := distance(a, b)
	var result: Array[Vector2i] = []
	if n == 0:
		result.append(a)
		return result
	var ac := _axial_to_cube(a)
	var bc := _axial_to_cube(b)
	for i in range(n + 1):
		var t := float(i) / float(n)
		var lerped := Vector3(ac).lerp(Vector3(bc), t)
		result.append(_cube_to_axial(_cube_round(lerped)))
	return result


# --- Vertices / Kanten (Hybrid-Modell) -----------------------------------------

## Die 6 Ecken (Vertices) eines Tiles, im Uhrzeigersinn.
## Eine Ecke = Summe der 3 Tiles, die sie berühren (in Cube-Koords).
func get_vertices(coord: Vector2i) -> Array[Vector3i]:
	var cube := _axial_to_cube(coord)
	var result: Array[Vector3i] = []
	for i in range(6):
		var d1: Vector3i = CUBE_DIRECTIONS[i]
		var d2: Vector3i = CUBE_DIRECTIONS[(i + 1) % 6]
		# cube + (cube+d1) + (cube+d2) = 3*cube + d1 + d2
		result.append(cube * 3 + d1 + d2)
	return result


## Die 6 Kanten (Edges) eines Tiles, jeweils als sortiertes Vertex-Paar.
func get_edges(coord: Vector2i) -> Array:
	var verts := get_vertices(coord)
	var result: Array = []
	for i in range(6):
		result.append(make_edge(verts[i], verts[(i + 1) % 6]))
	return result


## Die (bis zu 3) Kanten, die an einer Ecke/Vertex hängen (zu ihren Nachbar-Ecken).
func incident_edges(vertex: Vector3i) -> Array:
	var result: Array = []
	for v in adjacent_vertices(vertex):
		result.append(make_edge(vertex, v))
	return result


## Die (bis zu 3) Tiles, die an eine Ecke/Vertex angrenzen.
## Wir suchen alle Tiles h mit  3*h + cornerOffset == vertex.
func vertex_adjacent_tiles(vertex: Vector3i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in range(6):
		var offset: Vector3i = CUBE_DIRECTIONS[i] + CUBE_DIRECTIONS[(i + 1) % 6]
		var rest := vertex - offset
		# Nur gültig, wenn rest sauber durch 3 teilbar ist -> dann ist es ein Tile-Zentrum.
		if rest.x % 3 == 0 and rest.y % 3 == 0 and rest.z % 3 == 0:
			var cube := Vector3i(rest.x / 3, rest.y / 3, rest.z / 3)
			var coord := _cube_to_axial(cube)
			if not result.has(coord):
				result.append(coord)
	return result


## Die (bis zu 3) über eine Kante benachbarten Vertices einer Ecke.
## Zwei Ecken sind benachbart, wenn sie sich GENAU 2 Tiles teilen.
func adjacent_vertices(vertex: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var own_tiles := vertex_adjacent_tiles(vertex)
	for tile in own_tiles:
		for v in get_vertices(tile):
			if v == vertex or result.has(v):
				continue
			if _shared_tile_count(vertex, v) == 2:
				result.append(v)
	return result


## Die beiden Endpunkt-Vertices einer Kante.
func edge_endpoints(edge) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for v in edge:
		result.append(v)
	return result


# --- Interne Helfer ------------------------------------------------------------

func _axial_to_cube(coord: Vector2i) -> Vector3i:
	# q = x, r = z, y = -x - z
	return Vector3i(coord.x, -coord.x - coord.y, coord.y)


func _cube_to_axial(cube: Vector3i) -> Vector2i:
	return Vector2i(cube.x, cube.z)


## Rundet gebrochene Cube-Koordinaten auf das nächste gültige Hex (x+y+z=0).
func _cube_round(frac: Vector3) -> Vector3i:
	var rx := roundi(frac.x)
	var ry := roundi(frac.y)
	var rz := roundi(frac.z)
	var dx := absf(rx - frac.x)
	var dy := absf(ry - frac.y)
	var dz := absf(rz - frac.z)
	# Die Komponente mit dem größten Rundungsfehler wird korrigiert.
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector3i(rx, ry, rz)


## Erzeugt eine Kante als sortiertes Vertex-Paar (kanonisch, damit dieselbe
## Kante von zwei Tiles aus identisch ist).
func make_edge(a: Vector3i, b: Vector3i) -> Array:
	if _vertex_less(a, b):
		return [a, b]
	return [b, a]


## Stabiler String-Schlüssel einer Kante (Dictionaries keyen nicht zuverlässig
## auf Array[Vector3i]). Kanonisiert vorab über make_edge.
func edge_key(edge) -> String:
	var e := make_edge(edge[0], edge[1])
	return "%s|%s" % [e[0], e[1]]


## Lexikografischer Vergleich zweier Vertex-Koordinaten.
func _vertex_less(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z


## Zählt, wie viele Tiles sich zwei Vertices teilen.
func _shared_tile_count(a: Vector3i, b: Vector3i) -> int:
	var tiles_a := vertex_adjacent_tiles(a)
	var count := 0
	for t in vertex_adjacent_tiles(b):
		if tiles_a.has(t):
			count += 1
	return count

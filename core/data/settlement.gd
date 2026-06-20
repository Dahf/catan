class_name Settlement
extends RefCounted
## Eine Siedlung (oder Stadt) auf einer Ecke/Vertex (Catan-Modell).

var vertex: Vector3i              # Vertex-Koordinate (Ecke zwischen ≤3 Tiles)
var level: int = 1                # 1 = Siedlung, 2 = Stadt
var owner_id: int = -1            # Spieler-ID des Besitzers

class_name Settlement
extends RefCounted
## Eine Siedlung auf einer Ecke/Vertex (Hybrid-Modell, Catan-Stil).
## Bevölkerungszentrum mit Aufstiegs-Stufen und Nachfrage.

var vertex: Vector3i              # Vertex-Koordinate (Ecke zwischen ≤3 Tiles)
var level: int = 1
var pop_tier: int = 1             # 1=Siedler, 2=Bürger, 3=Industrielle
var population: int = 0


## Gibt die aktuelle Güter-Nachfrage dieser Siedlung zurück.
func current_demand() -> Dictionary:
	# TODO: abhängig von pop_tier (Brot / Werkzeug / Kleidung ...)
	return {}

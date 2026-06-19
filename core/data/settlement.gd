class_name Settlement
extends RefCounted
## Eine Siedlung auf einer Ecke/Vertex (Hybrid-Modell, Catan-Stil).
## Bevölkerungszentrum mit Aufstiegs-Stufen und Nachfrage.

var vertex: Vector3i              # Vertex-Koordinate (Ecke zwischen ≤3 Tiles)
var level: int = 1
var pop_tier: int = 1             # 1=Siedler, 2=Bürger, 3=Industrielle
var population: int = 0
var supplied_streak: int = 0      # >0 = Runden in Folge versorgt, <0 = Runden in Folge Mangel
var upkeep_timer: int = 0         # Runden seit letzter periodischer Nachfrage (Holz/Erz ab Tier 2)

static var _demand_system := DemandSystem.new()


## Gibt die diese Runde tatsächlich fällige Güter-Nachfrage dieser Siedlung zurück
## (Basis-Nachfrage plus periodische Nachfrage, falls gerade fällig).
func current_demand() -> Dictionary:
	return _demand_system.current_total_demand(self)

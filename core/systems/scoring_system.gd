class_name ScoringSystem
extends RefCounted
## Siegpunkt-Berechnung. Reine Logik über GameState.
## Kern-Catan: Siedlung = 1 VP, Stadt = 2 VP. Hooks für längste Handelsstraße,
## größte Rittermacht und Entwicklungskarten-VP folgen später.

const WIN_VP := 10


## Berechnet die Siegpunkte eines Spielers neu, speichert sie und meldet die Änderung.
func recompute(player: Player) -> int:
	var vp := player.settlements.size() + player.cities.size() * 2
	# TODO (später): + längste Handelsstraße (2) + größte Rittermacht (2) + Dev-Karten-VP
	player.victory_points = vp
	EventBus.victory_points_changed.emit(player.id, vp)
	return vp


## Berechnet die Siegpunkte aller Spieler neu.
func recompute_all() -> void:
	for p in GameState.players:
		recompute(p)


## Hat der Spieler gewonnen (≥ 10 VP)?
func has_won(player: Player) -> bool:
	return player.victory_points >= WIN_VP


## Inerter Roguelike-Hook: Stage-Ziel (später).
func check_stage_goal() -> bool:
	return false

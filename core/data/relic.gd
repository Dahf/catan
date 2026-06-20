class_name Relic
extends Resource
## Ein Relikt/Modifikator, der während einer Partie die Regeln verändert
## (data-driven, als .tres editierbar).
##
## Effekt-Interface: Statt der einmaligen apply()-Methode fragen die Systeme typi-
## sierte Effekt-Methoden ab (Produktion, Regelbrüche, Siegpunkte, Räuber). Jede
## liefert hier einen neutralen Default; die konkreten Familien (relic_production.gd
## usw.) überschreiben nur, was sie betreffen. So bleibt es daten-getrieben und die
## Systeme müssen den konkreten Relic-Typ nicht kennen (siehe RelicSystem).

enum Category { PRODUCTION, RULEBREAK, SYNERGY, AGGRESSIVE }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var category: int = Category.PRODUCTION


## Bonus auf eine Produktions-Ausschüttung. ctx enthält
## {player, res, base_amount, terrain, settlement_level, dice_value, owner_id}.
func modify_production(_ctx: Dictionary) -> int:
	return 0


## Darf der Spieler Straßen ohne Anbindung bauen?
func allows_disconnected_roads(_player: Player) -> bool:
	return false


## Ignoriert der Spieler die Abstandsregel beim Siedlungsbau?
func ignores_settlement_distance(_player: Player) -> bool:
	return false


## Ist der Spieler immun gegen den Räuber (wird nie bestohlen)?
func is_robber_immune(_player: Player) -> bool:
	return false


## Maritimes Handelsverhältnis (4 = Standard). Reserviert für einen späteren
## Seehandels-Hook; aktuell von keinem System abgefragt.
func trade_ratio(_player: Player) -> int:
	return 4


## Zusätzliche Siegpunkte (z.B. Synergie pro Relic einer Kategorie).
func bonus_victory_points(_player: Player) -> int:
	return 0


## Zusätzliche Diebstähle bei einer 7 (für den ziehenden Spieler).
func extra_steal_on_seven(_player: Player) -> int:
	return 0


## Einmal-Effekt beim Erwerb (für genuin einmalige Boni). Standard: nichts.
## (Parameter ist das GameState-Autoload — bewusst untypisiert, da Autoload-Name kein class_name ist.)
func apply(_state) -> void:
	pass

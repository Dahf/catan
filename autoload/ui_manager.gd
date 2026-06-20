extends Node
## Zentrale UI-Sichtbarkeits-/Banner-Steuerung. Autoload-Name: UIManager.
## Panels melden sich selbst per register() an. Bei Phasenwechseln wird das
## transiente Phasen-Banner geblitzt.

var _panels: Dictionary = {}   # StringName -> Control
var hud: Control
var phase_banner: Control

func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)


func _phase_flash(phase: int) -> String:
	if phase == GameState.TurnPhase.SETUP: return "Aufbau"
	if phase == GameState.TurnPhase.ROLL: return "Würfeln"
	if phase == GameState.TurnPhase.ROBBER_DISCARD: return "Karten abwerfen"
	if phase == GameState.TurnPhase.ROBBER_MOVE: return "Räuber setzen"
	if phase == GameState.TurnPhase.BUILD: return "Bauen"
	if phase == GameState.TurnPhase.GAME_OVER: return "Spiel vorbei"
	return "?"


## Von jedem Panel in dessen _ready() aufgerufen, um sich bekanntzumachen.
func register(panel_name: StringName, control: Control) -> void:
	_panels[panel_name] = control
	match panel_name:
		&"hud":
			hud = control
			hud.show()
		&"phase_banner":
			phase_banner = control


func _flash(text: String) -> void:
	if phase_banner != null and phase_banner.has_method("flash"):
		phase_banner.flash(text)


func _on_phase_changed() -> void:
	_flash(_phase_flash(GameState.turn_phase))

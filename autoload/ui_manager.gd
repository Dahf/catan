extends Node
## Zentrale UI-Sichtbarkeits-Steuerung. Autoload-Name: UIManager.
## Ordnet Spielphasen den passenden Panels zu und ersetzt die früher in jedem
## Panel verstreute "visible = true/false"-Logik bei Phasenwechseln.
## Panels melden sich selbst per register() an - UIManager kennt main.tscn nicht.

var _panels: Dictionary = {}   # StringName -> Control

var hud: Control
var phase_banner: Control
var build_menu: Control
var building_panel: Control
var round_planning_panel: Control
var ai_turn_panel: Control


func _ready() -> void:
	EventBus.rolled_phase_entered.connect(_on_rolled_phase_entered)
	EventBus.planning_phase_entered.connect(_on_planning_phase_entered)
	EventBus.round_confirmed.connect(_on_round_confirmed)
	EventBus.ai_turn_entered.connect(_on_ai_turn_entered)
	EventBus.ai_turn_done.connect(_on_ai_turn_done)
	EventBus.round_resolved.connect(_on_round_resolved)


## Von jedem Panel in dessen _ready() aufgerufen, um sich bekanntzumachen.
func register(panel_name: StringName, control: Control) -> void:
	_panels[panel_name] = control
	match panel_name:
		&"hud":
			hud = control
			hud.show()
		&"phase_banner":
			phase_banner = control
		&"build_menu":
			build_menu = control
		&"building_panel":
			building_panel = control
		&"round_planning_panel":
			round_planning_panel = control
		&"ai_turn_panel":
			ai_turn_panel = control


func _flash(text: String) -> void:
	if phase_banner != null and phase_banner.has_method("flash"):
		phase_banner.flash(text)


func _on_rolled_phase_entered() -> void:
	_flash("Gewürfelt")


func _on_planning_phase_entered() -> void:
	if build_menu != null:
		build_menu.hide()
	if round_planning_panel != null:
		round_planning_panel.show()
	if building_panel != null:
		building_panel.hide()
	_flash("Planen")


func _on_round_confirmed() -> void:
	if round_planning_panel != null:
		round_planning_panel.hide()
	if build_menu != null:
		build_menu.show()
	_flash("Bereit für KI-Zug")


func _on_ai_turn_entered() -> void:
	if build_menu != null:
		build_menu.hide()
	if building_panel != null:
		building_panel.hide()
	if ai_turn_panel != null:
		ai_turn_panel.show()
	_flash("KI-Zug")


func _on_ai_turn_done() -> void:
	if ai_turn_panel != null:
		ai_turn_panel.hide()


func _on_round_resolved(_turn: int) -> void:
	if build_menu != null:
		build_menu.show()
	_flash("Würfeln")

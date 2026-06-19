extends GutTest
## Prüft, dass UIManager bei Phasenwechseln die richtigen Panels zeigt/versteckt.

var _stubs: Dictionary = {}


func before_each() -> void:
	_stubs.clear()
	for name in [&"hud", &"phase_banner", &"build_menu", &"building_panel", &"round_planning_panel", &"ai_turn_panel"]:
		var c := Control.new()
		c.hide()
		add_child_autofree(c)
		_stubs[name] = c
		UIManager.register(name, c)


func after_each() -> void:
	UIManager.hud = null
	UIManager.phase_banner = null
	UIManager.build_menu = null
	UIManager.building_panel = null
	UIManager.round_planning_panel = null
	UIManager.ai_turn_panel = null


func test_planning_phase_shows_round_planning_and_hides_build_menu() -> void:
	_stubs[&"build_menu"].show()
	EventBus.planning_phase_entered.emit()
	assert_true(_stubs[&"round_planning_panel"].visible, "RoundPlanningPanel sollte sichtbar sein")
	assert_false(_stubs[&"build_menu"].visible, "BuildMenu sollte versteckt sein")


func test_round_confirmed_hides_planning_and_shows_build_menu() -> void:
	_stubs[&"round_planning_panel"].show()
	EventBus.round_confirmed.emit()
	assert_false(_stubs[&"round_planning_panel"].visible, "RoundPlanningPanel sollte versteckt sein")
	assert_true(_stubs[&"build_menu"].visible, "BuildMenu sollte sichtbar sein")


func test_ai_turn_entered_shows_ai_panel_and_hides_build_menu() -> void:
	_stubs[&"build_menu"].show()
	EventBus.ai_turn_entered.emit()
	assert_true(_stubs[&"ai_turn_panel"].visible, "AiTurnPanel sollte sichtbar sein")
	assert_false(_stubs[&"build_menu"].visible, "BuildMenu sollte versteckt sein")


func test_ai_turn_done_hides_ai_panel() -> void:
	_stubs[&"ai_turn_panel"].show()
	EventBus.ai_turn_done.emit()
	assert_false(_stubs[&"ai_turn_panel"].visible, "AiTurnPanel sollte versteckt sein")


func test_round_resolved_shows_build_menu() -> void:
	EventBus.round_resolved.emit(1)
	assert_true(_stubs[&"build_menu"].visible, "BuildMenu sollte nach Rundenabschluss sichtbar sein")

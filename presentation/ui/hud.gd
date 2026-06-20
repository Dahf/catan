extends Control
## Haupt-HUD für Catan: Spieler-/Phasen-Banner oben links, Ressourcen des aktuellen
## Spielers unten mittig, Würfel-Badge unten rechts, Scoreboard oben rechts,
## Aktions-Buttons (Würfeln / Zug beenden) unten links.

var _turn_panel: PanelContainer
var _turn_label: Label
var _phase_label: Label

var _resource_panel: PanelContainer
var _chip_box: HBoxContainer

var _dice_value_label: Label

var _score_box: VBoxContainer

var _roll_button: Button
var _end_button: Button

func _phase_name(phase: int) -> String:
	if phase == GameState.TurnPhase.SETUP: return "Aufbau"
	if phase == GameState.TurnPhase.ROLL: return "Würfeln"
	if phase == GameState.TurnPhase.ROBBER_DISCARD: return "Karten abwerfen"
	if phase == GameState.TurnPhase.ROBBER_MOVE: return "Räuber setzen"
	if phase == GameState.TurnPhase.BUILD: return "Bauen"
	if phase == GameState.TurnPhase.GAME_OVER: return "Spiel vorbei"
	return "?"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_turn_banner()
	_build_resource_bar()
	_build_dice_badge()
	_build_scoreboard()
	_build_action_buttons()

	EventBus.dice_rolled.connect(_on_dice_rolled)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.victory_points_changed.connect(_on_vp_changed)
	EventBus.active_player_changed.connect(_on_active_player_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.game_won.connect(_on_game_won)

	UIManager.register(&"hud", self)
	call_deferred("_refresh_all")


func _build_turn_banner() -> void:
	_turn_panel = PanelContainer.new()
	_turn_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_turn_panel.position = Vector2(16, 16)
	_turn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_turn_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_panel.add_child(vbox)

	_turn_label = Label.new()
	_turn_label.text = "—"
	_turn_label.theme_type_variation = &"HeaderLabel"
	vbox.add_child(_turn_label)

	_phase_label = Label.new()
	_phase_label.theme_type_variation = &"SubLabel"
	_phase_label.text = "Phase: —"
	vbox.add_child(_phase_label)


func _build_resource_bar() -> void:
	_resource_panel = PanelContainer.new()
	_resource_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_resource_panel.offset_bottom = -16
	_resource_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_resource_panel)

	_chip_box = HBoxContainer.new()
	_chip_box.add_theme_constant_override("separation", 8)
	_chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resource_panel.add_child(_chip_box)


func _build_dice_badge() -> void:
	var dice_panel := PanelContainer.new()
	dice_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dice_panel.offset_left = -64
	dice_panel.offset_top = -64
	dice_panel.offset_right = -16
	dice_panel.offset_bottom = -16
	dice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dice_panel)

	_dice_value_label = Label.new()
	_dice_value_label.text = "–"
	_dice_value_label.theme_type_variation = &"HeaderLabel"
	_dice_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dice_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dice_value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dice_panel.add_child(_dice_value_label)


func _build_scoreboard() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-16, 16)
	panel.offset_left = -200
	panel.offset_right = -16
	panel.offset_top = 16
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_score_box = VBoxContainer.new()
	_score_box.add_theme_constant_override("separation", 2)
	_score_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_score_box)


func _build_action_buttons() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hbox.position = Vector2(16, -56)
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	_roll_button = Button.new()
	_roll_button.text = "Würfeln"
	_roll_button.pressed.connect(func(): Net.request_roll())
	hbox.add_child(_roll_button)

	_end_button = Button.new()
	_end_button.text = "Zug beenden"
	_end_button.pressed.connect(func(): Net.request_end_turn())
	hbox.add_child(_end_button)


# --- Updates -------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_resources()
	_rebuild_scoreboard()
	_on_phase_changed()


func _on_active_player_changed(_index: int) -> void:
	_refresh_resources()
	_rebuild_scoreboard()
	_update_turn_label()


func _on_resource_changed(player_id: int, _id: StringName, _amount: int) -> void:
	if not GameState.players.is_empty() and player_id == GameState.current_player_index:
		_refresh_resources()
	_rebuild_scoreboard()


func _on_vp_changed(_player_id: int, _vp: int) -> void:
	_rebuild_scoreboard()


func _on_phase_changed() -> void:
	_phase_label.text = "Phase: %s" % _phase_name(GameState.turn_phase)
	_update_turn_label()
	_update_actions()


func _on_dice_rolled(value: int) -> void:
	_dice_value_label.text = str(value)


func _on_game_won(player_id: int) -> void:
	if player_id < GameState.players.size():
		_turn_label.text = "%s gewinnt!" % GameState.players[player_id].display_name


func _update_turn_label() -> void:
	if GameState.players.is_empty():
		return
	var p := GameState.current_player()
	_turn_label.text = "%s am Zug" % p.display_name
	_turn_label.add_theme_color_override("font_color", p.color)


func _update_actions() -> void:
	_roll_button.visible = GameState.turn_phase == GameState.TurnPhase.ROLL
	_end_button.visible = GameState.turn_phase == GameState.TurnPhase.BUILD


func _refresh_resources() -> void:
	for child in _chip_box.get_children():
		child.queue_free()
	if GameState.players.is_empty():
		return
	var res := GameState.current_player().resources
	for id in CatanPalette.RESOURCE_ORDER:
		_chip_box.add_child(ResourceChip.build(id, int(res.get(id, 0))))


func _rebuild_scoreboard() -> void:
	for child in _score_box.get_children():
		child.queue_free()
	for p in GameState.players:
		var row := Label.new()
		row.text = "%s   %d VP   %d Karten" % [p.display_name, p.victory_points, p.total_cards()]
		row.add_theme_color_override("font_color", p.color)
		if p.id == GameState.current_player_index:
			row.theme_type_variation = &"HeaderLabel"
		_score_box.add_child(row)

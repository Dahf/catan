extends Control
## Haupt-HUD: Runden-/Phasen-Banner oben links, Ressourcenleiste unten mittig,
## Würfel-Badge unten rechts. Layout angelehnt an Catan Universe (Spieler-
## Banner oben, Hand-Ressourcen unten mittig, Würfel unten rechts).

var _turn_panel: PanelContainer
var _turn_label: Label
var _phase_label: Label

var _resource_panel: PanelContainer
var _chip_box: HBoxContainer
var _chips: Dictionary = {}   # StringName -> PanelContainer

var _dice_panel: PanelContainer
var _dice_value_label: Label

var _carry_panel: PanelContainer
var _carry_label: Label
var _carry_cost_box: HBoxContainer

const PHASE_NAMES := {
	0: "Würfeln",            # GameState.TurnPhase.ROLLING
	1: "Gewürfelt",          # GameState.TurnPhase.ROLLED
	2: "Planen",             # GameState.TurnPhase.PLANNING
	3: "Bereit für KI-Zug",  # GameState.TurnPhase.AI_PENDING
	4: "KI-Zug",             # GameState.TurnPhase.AI_TURN
	5: "Ausführen",          # GameState.TurnPhase.RESOLVING
}


func _ready() -> void:
	# Leere HUD-Fläche darf Maus-Events nicht abfangen (Board-Drag).
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_turn_banner()
	_build_resource_bar()
	_build_dice_badge()
	_build_carry_indicator()

	EventBus.dice_rolled.connect(_on_dice_rolled)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.turn_advanced.connect(_on_turn_advanced)
	EventBus.rolled_phase_entered.connect(_on_phase_event)
	EventBus.planning_phase_entered.connect(_on_phase_event)
	EventBus.round_confirmed.connect(_on_phase_event)
	EventBus.ai_turn_entered.connect(_on_phase_event)
	EventBus.round_resolved.connect(_on_phase_event)
	EventBus.carried_building_changed.connect(_on_carried_building_changed)

	UIManager.register(&"hud", self)


## Kompaktes Banner oben links: Rundennummer + Phase, wie eine Spielerkarte.
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
	_turn_label.text = "Runde 0"
	_turn_label.theme_type_variation = &"HeaderLabel"
	vbox.add_child(_turn_label)

	_phase_label = Label.new()
	_phase_label.theme_type_variation = &"SubLabel"
	_phase_label.text = "Phase: %s" % PHASE_NAMES.get(GameState.turn_phase, "?")
	vbox.add_child(_phase_label)


## Lange Pille unten mittig mit den Ressourcen-Chips, wie die Handkarten-
## Leiste in Catan Universe.
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


## Würfel-Badge unten rechts, abgesetzt vom Aktionsbereich des Boards.
func _build_dice_badge() -> void:
	_dice_panel = PanelContainer.new()
	_dice_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dice_panel.offset_left = -64
	_dice_panel.offset_top = -64
	_dice_panel.offset_right = -16
	_dice_panel.offset_bottom = -16
	_dice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dice_panel)

	_dice_value_label = Label.new()
	_dice_value_label.text = "–"
	_dice_value_label.theme_type_variation = &"HeaderLabel"
	_dice_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dice_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dice_value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dice_panel.add_child(_dice_value_label)


## Anzeige des aktuell vom Spieler getragenen Bauteils (Name + Kosten),
## über der Ressourcen-Pille, ausgeblendet solange nichts getragen wird.
func _build_carry_indicator() -> void:
	_carry_panel = PanelContainer.new()
	_carry_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_carry_panel.offset_bottom = -64
	_carry_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carry_panel.visible = false
	add_child(_carry_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carry_panel.add_child(vbox)

	_carry_label = Label.new()
	_carry_label.theme_type_variation = &"SubLabel"
	_carry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_carry_label)

	_carry_cost_box = HBoxContainer.new()
	_carry_cost_box.add_theme_constant_override("separation", 4)
	_carry_cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carry_cost_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_carry_cost_box)


func _on_carried_building_changed(def: BuildingDef) -> void:
	if def == null:
		_carry_panel.visible = false
		return
	_carry_label.text = "Trägt: %s" % def.display_name
	for child in _carry_cost_box.get_children():
		child.queue_free()
	_carry_cost_box.add_child(ResourceChip.build_row(def.build_cost))
	_carry_panel.visible = true


func _on_phase_event(_arg = null) -> void:
	_phase_label.text = "Phase: %s" % PHASE_NAMES.get(GameState.turn_phase, "?")


func _on_turn_advanced(turn: int) -> void:
	_turn_label.text = "Runde %d" % turn


func _on_dice_rolled(value: int) -> void:
	_dice_value_label.text = str(value)


func _on_resource_changed(id: StringName, amount: int) -> void:
	if _chips.has(id):
		ResourceChip.update_amount(_chips[id], amount)
		return
	var chip := ResourceChip.build(id, amount)
	_chips[id] = chip
	_insert_chip_in_order(id, chip)


## Fügt einen neuen Chip an der durch RESOURCE_ORDER vorgegebenen Position ein,
## damit die Leiste nicht je nach Entstehungsreihenfolge der Ressourcen springt.
func _insert_chip_in_order(id: StringName, chip: Control) -> void:
	var target_index := CatanPalette.RESOURCE_ORDER.find(id)
	if target_index == -1:
		_chip_box.add_child(chip)
		return
	for existing_id in _chips:
		if existing_id == id:
			continue
		var existing_chip : Control = _chips[existing_id]
		var existing_index := CatanPalette.RESOURCE_ORDER.find(existing_id)
		if existing_index != -1 and existing_index > target_index and existing_chip.get_parent() == _chip_box:
			_chip_box.add_child(chip)
			_chip_box.move_child(chip, existing_chip.get_index())
			return
	_chip_box.add_child(chip)

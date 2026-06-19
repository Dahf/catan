extends Control
## Detail-Panel für ein angeklicktes Gebäude oder eine Siedlung.
## Gebäude-Ansicht: Kategorie-Badge, Rezept als Chips, Fortschrittsbalken,
## Aktiv-Schalter, Priorität. Siedlungs-Ansicht: Tier-Badge, Bevölkerung,
## Versorgungs-Meter, Nachschub-Countdown.

var _panel: PanelContainer
var _box: VBoxContainer
var _title_label: Label
var _badge_panel: PanelContainer
var _badge_label: Label

var _building_section: VBoxContainer
var _recipe_row: HBoxContainer
var _progress_bar: ProgressBar
var _progress_label: Label
var _active_check: CheckButton
var _priority_spin: SpinBox

var _settlement_section: VBoxContainer
var _population_label: Label
var _demand_row: HBoxContainer
var _tier_meter: TierMeter
var _tier_meter_label: Label
var _upkeep_box: VBoxContainer
var _upkeep_bar: ProgressBar
var _upkeep_label: Label

var _open_coord: Vector2i
var _open_vertex: Vector3i
var _mode: StringName = &""   # &"building" oder &"settlement"
var _demand_system := DemandSystem.new()


const OVERLAY_SIZE := Vector2(480, 420)

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.55)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim_bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -OVERLAY_SIZE.x / 2.0
	_panel.offset_top = -OVERLAY_SIZE.y / 2.0
	_panel.offset_right = OVERLAY_SIZE.x / 2.0
	_panel.offset_bottom = OVERLAY_SIZE.y / 2.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	_box.add_child(title_row)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"HeaderLabel"
	title_row.add_child(_title_label)
	_badge_panel = PanelContainer.new()
	title_row.add_child(_badge_panel)
	_badge_label = Label.new()
	_badge_panel.add_child(_badge_label)

	_build_building_section()
	_build_settlement_section()

	var close_btn := Button.new()
	close_btn.text = "Schließen"
	close_btn.pressed.connect(_close)
	_box.add_child(close_btn)

	EventBus.building_selected.connect(_on_building_selected)
	EventBus.settlement_selected.connect(_on_settlement_selected)
	EventBus.turn_advanced.connect(_on_turn_advanced)
	EventBus.building_updated.connect(_on_building_updated)

	UIManager.register(&"building_panel", self)


func _build_building_section() -> void:
	_building_section = VBoxContainer.new()
	_building_section.add_theme_constant_override("separation", 8)
	_box.add_child(_building_section)

	_recipe_row = HBoxContainer.new()
	_recipe_row.add_theme_constant_override("separation", 8)
	_building_section.add_child(_recipe_row)

	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 12)
	_building_section.add_child(_progress_bar)

	_progress_label = Label.new()
	_progress_label.theme_type_variation = &"SubLabel"
	_building_section.add_child(_progress_label)

	_active_check = CheckButton.new()
	_active_check.toggled.connect(_on_active_toggled)
	_building_section.add_child(_active_check)

	var prio_row := HBoxContainer.new()
	prio_row.add_theme_constant_override("separation", 8)
	_building_section.add_child(prio_row)
	var prio_label := Label.new()
	prio_label.text = "Priorität:"
	prio_row.add_child(prio_label)
	_priority_spin = SpinBox.new()
	_priority_spin.min_value = -50
	_priority_spin.max_value = 50
	_priority_spin.value_changed.connect(_on_priority_changed)
	prio_row.add_child(_priority_spin)
	var prio_slider := HSlider.new()
	prio_slider.min_value = -50
	prio_slider.max_value = 50
	prio_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prio_slider.value_changed.connect(_on_priority_changed)
	_priority_spin.value_changed.connect(func(v): prio_slider.set_value_no_signal(v))
	prio_slider.value_changed.connect(func(v): _priority_spin.set_value_no_signal(v))
	prio_row.add_child(prio_slider)


func _build_settlement_section() -> void:
	_settlement_section = VBoxContainer.new()
	_settlement_section.add_theme_constant_override("separation", 8)
	_box.add_child(_settlement_section)

	_population_label = Label.new()
	_settlement_section.add_child(_population_label)

	var demand_title := Label.new()
	demand_title.theme_type_variation = &"SubLabel"
	demand_title.text = "Laufende Nachfrage:"
	_settlement_section.add_child(demand_title)
	_demand_row = HBoxContainer.new()
	_settlement_section.add_child(_demand_row)

	var meter_title := Label.new()
	meter_title.theme_type_variation = &"SubLabel"
	meter_title.text = "Versorgungs-Streak:"
	_settlement_section.add_child(meter_title)
	var meter_row := HBoxContainer.new()
	meter_row.add_theme_constant_override("separation", 8)
	_settlement_section.add_child(meter_row)
	_tier_meter = TierMeter.new()
	meter_row.add_child(_tier_meter)
	_tier_meter_label = Label.new()
	meter_row.add_child(_tier_meter_label)

	_upkeep_box = VBoxContainer.new()
	_settlement_section.add_child(_upkeep_box)
	_upkeep_bar = ProgressBar.new()
	_upkeep_bar.show_percentage = false
	_upkeep_bar.custom_minimum_size = Vector2(0, 12)
	_upkeep_box.add_child(_upkeep_bar)
	_upkeep_label = Label.new()
	_upkeep_label.theme_type_variation = &"SubLabel"
	_upkeep_box.add_child(_upkeep_label)


func _close() -> void:
	visible = false
	_mode = &""


func _on_building_selected(coord: Vector2i) -> void:
	_open_coord = coord
	_mode = &"building"
	visible = true
	_refresh_building()


func _on_settlement_selected(vertex: Vector3i) -> void:
	_open_vertex = vertex
	_mode = &"settlement"
	visible = true
	_refresh_settlement()


func _on_turn_advanced(_turn: int) -> void:
	_refresh()


func _on_building_updated(coord: Vector2i) -> void:
	if _mode == &"building" and coord == _open_coord:
		_refresh_building()


func _refresh() -> void:
	if _mode == &"building":
		_refresh_building()
	elif _mode == &"settlement":
		_refresh_settlement()


func _refresh_building() -> void:
	var tile : Tile = GameState.tiles.get(_open_coord)
	if tile == null or tile.building == null:
		_close()
		return
	var building : BuildingInstance = tile.building
	var def : BuildingDef = building.def

	_title_label.text = def.display_name
	_badge_label.text = " %s " % CatanPalette.CATEGORY_NAMES.get(def.category, "")
	_badge_label.add_theme_color_override("font_color", Color.WHITE)
	var badge_bg := StyleBoxFlat.new()
	badge_bg.bg_color = CatanPalette.CATEGORY_COLORS.get(def.category, CatanPalette.PARCHMENT_DARK)
	badge_bg.corner_radius_top_left = 8
	badge_bg.corner_radius_top_right = 8
	badge_bg.corner_radius_bottom_right = 8
	badge_bg.corner_radius_bottom_left = 8
	_badge_panel.add_theme_stylebox_override("panel", badge_bg)

	_building_section.show()
	_settlement_section.hide()

	for child in _recipe_row.get_children():
		child.queue_free()

	if def.recipe != null:
		_recipe_row.add_child(ResourceChip.build_row(def.recipe.inputs))
		var arrow := Label.new()
		arrow.text = "→"
		arrow.add_theme_color_override("font_color", CatanPalette.WOOD_BROWN)
		_recipe_row.add_child(arrow)
		_recipe_row.add_child(ResourceChip.build_row(def.recipe.outputs))

		_progress_bar.show()
		_progress_bar.max_value = def.recipe.turns_per_cycle
		_progress_bar.value = building.recipe_progress
		_progress_label.text = "Fortschritt: %d/%d Runden" % [building.recipe_progress, def.recipe.turns_per_cycle]
	else:
		var none_label := Label.new()
		none_label.text = "Keine Produktion (Infrastruktur)."
		_recipe_row.add_child(none_label)
		_progress_bar.hide()
		_progress_label.text = ""

	_active_check.text = "Aktiv" if building.active else "Inaktiv"
	_active_check.set_pressed_no_signal(building.active)
	_priority_spin.set_value_no_signal(building.priority)


func _refresh_settlement() -> void:
	var settlement : Settlement = GameState.settlements.get(_open_vertex)
	if settlement == null:
		_close()
		return

	_title_label.text = "Siedlung"
	_badge_label.text = " Tier %d " % settlement.pop_tier
	_badge_label.add_theme_color_override("font_color", Color.WHITE)
	var badge_bg := StyleBoxFlat.new()
	badge_bg.bg_color = CatanPalette.TIER_COLORS.get(settlement.pop_tier, CatanPalette.PARCHMENT_DARK)
	badge_bg.corner_radius_top_left = 8
	badge_bg.corner_radius_top_right = 8
	badge_bg.corner_radius_bottom_right = 8
	badge_bg.corner_radius_bottom_left = 8
	_badge_panel.add_theme_stylebox_override("panel", badge_bg)

	_building_section.hide()
	_settlement_section.show()

	_population_label.text = "Bevölkerung: %d" % settlement.population

	for child in _demand_row.get_children():
		child.queue_free()
	_demand_row.add_child(ResourceChip.build_row(_demand_system.base_demand_for_tier(settlement.pop_tier)))

	_tier_meter.min_value = DemandSystem.TIER_DOWN_STREAK
	_tier_meter.max_value = DemandSystem.TIER_UP_STREAK
	_tier_meter.value = settlement.supplied_streak
	_tier_meter_label.text = "%+d" % settlement.supplied_streak

	var periodic := _demand_system.periodic_demand_for_tier(settlement.pop_tier)
	if periodic.is_empty():
		_upkeep_box.hide()
	else:
		_upkeep_box.show()
		_upkeep_bar.max_value = DemandSystem.PERIODIC_PERIOD
		_upkeep_bar.value = settlement.upkeep_timer
		var rounds_left := maxi(DemandSystem.PERIODIC_PERIOD - settlement.upkeep_timer, 0)
		_upkeep_label.text = "Nachschub fällig in %d Runden: %s" % [
			rounds_left,
			CatanPalette.resource_label(periodic.keys()[0]) if periodic.size() == 1 else _format_goods(periodic),
		]


func _on_active_toggled(pressed: bool) -> void:
	if _mode == &"building":
		GameState.set_building_active(_open_coord, pressed)


func _on_priority_changed(value: float) -> void:
	if _mode == &"building":
		GameState.set_building_priority(_open_coord, int(value))


func _format_goods(goods: Dictionary) -> String:
	var parts : Array[String] = []
	for id in goods:
		parts.append("%d %s" % [int(goods[id]), CatanPalette.resource_label(id)])
	return ", ".join(parts) if not parts.is_empty() else "–"

extends Control
## Rundenplanungs-Screen: zeigt alle aktiven Produktionsgebäude gruppiert nach
## Kategorie, sortiert nach Leistbarkeit, mit Fortschrittsbalken und der
## Möglichkeit, alle aktuell leistbaren Gebäude auf einmal auszuwählen.

var _panel: PanelContainer
var _list_box: VBoxContainer
var _hint_label: Label
var _confirm_btn: Button
var _select_affordable_btn: Button

var _rows: Dictionary = {}   # Vector2i -> { "status": Label, "progress": ProgressBar }

const OVERLAY_SIZE := Vector2(620, 520)


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

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	var title_label := Label.new()
	title_label.text = "Runde planen"
	title_label.theme_type_variation = &"HeaderLabel"
	box.add_child(title_label)

	var header_row := HBoxContainer.new()
	box.add_child(header_row)
	_hint_label = Label.new()
	_hint_label.theme_type_variation = &"SubLabel"
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_hint_label)
	_select_affordable_btn = Button.new()
	_select_affordable_btn.text = "Alle leistbaren auswählen"
	_select_affordable_btn.pressed.connect(_on_select_affordable_pressed)
	header_row.add_child(_select_affordable_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	box.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 10)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Runde bestätigen"
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	box.add_child(_confirm_btn)

	EventBus.planning_phase_entered.connect(_on_planning_phase_entered)
	EventBus.building_updated.connect(_on_building_updated)

	UIManager.register(&"round_planning_panel", self)


func _on_planning_phase_entered() -> void:
	_populate()


func _populate() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	_rows.clear()

	var by_category: Dictionary = {}   # Category -> Array[Dictionary{coord, building}]
	var knapp_count := 0
	var total := 0

	for coord in GameState.tiles:
		var tile : Tile = GameState.tiles[coord]
		var building : BuildingInstance = tile.building
		if building == null or not building.active or building.def == null or building.def.recipe == null:
			continue

		total += 1
		if not building.can_produce():
			knapp_count += 1
		if not by_category.has(building.def.category):
			by_category[building.def.category] = []
		by_category[building.def.category].append({"coord": coord, "building": building})

	_hint_label.text = "%d Gebäude, davon %d mit knappen Inputs." % [total, knapp_count]

	var category_order := [
		BuildingDef.Category.EXTRACTOR,
		BuildingDef.Category.PROCESSOR,
		BuildingDef.Category.FACTORY,
	]

	for category in category_order:
		if not by_category.has(category):
			continue
		var entries : Array = by_category[category]
		# Leistbare zuerst, dann nach Priorität absteigend.
		entries.sort_custom(func(a, b):
			var a_ok : bool = a["building"].can_produce()
			var b_ok : bool = b["building"].can_produce()
			if a_ok != b_ok:
				return a_ok
			return a["building"].priority > b["building"].priority
		)

		var header := Label.new()
		header.theme_type_variation = &"SubLabel"
		header.text = CatanPalette.CATEGORY_NAMES.get(category, "")
		_list_box.add_child(header)

		for entry in entries:
			_list_box.add_child(_make_row(entry["coord"], entry["building"]))


func _make_row(coord: Vector2i, building: BuildingInstance) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"RecessedPanel"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var name_label := Label.new()
	name_label.text = building.def.display_name
	name_label.custom_minimum_size = Vector2(130, 0)
	row.add_child(name_label)

	var recipe_box := VBoxContainer.new()
	recipe_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(recipe_box)

	var recipe_row := HBoxContainer.new()
	recipe_row.add_theme_constant_override("separation", 6)
	recipe_row.add_child(ResourceChip.build_row(building.def.recipe.inputs))
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_color_override("font_color", CatanPalette.WOOD_BROWN)
	recipe_row.add_child(arrow)
	recipe_row.add_child(ResourceChip.build_row(building.def.recipe.outputs))
	recipe_box.add_child(recipe_row)

	var progress := ProgressBar.new()
	progress.min_value = 0
	progress.max_value = building.def.recipe.turns_per_cycle
	progress.value = building.recipe_progress
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 10)
	recipe_box.add_child(progress)

	var status_label := Label.new()
	status_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(status_label)

	var check := CheckButton.new()
	check.set_pressed_no_signal(building.produce_this_round)
	check.toggled.connect(_on_row_toggled.bind(coord))
	row.add_child(check)

	_rows[coord] = {"status": status_label, "progress": progress}
	_refresh_status(coord)

	return card


func _refresh_status(coord: Vector2i) -> void:
	var row_data : Dictionary = _rows.get(coord)
	if row_data == null:
		return
	var tile : Tile = GameState.tiles.get(coord)
	if tile == null or tile.building == null:
		return
	var status_label : Label = row_data["status"]
	var progress : ProgressBar = row_data["progress"]
	progress.max_value = tile.building.def.recipe.turns_per_cycle
	progress.value = tile.building.recipe_progress
	if tile.building.can_produce():
		status_label.text = "OK"
		status_label.add_theme_color_override("font_color", CatanPalette.FOREST_GREEN)
	else:
		status_label.text = "Knapp"
		status_label.add_theme_color_override("font_color", CatanPalette.LEATHER_RED)


func _on_row_toggled(pressed: bool, coord: Vector2i) -> void:
	GameState.set_building_produce_this_round(coord, pressed)


func _on_building_updated(coord: Vector2i) -> void:
	if _rows.has(coord):
		_refresh_status(coord)


## Aktiviert die Produktion für alle aktuell leistbaren, aber noch nicht
## ausgewählten Gebäude. Bereits ausgewählte, nicht leistbare Gebäude werden
## bewusst NICHT abgewählt, um keine bestehende Spielerentscheidung zu überschreiben.
func _on_select_affordable_pressed() -> void:
	for coord in _rows:
		var tile : Tile = GameState.tiles.get(coord)
		if tile == null or tile.building == null:
			continue
		if tile.building.can_produce() and not tile.building.produce_this_round:
			GameState.set_building_produce_this_round(coord, true)
	_populate()


func _on_confirm_pressed() -> void:
	EventBus.round_confirmed.emit()

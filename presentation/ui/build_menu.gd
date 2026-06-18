extends Control
## Baumenü: listet verfügbare Bautypen und startet den Bau-Modus.

var _row: HBoxContainer


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(panel)
	_row = HBoxContainer.new()
	panel.add_child(_row)
	populate()


## Befüllt das Menü mit den verfügbaren Bautypen aus der ContentDB.
func populate() -> void:
	for child in _row.get_children():
		child.queue_free()
	for def in ContentDB.all_buildings():
		var btn := Button.new()
		btn.text = _label_for(def)
		btn.pressed.connect(_on_building_selected.bind(def))
		_row.add_child(btn)


func _label_for(def: BuildingDef) -> String:
	var parts: Array[String] = []
	for id in def.build_cost:
		var res_name: String = Terrain.RESOURCE_NAMES.get(id, str(id))
		parts.append("%d %s" % [int(def.build_cost[id]), res_name])
	return "%s (%s)" % [def.display_name, ", ".join(parts)]


func _on_building_selected(def: BuildingDef) -> void:
	EventBus.build_mode_requested.emit(def)

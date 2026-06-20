extends Control
## Dauerhafte Relic-Übersicht am linken Rand: zeigt alle Spieler und ihre erworbenen
## Relics. Effektbeschreibung + Kategorie erscheinen als Tooltip beim Hovern.

var _box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.position = Vector2(16, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_box.custom_minimum_size = Vector2(180, 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_box)

	EventBus.relic_acquired.connect(_on_relic_acquired)
	EventBus.active_player_changed.connect(_on_active_player_changed)
	EventBus.phase_changed.connect(_rebuild)
	call_deferred("_rebuild")


func _on_relic_acquired(_relic: Relic) -> void:
	_rebuild()


func _on_active_player_changed(_index: int) -> void:
	_rebuild()


func _rebuild() -> void:
	for child in _box.get_children():
		child.queue_free()
	if GameState.players.is_empty():
		return

	var header := Label.new()
	header.text = "Relikte (Stage %d)" % GameState.stage
	header.theme_type_variation = &"HeaderLabel"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(header)

	for p in GameState.players:
		var name_row := Label.new()
		name_row.text = p.display_name
		name_row.add_theme_color_override("font_color", p.color)
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(name_row)

		if p.relics.is_empty():
			var none := Label.new()
			none.text = "   —"
			none.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_box.add_child(none)
			continue

		for r in p.relics:
			var row := Label.new()
			row.text = "   • %s" % r.display_name
			row.tooltip_text = "%s\n%s" % [_category_name(r.category), r.description]
			row.mouse_filter = Control.MOUSE_FILTER_STOP   # nötig, damit der Tooltip erscheint
			_box.add_child(row)


func _category_name(category: int) -> String:
	match category:
		Relic.Category.PRODUCTION: return "Produktion"
		Relic.Category.RULEBREAK: return "Regelbruch"
		Relic.Category.SYNERGY: return "Synergie"
		Relic.Category.AGGRESSIVE: return "Aggressiv"
	return "?"

extends Control
## Modale Overlays rund um den Räuber (bei einer 7):
##  - Abwurf: der betroffene Spieler wählt die Hälfte seiner Karten zum Abwerfen.
##  - Opferwahl: der Räuber-Spieler wählt unter mehreren angrenzenden Spielern.
## Reagiert auf EventBus-Anfragen und meldet die Entscheidung zurück.

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _confirm: Button

# Abwurf-Zustand
var _discard_player: int = -1
var _discard_needed: int = 0
var _selected: Dictionary = {}   # StringName -> int


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(360, 0)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	vbox.add_child(_body)

	_confirm = Button.new()
	_confirm.text = "Bestätigen"
	_confirm.pressed.connect(_on_confirm)
	vbox.add_child(_confirm)

	EventBus.robber_discard_required.connect(_show_discard)
	EventBus.robber_victims_available.connect(_show_victims)

	_hide_overlay()


func _hide_overlay() -> void:
	visible = false


# --- Abwurf --------------------------------------------------------------------

func _show_discard(player_id: int, count: int) -> void:
	_discard_player = player_id
	_discard_needed = count
	_selected.clear()
	_confirm.visible = true
	_title.text = "%s: %d Karten abwerfen" % [GameState.players[player_id].display_name, count]
	_rebuild_discard_rows()
	visible = true


func _rebuild_discard_rows() -> void:
	for child in _body.get_children():
		child.queue_free()
	var res := GameState.players[_discard_player].resources
	for id in CatanPalette.RESOURCE_ORDER:
		var have := int(res.get(id, 0))
		if have <= 0:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_label := Label.new()
		name_label.text = CatanPalette.resource_label(id)
		name_label.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_label)

		var minus := Button.new()
		minus.text = "−"
		minus.pressed.connect(_adjust_discard.bind(id, -1))
		row.add_child(minus)

		var count_label := Label.new()
		count_label.text = "%d / %d" % [int(_selected.get(id, 0)), have]
		count_label.custom_minimum_size = Vector2(60, 0)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count_label)

		var plus := Button.new()
		plus.text = "+"
		plus.pressed.connect(_adjust_discard.bind(id, 1))
		row.add_child(plus)

		_body.add_child(row)
	_update_confirm()


func _adjust_discard(id: StringName, delta: int) -> void:
	var have := int(GameState.players[_discard_player].get_resource(id))
	var cur := int(_selected.get(id, 0))
	var total := _selected_total()
	var next := clampi(cur + delta, 0, have)
	if delta > 0 and total >= _discard_needed:
		return   # nicht mehr als nötig auswählen
	_selected[id] = next
	_rebuild_discard_rows()


func _selected_total() -> int:
	var n := 0
	for id in _selected:
		n += _selected[id]
	return n


func _update_confirm() -> void:
	_confirm.disabled = _selected_total() != _discard_needed


# --- Opferwahl -----------------------------------------------------------------

func _show_victims(victim_ids: Array) -> void:
	_discard_player = -1
	_confirm.visible = false
	_title.text = "Wen bestehlen?"
	for child in _body.get_children():
		child.queue_free()
	for id in victim_ids:
		var btn := Button.new()
		btn.text = GameState.players[id].display_name
		btn.add_theme_color_override("font_color", GameState.players[id].color)
		btn.pressed.connect(_on_victim_chosen.bind(id))
		_body.add_child(btn)
	visible = true


func _on_victim_chosen(victim_id: int) -> void:
	_hide_overlay()
	Net.request_robber_victim(victim_id)


# --- Bestätigen (Abwurf) -------------------------------------------------------

func _on_confirm() -> void:
	if _discard_player < 0 or _selected_total() != _discard_needed:
		return
	var discards: Dictionary = {}
	for id in _selected:
		if _selected[id] > 0:
			discards[id] = _selected[id]
	var pid := _discard_player
	_hide_overlay()
	Net.request_discard(pid, discards)

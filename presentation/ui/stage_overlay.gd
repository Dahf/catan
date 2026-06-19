extends Control
## Stage-Overlay: zeigt das aktuelle Stage-Ziel sowie das Ergebnis (Sieg/Niederlage).
## Hinweis: es existiert noch kein Stage-Ziel-/Ergebnis-Datenmodell und die Szene
## wird aktuell nirgends instanziert (EventBus.stage_completed/run_ended werden
## nie ausgelöst) - Inhalt folgt, sobald diese Systeme existieren.

var _panel: PanelContainer
var _title_label: Label
var _body_label: Label

const OVERLAY_SIZE := Vector2(420, 200)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.55)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim_bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -OVERLAY_SIZE.x / 2.0
	_panel.offset_top = -OVERLAY_SIZE.y / 2.0
	_panel.offset_right = OVERLAY_SIZE.x / 2.0
	_panel.offset_bottom = OVERLAY_SIZE.y / 2.0
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	_title_label = Label.new()
	_title_label.text = "Stage-Ziel"
	_title_label.theme_type_variation = &"HeaderLabel"
	box.add_child(_title_label)

	_body_label = Label.new()
	_body_label.text = "Diese Funktion folgt in einer späteren Iteration."
	box.add_child(_body_label)


## Zeigt das Ziel der aktuellen Stage an.
func show_goal() -> void:
	# TODO: sobald ein Stage-Ziel-Datenmodell existiert.
	pass


## Zeigt das Stage-Ergebnis an.
func show_result(success: bool) -> void:
	# TODO: sobald Sieg-/Niederlage-Logik existiert.
	pass

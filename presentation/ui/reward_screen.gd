extends Control
## Belohnungs-Screen nach erfolgreicher Stage: Auswahl 1 aus 3 (Relikt/Blueprint/Boost).
## Hinweis: es existiert noch kein Belohnungs-/Relikt-Auswahlsystem und die Szene
## wird aktuell nirgends instanziert (EventBus.relic_acquired wird nie ausgelöst) -
## Inhalt folgt, sobald dieses System existiert.

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
	_title_label.text = "Belohnung wählen"
	_title_label.theme_type_variation = &"HeaderLabel"
	box.add_child(_title_label)

	_body_label = Label.new()
	_body_label.text = "Diese Funktion folgt in einer späteren Iteration."
	box.add_child(_body_label)


## Zeigt die zur Wahl stehenden Belohnungen an.
func present_choices(choices: Array) -> void:
	# TODO: sobald ein Belohnungs-/Relikt-Auswahlsystem existiert.
	pass


func _on_reward_chosen(choice) -> void:
	# TODO: sobald ein Belohnungs-/Relikt-Auswahlsystem existiert.
	pass

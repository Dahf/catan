extends Control
## Transiente Phasenwechsel-Anzeige: blendet kurz mittig über dem Bildschirm
## ein, wenn UIManager.flash() aufgerufen wird, und verschwindet danach wieder.
## Hält keinen dauerhaften Zustand mehr - die persistente Phasenanzeige sitzt
## jetzt im HUD.

const FADE_IN := 0.15
const HOLD := 0.9
const FADE_OUT := 0.3

var _panel: PanelContainer
var _label: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_top = 70
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_label = Label.new()
	_label.theme_type_variation = &"HeaderLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)

	UIManager.register(&"phase_banner", self)


## Wird ausschließlich von UIManager bei Phasenwechseln aufgerufen.
func flash(text: String) -> void:
	_label.text = text
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)

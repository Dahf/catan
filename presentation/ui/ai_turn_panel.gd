extends Control
## KI-Zug-Overlay: simuliert einen "Die KI denkt..."-Ablauf mit animierten
## Schritten und Fortschrittsbalken. Die eigentliche KI-Logik ist noch ein
## Platzhalter (main.gd löst beim Abschluss direkt _resolve_turn() aus) - hier
## geht es nur um eine ehrliche, nicht-blockierende Wartedarstellung.

const STEPS := [
	"Sammelt Ressourcen…",
	"Bewertet Bauoptionen…",
	"Baut…",
	"Fertig.",
]
const STEP_DELAY_MIN := 0.5
const STEP_DELAY_MAX := 0.9

var _panel: PanelContainer
var _title_label: Label
var _step_log: VBoxContainer
var _progress_bar: ProgressBar
var _skip_btn: Button

## Schützt vor doppeltem ai_turn_done: einmal durch die automatische Sequenz,
## einmal durch manuellen Skip. main.gd._resolve_turn() würde sonst zweimal
## laufen und Ressourcen/Runde doppelt verarbeiten.
var _sequence_active: bool = false

const OVERLAY_SIZE := Vector2(420, 280)


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

	_title_label = Label.new()
	_title_label.text = "Die KI plant ihren Zug…"
	_title_label.theme_type_variation = &"HeaderLabel"
	box.add_child(_title_label)

	_step_log = VBoxContainer.new()
	_step_log.add_theme_constant_override("separation", 4)
	box.add_child(_step_log)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 12)
	box.add_child(_progress_bar)

	_skip_btn = Button.new()
	_skip_btn.text = "Weiter"
	_skip_btn.pressed.connect(_on_skip_pressed)
	box.add_child(_skip_btn)

	EventBus.ai_turn_entered.connect(_on_ai_turn_entered)

	UIManager.register(&"ai_turn_panel", self)


func _on_ai_turn_entered() -> void:
	_run_sequence()


func _run_sequence() -> void:
	for child in _step_log.get_children():
		child.queue_free()
	_progress_bar.value = 0
	_sequence_active = true
	_skip_btn.text = "Überspringen"

	var delays : Array[float] = []
	for i in STEPS.size():
		delays.append(STEP_DELAY_MIN + RNG.randf() * (STEP_DELAY_MAX - STEP_DELAY_MIN))
	var total_delay : float = 0.0
	for d in delays:
		total_delay += d

	var elapsed := 0.0
	for i in STEPS.size():
		if not _sequence_active:
			return
		var line := Label.new()
		line.text = STEPS[i]
		if i == STEPS.size() - 1:
			line.add_theme_color_override("font_color", CatanPalette.FOREST_GREEN)
			line.text = "✓ " + line.text
		_step_log.add_child(line)

		await get_tree().create_timer(delays[i]).timeout
		if not _sequence_active:
			return
		elapsed += delays[i]
		_progress_bar.value = clampf(elapsed / total_delay * 100.0, 0, 100)

	if _sequence_active:
		_finish()


func _finish() -> void:
	if not _sequence_active:
		return
	_sequence_active = false
	EventBus.ai_turn_done.emit()


func _on_skip_pressed() -> void:
	if _sequence_active:
		_sequence_active = false
		EventBus.ai_turn_done.emit()
	else:
		# Sequenz ist bereits fertig (oder Panel war anderweitig sichtbar) -
		# manuelles Schließen ohne erneutes ai_turn_done.
		pass

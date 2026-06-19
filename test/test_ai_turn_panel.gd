extends GutTest
## Prüft, dass ai_turn_done bei einem Skip mitten in der Sequenz nicht doppelt
## ausgelöst wird (sonst würde main.gd._resolve_turn() die Runde doppelt verarbeiten).

var _panel: Control
var _done_count: int = 0


func before_each() -> void:
	_done_count = 0
	var scene : PackedScene = load("res://presentation/ui/ai_turn_panel.tscn")
	_panel = scene.instantiate()
	add_child_autofree(_panel)
	EventBus.ai_turn_done.connect(_on_ai_turn_done)


func after_each() -> void:
	EventBus.ai_turn_done.disconnect(_on_ai_turn_done)
	UIManager.ai_turn_panel = null


func _on_ai_turn_done() -> void:
	_done_count += 1


func test_manual_skip_during_sequence_emits_done_exactly_once() -> void:
	EventBus.ai_turn_entered.emit()
	await wait_seconds(0.1)
	_panel._on_skip_pressed()
	# Über die volle (zufällige, max. ~4*0.9s) Sequenzdauer hinaus warten, um
	# sicherzustellen, dass die automatische Fertigstellung nicht noch nachträglich feuert.
	await wait_seconds(4.0)
	assert_eq(_done_count, 1, "ai_turn_done darf nach manuellem Skip nicht doppelt feuern")


func test_full_sequence_auto_completes_once() -> void:
	EventBus.ai_turn_entered.emit()
	await wait_seconds(4.0)
	assert_eq(_done_count, 1, "ai_turn_done sollte nach der vollen Sequenz genau einmal feuern")

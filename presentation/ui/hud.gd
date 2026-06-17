extends Control
## Haupt-HUD: zeigt Ressourcen, Bevölkerung und Stage-Infos.

var _box: VBoxContainer
var _dice_label: Label
var _resource_labels: Dictionary = {}   # StringName -> Label

func _ready() -> void:
	# Leere HUD-Fläche darf Maus-Events nicht abfangen (Board-Drag).
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	add_child(panel)

	_box = VBoxContainer.new()
	panel.add_child(_box)

	_dice_label = Label.new()
	_dice_label.text = "Würfel: – (Leertaste)"
	_box.add_child(_dice_label)

	EventBus.dice_rolled.connect(_on_dice_rolled)
	EventBus.resource_changed.connect(_on_resource_changed)


func _on_dice_rolled(value: int) -> void:
	_dice_label.text = "Würfel: %d" % value


func _on_resource_changed(id: StringName, amount: int) -> void:
	if not _resource_labels.has(id):
		var label := Label.new()
		_resource_labels[id] = label
		_box.add_child(label)
	var res_name: String = Terrain.RESOURCE_NAMES.get(id, str(id))
	_resource_labels[id].text = "%s: %d" % [res_name, amount]


func update_resources() -> void:
	# TODO
	pass


func update_population() -> void:
	# TODO
	pass


func update_stage_info() -> void:
	# TODO
	pass

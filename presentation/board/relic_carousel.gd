class_name RelicCarousel
extends Node3D
## Physisches Relic-Karussell (TFT-Stil): legt die zur Wahl stehenden Relics als
## 3D-Pickups im Kreis um die eigene Position ab. Reagiert nur auf Fakt-Signale
## (auf jedem Peer identisch); die Aufnahme-Interaktion selbst liegt in game_board.

const RING_RADIUS := 4.0
const PICKUP_Y := 1.0

var _pickups: Dictionary = {}   # StringName(relic_id) -> Node3D


func _ready() -> void:
	EventBus.draft_ring_spawned.connect(_on_ring_spawned)
	EventBus.relic_acquired.connect(_on_relic_acquired)
	EventBus.draft_turn_changed.connect(_on_draft_turn_changed)


## Aktuelle Pickups (für die Annäherungs-Erkennung in game_board).
func pickups() -> Dictionary:
	return _pickups


func _on_ring_spawned(relic_ids: Array) -> void:
	_clear()
	var n := relic_ids.size()
	for i in n:
		var id: StringName = relic_ids[i]
		var ang := TAU * float(i) / float(maxi(n, 1))
		var pickup := _make_pickup(id)
		pickup.position = Vector3(cos(ang), 0.0, sin(ang)) * RING_RADIUS + Vector3(0.0, PICKUP_Y, 0.0)
		add_child(pickup)
		_pickups[id] = pickup


func _on_relic_acquired(relic: Relic) -> void:
	if _pickups.has(relic.id):
		_pickups[relic.id].queue_free()
		_pickups.erase(relic.id)


func _on_draft_turn_changed(player_id: int) -> void:
	if player_id < 0:
		_clear()   # Draft beendet → Ring abräumen (auch auf Clients)


func _clear() -> void:
	for id in _pickups:
		_pickups[id].queue_free()
	_pickups.clear()


func _make_pickup(id: StringName) -> Node3D:
	var relic := ContentDB.get_relic(id)
	var root := Node3D.new()
	root.set_meta(&"relic_id", id)

	var mesh := MeshInstance3D.new()
	var gem := PrismMesh.new()
	gem.size = Vector3(0.5, 0.7, 0.5)
	mesh.mesh = gem
	mesh.material_override = _gem_material(relic)
	root.add_child(mesh)

	var label := Label3D.new()
	label.text = relic.display_name if relic != null else String(id)
	label.font_size = 64
	label.pixel_size = 0.006
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 1.05, 0.0)
	root.add_child(label)

	# Effekt-Beschreibung unter dem Namen (umgebrochen), damit die Wahl informiert ist.
	if relic != null and relic.description != "":
		var desc := Label3D.new()
		desc.text = relic.description
		desc.font_size = 32
		desc.pixel_size = 0.005
		desc.outline_size = 8
		desc.modulate = Color(0.85, 0.9, 1.0)
		desc.width = 520.0
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		desc.no_depth_test = true
		desc.position = Vector3(0.0, 0.7, 0.0)
		root.add_child(desc)
	return root


## Färbt das Pickup nach Relic-Kategorie ein (visuelle Orientierung am Tisch).
func _gem_material(relic: Relic) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var color := Color(0.7, 0.7, 0.8)
	if relic != null:
		match relic.category:
			Relic.Category.PRODUCTION: color = Color(0.3, 0.8, 0.4)
			Relic.Category.RULEBREAK: color = Color(0.4, 0.6, 1.0)
			Relic.Category.SYNERGY: color = Color(0.9, 0.8, 0.3)
			Relic.Category.AGGRESSIVE: color = Color(0.9, 0.35, 0.3)
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color * 0.4
	return m

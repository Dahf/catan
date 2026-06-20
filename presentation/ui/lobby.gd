extends Control
## Lobby: zeigt das Roster (live über Net.roster_changed), Host kann starten und
## Freunde per Steam-Overlay einladen. Beim Spielstart bauen ALLE Peers
## deterministisch dasselbe Brett (gleicher Seed) und wechseln in die Spielszene.

const GAME_SCENE := "res://main/main.tscn"
const MENU_SCENE := "res://presentation/ui/menu.tscn"

var _list: VBoxContainer
var _start_button: Button
var _invite_button: Button
var _copy_button: Button
var _status: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(360, 0)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Lobby"
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	vbox.add_child(_list)

	vbox.add_child(HSeparator.new())

	_invite_button = Button.new()
	_invite_button.text = "Freund einladen (Steam-Overlay)"
	_invite_button.pressed.connect(_on_invite_pressed)
	vbox.add_child(_invite_button)

	# Zuverlässigster Weg unabhängig vom Overlay: Lobby-ID teilen.
	_copy_button = Button.new()
	_copy_button.text = "Lobby-ID kopieren"
	_copy_button.pressed.connect(_on_copy_pressed)
	vbox.add_child(_copy_button)

	_start_button = Button.new()
	_start_button.text = "Spiel starten"
	_start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(_start_button)

	var leave := Button.new()
	leave.text = "Verlassen"
	leave.pressed.connect(_on_leave_pressed)
	vbox.add_child(leave)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status)

	Net.roster_changed.connect(_rebuild_list)
	Net.game_started.connect(_on_game_started)
	Net.game_resumed.connect(_on_game_resumed)
	Net.server_disconnected_.connect(_on_disconnected)
	Net.connection_failed_.connect(_on_disconnected)

	_rebuild_list()


func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	for entry in Net.roster:
		var row := Label.new()
		var suffix := "" if entry["connected"] else "  (getrennt)"
		var you := "  ◄ du" if entry["slot"] == Net.local_slot else ""
		row.text = "Slot %d: %s%s%s" % [entry["slot"], entry["name"], you, suffix]
		row.add_theme_color_override("font_color", entry["color"])
		_list.add_child(row)

	var host := Net.is_host()
	var steam_host := host and SteamManager.available and SteamManager.lobby_id != 0
	_start_button.disabled = not host or Net.roster.size() < 2
	_start_button.visible = host
	_invite_button.visible = steam_host
	_copy_button.visible = steam_host
	if steam_host:
		_copy_button.text = "Lobby-ID kopieren (%d)" % SteamManager.lobby_id
	if not host:
		_status.text = "Warte auf den Host …"
	elif Net.roster.size() < 2:
		_status.text = "Mindestens 2 Spieler nötig."
	else:
		_status.text = "Bereit (%d Spieler)." % Net.roster.size()


func _on_start_pressed() -> void:
	Net.start_game()


func _on_invite_pressed() -> void:
	if SteamManager.invite_overlay():
		_status.text = "Overlay geöffnet. Geht nichts auf? → 'Lobby-ID kopieren' nutzen (Overlay läuft nur bei Start über Steam)."
	else:
		_status.text = "Keine aktive Steam-Lobby."


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(str(SteamManager.lobby_id))
	_status.text = "Lobby-ID %d kopiert — Freund fügt sie im Menü unter 'Beitreten per Lobby-ID' ein." % SteamManager.lobby_id


func _on_game_started(game_seed: int, configs: Array) -> void:
	# Deterministischer Aufbau auf JEDEM Peer: gleicher Seed → gleiches Brett.
	GameState.new_run(game_seed, configs)
	var proc := ProcGen.new()
	proc.generate_board()
	get_tree().change_scene_to_file(GAME_SCENE)


## Mid-Game beigetreten/reconnected: Zustand ist bereits per Snapshot gesetzt,
## nur die Szene wechseln (keine Neu-Generierung).
func _on_game_resumed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_leave_pressed() -> void:
	Net.disconnect_session()
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_disconnected() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

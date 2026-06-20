extends Control
## Startmenü: Offline-Hotseat, ENet-Dev-Host/Join und Steam-Host. Baut sein UI
## programmatisch auf (wie hud.gd). Übergänge via change_scene_to_file().

const GAME_SCENE := "res://main/main.tscn"
const LOBBY_SCENE := "res://presentation/ui/lobby.tscn"

var _status: Label
var _lobby_input: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Frischer Zustand: evtl. Reste einer alten Sitzung verwerfen.
	Net.disconnect_session()
	GameState.reset()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(320, 0)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "CATAN"
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_button(vbox, "Offline (Hotseat)", _on_offline)
	_add_separator(vbox)
	_add_button(vbox, "Host (Steam)", _on_host_steam)

	# Beitreten per Lobby-ID (vom Host kopiert) — funktioniert ohne Overlay.
	var join_row := HBoxContainer.new()
	_lobby_input = LineEdit.new()
	_lobby_input.placeholder_text = "Lobby-ID"
	_lobby_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_lobby_input)
	var join_btn := Button.new()
	join_btn.text = "Beitreten (Steam)"
	join_btn.pressed.connect(_on_join_steam_id)
	join_row.add_child(join_btn)
	vbox.add_child(join_row)

	_add_separator(vbox)
	_add_button(vbox, "Host (ENet, lokal)", _on_host_enet)
	_add_button(vbox, "Beitreten (ENet 127.0.0.1)", _on_join_enet)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = "Steam: %s" % ("verfügbar" if SteamManager.available else "nicht installiert (ENet-Dev nutzbar)")
	vbox.add_child(_status)

	SteamManager.steam_lobby_created.connect(_on_steam_lobby_ready)
	SteamManager.steam_lobby_joined.connect(_on_steam_lobby_ready)
	SteamManager.steam_lobby_failed.connect(_on_steam_failed)


func _add_button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)


func _add_separator(parent: Control) -> void:
	parent.add_child(HSeparator.new())


# --- Aktionen ------------------------------------------------------------------

func _on_offline() -> void:
	# GameState bleibt leer → main.gd erzeugt einen Standard-Offline-Run.
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_host_enet() -> void:
	if Net.host_enet() == OK:
		_goto_lobby()
	else:
		_status.text = "ENet-Host fehlgeschlagen"


func _on_join_enet() -> void:
	if Net.join_enet() == OK:
		_goto_lobby()
	else:
		_status.text = "ENet-Join fehlgeschlagen"


func _on_host_steam() -> void:
	if not SteamManager.available:
		_status.text = "Steam nicht verfügbar — GodotSteam installieren."
		return
	_status.text = "Erstelle Steam-Lobby …"
	SteamManager.host_lobby()


func _on_join_steam_id() -> void:
	if not SteamManager.available:
		_status.text = "Steam nicht verfügbar."
		return
	var id := int(_lobby_input.text.strip_edges())
	if id == 0:
		_status.text = "Bitte eine gültige Lobby-ID eingeben."
		return
	_status.text = "Trete Steam-Lobby %d bei …" % id
	SteamManager.join_lobby(id)


func _on_steam_lobby_ready(_lobby_id: int) -> void:
	_goto_lobby()


func _on_steam_failed(reason: String) -> void:
	_status.text = "Steam-Fehler: %s" % reason


func _goto_lobby() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)

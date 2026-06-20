extends Node
## Steam-Integration (GodotSteam). Autoload-Name: SteamManager.
##
## DEFENSIV: greift NICHT statisch auf das `Steam`-Singleton oder die Klasse
## `SteamMultiplayerPeer` zu (das würde ohne installierte GodotSteam-Binaries einen
## Parse-Fehler werfen und das ganze Projekt lahmlegen). Stattdessen wird zur
## Laufzeit über Engine.get_singleton()/Object.call()/ClassDB.instantiate() gearbeitet.
## Ist GodotSteam nicht vorhanden, bleibt `available == false` und der ENet-Dev-Pfad
## in `Net` funktioniert unverändert weiter.
##
## Setup-Schritte für den Steam-Pfad (manuell, einmalig):
##   1. GodotSteam GDExtension (Godot 4.6, precompiled) nach addons/godotsteam/ legen.
##   2. steam_appid.txt mit Inhalt "480" (Spacewar/Test) ins Projekt-Root.
##   3. Steam-Client muss beim Testen laufen.

signal steam_lobby_created(lobby_id: int)
signal steam_lobby_joined(lobby_id: int)
signal steam_lobby_failed(reason: String)

# Steam-Enum-Werte als Literale (dürfen nicht statisch referenziert werden).
const LOBBY_TYPE_PUBLIC := 2          # k_ELobbyTypePublic
const LOBBY_TYPE_FRIENDS_ONLY := 1    # k_ELobbyTypeFriendsOnly
const RESULT_OK := 1                  # k_EResultOK
const CHAT_ROOM_ENTER_RESPONSE_SUCCESS := 1

var available: bool = false
var lobby_id: int = 0

var _steam: Object = null


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	var result = _steam.call("steamInit")
	# steamInit() liefert ein Dictionary {status, verbal}; status==RESULT_OK == Erfolg.
	if typeof(result) == TYPE_DICTIONARY and int(result.get("status", -1)) != RESULT_OK:
		push_warning("SteamManager: steamInit fehlgeschlagen: %s" % str(result.get("verbal", "")))
		_steam = null
		return
	available = true
	_steam.connect("lobby_created", _on_lobby_created)
	_steam.connect("lobby_joined", _on_lobby_joined)
	# Freund klickt "Beitreten" in der Steam-Freundesliste / nimmt Einladung an,
	# während das Spiel schon läuft.
	_steam.connect("join_requested", _on_join_requested)
	# Spiel wurde frisch über eine Einladung gestartet (+connect_lobby <id>).
	call_deferred("_check_launch_join")


func _process(_delta: float) -> void:
	if available:
		_steam.call("run_callbacks")


# --- Lobby-Lifecycle -----------------------------------------------------------

## Host: erstellt eine Steam-Lobby. Antwort kommt asynchron über _on_lobby_created.
func host_lobby(max_players: int = Net.MAX_PLAYERS) -> bool:
	if not available:
		return false
	_steam.call("createLobby", LOBBY_TYPE_FRIENDS_ONLY, max_players)
	return true


## Client: tritt einer Lobby bei. Antwort kommt über _on_lobby_joined.
func join_lobby(target_lobby_id: int) -> bool:
	if not available:
		return false
	_steam.call("joinLobby", target_lobby_id)
	return true


## Öffnet den Steam-Overlay-Dialog zum Einladen von Freunden in die aktuelle Lobby.
## ACHTUNG: Das Overlay rendert i.d.R. nur, wenn das Spiel über Steam gestartet
## wurde — aus dem Godot-Editor heraus passiert oft nichts. Dann stattdessen die
## Lobby-ID teilen oder die Freundesliste ("Spiel beitreten") nutzen.
func invite_overlay() -> bool:
	if available and lobby_id != 0:
		_steam.call("activateGameOverlayInviteDialog", lobby_id)
		return true
	return false


## Lädt einen bestimmten Freund direkt in die Lobby ein (ohne Overlay).
func invite_user(friend_steam_id: int) -> void:
	if available and lobby_id != 0:
		_steam.call("inviteUserToLobby", lobby_id, friend_steam_id)


# Freund klickt "Spiel beitreten" / nimmt Einladung an, während das Spiel läuft.
func _on_join_requested(target_lobby_id: int, _friend_id: int) -> void:
	join_lobby(target_lobby_id)


# Spielstart über eine Einladung: Steam hängt "+connect_lobby <id>" an die Argumente.
func _check_launch_join() -> void:
	var args := OS.get_cmdline_args()
	var idx := args.find("+connect_lobby")
	if idx != -1 and idx + 1 < args.size():
		join_lobby(int(args[idx + 1]))


func leave_lobby() -> void:
	if available and lobby_id != 0:
		_steam.call("clearRichPresence")
		_steam.call("leaveLobby", lobby_id)
		lobby_id = 0


# --- Steam-Callbacks -----------------------------------------------------------

func _on_lobby_created(result: int, new_lobby_id: int) -> void:
	if result != RESULT_OK:
		steam_lobby_failed.emit("createLobby: %d" % result)
		return
	lobby_id = new_lobby_id
	_steam.call("setLobbyData", lobby_id, "game", "catan")
	_steam.call("setLobbyData", lobby_id, "host_name", _persona_self())
	# Damit Freunde über die Steam-Freundesliste "Spiel beitreten" sehen — auch
	# ohne dass das Overlay im Spiel funktioniert (Editor-Start).
	_steam.call("setLobbyJoinable", lobby_id, true)
	_steam.call("setRichPresence", "connect", "+connect_lobby %d" % lobby_id)

	var peer := _new_steam_peer()
	if peer == null:
		steam_lobby_failed.emit("SteamMultiplayerPeer nicht verfügbar")
		return
	var err = peer.call("host_with_lobby", lobby_id)
	if err != OK:
		steam_lobby_failed.emit("host_with_lobby: %s" % str(err))
		return
	Net.attach_steam_host(peer, _persona_self(), _self_steam_id())
	steam_lobby_created.emit(lobby_id)


func _on_lobby_joined(new_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		steam_lobby_failed.emit("joinLobby response: %d" % response)
		return
	lobby_id = new_lobby_id
	var peer := _new_steam_peer()
	if peer == null:
		steam_lobby_failed.emit("SteamMultiplayerPeer nicht verfügbar")
		return
	var err = peer.call("connect_to_lobby", lobby_id)
	if err != OK:
		steam_lobby_failed.emit("connect_to_lobby: %s" % str(err))
		return
	Net.attach_steam_client(peer)
	steam_lobby_joined.emit(lobby_id)


# --- Hilfen (von Net genutzt) --------------------------------------------------

## Steam-ID eines Peers (für Reconnect-Matching). 0, wenn nicht verfügbar.
func steam_id_for_peer(peer_id: int) -> int:
	var peer := multiplayer.multiplayer_peer
	if peer != null and peer.has_method("get_steam_id_for_peer_id"):
		return int(peer.call("get_steam_id_for_peer_id", peer_id))
	return 0


## Anzeigename zu einer Steam-ID.
func persona_name_for(steam_id: int) -> String:
	if available and steam_id != 0:
		return str(_steam.call("getFriendPersonaName", steam_id))
	return "Spieler"


func _persona_self() -> String:
	if available:
		return str(_steam.call("getPersonaName"))
	return "Host"


func _self_steam_id() -> int:
	if available:
		return int(_steam.call("getSteamID"))
	return 0


# Instanziert einen SteamMultiplayerPeer dynamisch (null, wenn Klasse fehlt).
func _new_steam_peer() -> Object:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return null
	var peer: Object = ClassDB.instantiate("SteamMultiplayerPeer")
	if peer == null:
		return null
	# Niedrige Latenz + Steam-Relay (bessere NAT-Traversal übers Internet).
	# Defensiv setzen — Properties existieren nur beim echten Peer.
	peer.set("no_nagle", true)
	peer.set("no_delay", true)
	peer.set("server_relay", true)
	return peer

extends CharacterBody3D
## Frei laufbarer Character. Bewegung kamera-relativ (WASD), Kollision via Physik.
## Der Modell-Slot "Model" enthält aktuell eine Platzhalter-Kapsel; später kann dort
## ein echtes .glb-Modell eingehängt werden.

@export var speed := 6.0
@export var gravity := 20.0
@export var turn_speed := 0.2   # Glättung der Blickrichtung (0..1)
@export var step_height := 0.4   # max. Kantenhöhe, die ohne Rampe automatisch "hochgestiegen" wird

## Optionales Character-Modell (.glb -> als PackedScene hier zuweisen).
## Ist es gesetzt, wird die Platzhalter-Kapsel ausgeblendet und das Modell
## in den "Model"-Slot instanziiert. Modell sollte mit Füßen auf y = 0 stehen
## und nach +Z blicken (Vorderseite), passend zur Lauf-Drehung.
@export var character_model: PackedScene


## Slot für das aktuell getragene Bauteil-Visual (von game_board.gd befüllt).
@onready var carry_slot: Node3D = $Model/CarrySlot

## Roster-Slot dieser Figur (von game_board beim Spawn gesetzt).
var slot: int = -1


func _ready() -> void:
	if character_model != null:
		$Model/Placeholder.visible = false
		$Model.add_child(character_model.instantiate())


## Steuert der lokale Spieler diese Figur? Online: Multiplayer-Autorität (eigener
## Peer). Offline (Hotseat): im Draft die Figur des aktiven Drafters, sonst die des
## aktuell am Zug befindlichen Spielers.
func _is_controlled() -> bool:
	if Net.is_online():
		return is_multiplayer_authority()
	if GameState.turn_phase == GameState.TurnPhase.DRAFT:
		return slot == GameState.draft_current
	return slot == GameState.current_player_index


func _physics_process(delta: float) -> void:
	if not _is_controlled():
		return   # Fremde Figuren: Position kommt per Sync (online) bzw. ruht (offline)
	if GameState.turn_phase == GameState.TurnPhase.DRAFT:
		if slot != GameState.draft_current:
			return   # Im Draft darf nur der aktive Drafter laufen
	elif GameState.is_input_blocked():
		return   # Bewegung pausiert, solange ein Phasen-Overlay geöffnet ist

	var input_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_z := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var dir := _camera_relative_dir(input_x, input_z)

	_step_up(Vector3(dir.x, 0.0, dir.z) * speed * delta)

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	# Modell in Laufrichtung drehen
	if dir.length() > 0.01:
		var target := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target, turn_speed)


## Erlaubt das Hochsteigen kleiner Kanten (z.B. Tisch -> Hex-Plattform) ohne
## Rampe: Ist die horizontale Bewegung blockiert, aber nach Anheben um
## step_height frei, wird der Character direkt angehoben (move_and_slide
## zieht ihn danach per Bodenerkennung wieder auf die neue Oberfläche).
func _step_up(horizontal_motion: Vector3) -> void:
	if horizontal_motion.length() < 0.001:
		return
	if not test_move(global_transform, horizontal_motion):
		return   # nicht blockiert, kein Hochsteigen nötig
	var lifted := global_transform
	lifted.origin.y += step_height
	if not test_move(lifted, horizontal_motion):
		global_position.y += step_height


## Wandelt die Eingabe in eine bildschirm-/kamera-relative Bewegungsrichtung (XZ) um.
func _camera_relative_dir(ix: float, iz: float) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(ix, 0.0, iz)
	var b := cam.global_transform.basis
	var forward := -b.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := b.x
	right.y = 0.0
	right = right.normalized()
	var dir := right * ix + forward * iz
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir

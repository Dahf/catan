extends CharacterBody3D
## Frei laufbarer Character. Bewegung kamera-relativ (WASD), Kollision via Physik.
## Der Modell-Slot "Model" enthält aktuell eine Platzhalter-Kapsel; später kann dort
## ein echtes .glb-Modell eingehängt werden.

@export var speed := 6.0
@export var gravity := 20.0
@export var turn_speed := 0.2   # Glättung der Blickrichtung (0..1)

## Optionales Character-Modell (.glb -> als PackedScene hier zuweisen).
## Ist es gesetzt, wird die Platzhalter-Kapsel ausgeblendet und das Modell
## in den "Model"-Slot instanziiert. Modell sollte mit Füßen auf y = 0 stehen
## und nach +Z blicken (Vorderseite), passend zur Lauf-Drehung.
@export var character_model: PackedScene


func _ready() -> void:
	if character_model != null:
		$Model/Placeholder.visible = false
		$Model.add_child(character_model.instantiate())


func _physics_process(delta: float) -> void:
	var input_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_z := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var dir := _camera_relative_dir(input_x, input_z)

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

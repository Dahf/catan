extends Node
## Persistenz: trennt Run-State (pro Run) von Meta-Progression (dauerhaft).
## Speichert nach user://. Autoload-Name: SaveManager.

## Speichert den aktuellen Run-Zustand.
func save_run() -> void:
	# TODO
	pass


## Lädt einen gespeicherten Run-Zustand.
func load_run() -> void:
	# TODO
	pass


## Speichert die dauerhafte Meta-Progression (Freischaltungen etc.).
func save_meta() -> void:
	# TODO
	pass


## Lädt die Meta-Progression.
func load_meta() -> void:
	# TODO
	pass


## Gibt true zurück, wenn ein gespeicherter Run existiert.
func has_save() -> bool:
	# TODO
	return false

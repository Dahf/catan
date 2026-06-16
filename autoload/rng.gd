extends Node
## Zentraler, geseedeter Zufallsgenerator für reproduzierbare Runs.
## Autoload-Name: RNG.

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Setzt den Seed für einen neuen Run/Stage.
func seed_run(seed: int) -> void:
	# TODO
	pass


## Ganzzahl im Bereich [a, b].
func randi_range(a: int, b: int) -> int:
	# TODO
	return a


## Fließkommazahl in [0, 1).
func randf() -> float:
	# TODO
	return 0.0


## Mischt ein Array in-place (geseedet).
func shuffle(arr: Array) -> void:
	# TODO
	pass

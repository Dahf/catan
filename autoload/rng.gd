extends Node
## Zentraler, geseedeter Zufallsgenerator für reproduzierbare Runs.
## Autoload-Name: RNG.

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Setzt den Seed für einen neuen Run/Stage.
func seed_run(seed: int) -> void:
	rng.seed = seed


## Ganzzahl im Bereich [a, b].
func randi_range(a: int, b: int) -> int:	
	return rng.randi_range(a, b)


## Fließkommazahl in [0, 1).
func randf() -> float:
	return rng.randf()


## Mischt ein Array in-place (geseedet).
func shuffle(arr: Array) -> void:
	for i in range(arr.size()-1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp
